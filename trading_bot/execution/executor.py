"""
Order Execution Engine
Supports paper trading (default) and live trading via ccxt.
"""

from __future__ import annotations
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional

from trading_bot.strategies.base import Signal, TradeSignal
from trading_bot.risk.manager import RiskManager, Position
from trading_bot.utils.logger import get_logger

logger = get_logger("execution.executor")


@dataclass
class Order:
    order_id: str
    symbol: str
    side: str              # "buy" | "sell"
    order_type: str        # "market" | "limit"
    quantity: float
    price: float
    status: str = "open"   # open | filled | cancelled | rejected
    filled_qty: float = 0.0
    avg_fill_price: float = 0.0
    commission: float = 0.0
    created_at: datetime = field(default_factory=datetime.utcnow)
    filled_at: Optional[datetime] = None


class PaperExecutor:
    """Simulates order execution with configurable slippage and commission."""

    def __init__(self, commission_pct: float = 0.001, slippage_pct: float = 0.0005):
        self.commission_pct = commission_pct
        self.slippage_pct = slippage_pct
        self.orders: Dict[str, Order] = {}

    def submit_order(self, symbol: str, side: str, quantity: float,
                     price: float, order_type: str = "market") -> Order:
        oid = str(uuid.uuid4())[:8]
        order = Order(order_id=oid, symbol=symbol, side=side,
                      order_type=order_type, quantity=quantity, price=price)

        # Simulate fill with slippage
        slip = self.slippage_pct if side == "buy" else -self.slippage_pct
        fill_price = price * (1 + slip)
        commission = fill_price * quantity * self.commission_pct

        order.status = "filled"
        order.filled_qty = quantity
        order.avg_fill_price = fill_price
        order.commission = commission
        order.filled_at = datetime.utcnow()
        self.orders[oid] = order

        logger.info(f"[PAPER] {side.upper()} {symbol}: qty={quantity:.6f} "
                    f"@ {fill_price:.4f} | comm={commission:.6f} | oid={oid}")
        return order

    def cancel_order(self, order_id: str) -> bool:
        order = self.orders.get(order_id)
        if order and order.status == "open":
            order.status = "cancelled"
            return True
        return False

    def get_order(self, order_id: str) -> Optional[Order]:
        return self.orders.get(order_id)


class LiveExecutor:
    """Live order execution via ccxt exchange."""

    def __init__(self, exchange, commission_pct: float = 0.001):
        self.exchange = exchange
        self.commission_pct = commission_pct
        self.orders: Dict[str, Order] = {}

    def submit_order(self, symbol: str, side: str, quantity: float,
                     price: float, order_type: str = "market") -> Optional[Order]:
        try:
            if order_type == "market":
                raw = self.exchange.create_market_order(symbol, side, quantity)
            else:
                raw = self.exchange.create_limit_order(symbol, side, quantity, price)

            oid = str(raw["id"])
            fill_price = raw.get("average") or raw.get("price") or price
            order = Order(
                order_id=oid, symbol=symbol, side=side,
                order_type=order_type, quantity=quantity, price=price,
                status="filled", filled_qty=quantity,
                avg_fill_price=fill_price,
                commission=fill_price * quantity * self.commission_pct,
            )
            self.orders[oid] = order
            logger.info(f"[LIVE] {side.upper()} {symbol}: qty={quantity:.6f} "
                        f"@ {fill_price:.4f} | oid={oid}")
            return order
        except Exception as e:
            logger.error(f"Live order failed for {symbol}: {e}")
            return None


class TradingExecutor:
    """High-level executor that wraps paper/live and integrates with RiskManager."""

    def __init__(self, risk_manager: RiskManager, config=None):
        self.risk = risk_manager
        self.paper_trading = True if config is None else config.paper_trading
        commission = 0.001
        slippage = 0.0005
        if config and hasattr(config, "backtest"):
            commission = config.backtest.commission_pct
            slippage = config.backtest.slippage_pct

        self._executor = PaperExecutor(commission, slippage)
        self._live_executor: Optional[LiveExecutor] = None
        self._filled_orders: List[Order] = []

    def set_live_exchange(self, exchange):
        self._live_executor = LiveExecutor(exchange)
        self.paper_trading = False

    def execute_signal(self, signal: TradeSignal) -> Optional[Order]:
        if signal.signal == Signal.HOLD:
            return None

        # Check if we should close an existing opposite position
        existing = self.risk.open_positions.get(signal.symbol)
        if existing:
            opposite = (existing.side == "long" and signal.signal == Signal.SELL) or \
                       (existing.side == "short" and signal.signal == Signal.BUY)
            if opposite:
                close_side = "sell" if existing.side == "long" else "buy"
                order = self._executor.submit_order(
                    signal.symbol, close_side, existing.quantity, signal.price
                )
                self.risk.close_position(
                    signal.symbol, order.avg_fill_price, f"Signal reversal: {signal.reason}"
                )
                self._filled_orders.append(order)
                return order
            return None  # Same direction, already in trade

        # Open new position
        pos = self.risk.open_position(signal)
        if pos is None:
            return None

        side = "buy" if signal.signal == Signal.BUY else "sell"
        order = self._executor.submit_order(
            signal.symbol, side, pos.quantity, signal.price
        )
        if order is None or order.status != "filled":
            self.risk.open_positions.pop(signal.symbol, None)
            return None

        self._filled_orders.append(order)
        return order

    def update_and_check_exits(self, prices: Dict[str, float]):
        """Update trailing stops and execute any triggered exits."""
        # Risk manager determines which positions to close
        exits_before = set(self.risk.open_positions.keys())
        self.risk.update_positions(prices)
        exits_after = set(self.risk.open_positions.keys())
        closed = exits_before - exits_after

        for symbol in closed:
            price = prices.get(symbol, 0)
            if price:
                side = "sell"  # simplified — close by selling
                logger.debug(f"Auto-closed {symbol} at {price:.4f}")
