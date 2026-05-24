"""
Professional risk management module.
Handles position sizing, stop-loss, take-profit, trailing stops,
drawdown protection, and overall portfolio state.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from datetime import datetime

from trading_bot.strategies.base import Signal, SignalType

logger = logging.getLogger(__name__)


@dataclass
class Position:
    symbol: str
    entry_price: float
    quantity: float
    side: str                  # "long" | "short"
    stop_loss: float
    take_profit: float
    trailing_stop_pct: float   # 0.02 = 2%
    opened_at: datetime = field(default_factory=datetime.utcnow)
    highest_price: float = 0.0
    lowest_price: float = float("inf")
    unrealized_pnl: float = 0.0
    realized_pnl: float = 0.0
    is_open: bool = True

    def update(self, current_price: float) -> Optional[str]:
        """
        Update position with latest price.
        Returns close reason if position should be closed, else None.
        """
        if not self.is_open:
            return None

        # Track extremes for trailing stop
        if current_price > self.highest_price:
            self.highest_price = current_price
        if current_price < self.lowest_price:
            self.lowest_price = current_price

        # Unrealized PnL
        if self.side == "long":
            self.unrealized_pnl = (current_price - self.entry_price) * self.quantity
        else:
            self.unrealized_pnl = (self.entry_price - current_price) * self.quantity

        # --- Exit conditions ---
        # Trailing stop
        if self.side == "long":
            trailing_sl = self.highest_price * (1 - self.trailing_stop_pct)
            effective_sl = max(self.stop_loss, trailing_sl)
            if current_price <= effective_sl:
                return "trailing_stop" if current_price > self.stop_loss else "stop_loss"
            if current_price >= self.take_profit:
                return "take_profit"
        else:
            trailing_sl = self.lowest_price * (1 + self.trailing_stop_pct)
            effective_sl = min(self.stop_loss, trailing_sl)
            if current_price >= effective_sl:
                return "trailing_stop" if current_price < self.stop_loss else "stop_loss"
            if current_price <= self.take_profit:
                return "take_profit"

        return None

    def close(self, exit_price: float, reason: str) -> float:
        """Close position and return realized PnL."""
        if self.side == "long":
            self.realized_pnl = (exit_price - self.entry_price) * self.quantity
        else:
            self.realized_pnl = (self.entry_price - exit_price) * self.quantity
        self.is_open = False
        return self.realized_pnl

    @property
    def pnl_pct(self) -> float:
        if self.side == "long":
            return (self.unrealized_pnl) / (self.entry_price * self.quantity)
        return (self.unrealized_pnl) / (self.entry_price * self.quantity)


@dataclass
class PortfolioState:
    balance: float
    initial_balance: float
    open_positions: Dict[str, Position] = field(default_factory=dict)
    closed_trades: List[dict] = field(default_factory=list)
    peak_balance: float = 0.0
    total_trades: int = 0
    winning_trades: int = 0

    def __post_init__(self):
        self.peak_balance = self.initial_balance

    @property
    def equity(self) -> float:
        unrealized = sum(p.unrealized_pnl for p in self.open_positions.values())
        return self.balance + unrealized

    @property
    def drawdown(self) -> float:
        if self.peak_balance <= 0:
            return 0.0
        if self.equity > self.peak_balance:
            self.peak_balance = self.equity
        return (self.peak_balance - self.equity) / self.peak_balance

    @property
    def win_rate(self) -> float:
        if self.total_trades == 0:
            return 0.0
        return self.winning_trades / self.total_trades

    @property
    def total_pnl(self) -> float:
        return self.equity - self.initial_balance

    @property
    def total_return_pct(self) -> float:
        return (self.total_pnl / self.initial_balance) * 100


class RiskManager:
    """Central risk manager for the trading bot."""

    def __init__(self, config=None):
        from trading_bot.config import config as default_config
        self.cfg = (config or default_config).risk
        self.trading_cfg = (config or default_config).trading

    def calculate_position_size(
        self, balance: float, entry_price: float, stop_loss: float
    ) -> float:
        """
        Kelly-inspired fixed-risk position sizing.
        Risk at most `max_risk_per_trade` of balance per trade.
        """
        risk_amount = balance * self.cfg.max_risk_per_trade
        price_risk = abs(entry_price - stop_loss)
        if price_risk <= 0:
            return 0.0
        quantity = risk_amount / price_risk
        # Also cap by stake amount limit
        max_qty = self.trading_cfg.stake_amount / entry_price
        return min(quantity, max_qty)

    def validate_signal(
        self, signal: Signal, portfolio: PortfolioState
    ) -> Tuple[bool, str]:
        """
        Validate a signal against risk rules.
        Returns (is_valid, reason).
        """
        # 1. Max open trades
        if len(portfolio.open_positions) >= self.trading_cfg.max_open_trades:
            return False, f"Max open trades ({self.trading_cfg.max_open_trades}) reached"

        # 2. Already in this symbol
        if signal.symbol in portfolio.open_positions:
            return False, f"Already have open position in {signal.symbol}"

        # 3. Max drawdown
        if portfolio.drawdown >= self.cfg.max_drawdown_pct:
            return False, f"Max drawdown ({self.cfg.max_drawdown_pct:.1%}) breached"

        # 4. Minimum confidence
        if signal.confidence < 0.60:
            return False, f"Signal confidence {signal.confidence:.2f} below threshold 0.60"

        # 5. Risk/Reward check
        if signal.stop_loss and signal.take_profit and signal.is_entry:
            risk = abs(signal.price - signal.stop_loss)
            reward = abs(signal.take_profit - signal.price)
            if risk > 0 and (reward / risk) < self.cfg.risk_reward_min:
                return False, f"R/R {reward/risk:.2f} below minimum {self.cfg.risk_reward_min}"

        # 6. Sufficient balance
        required = self.trading_cfg.stake_amount
        if portfolio.balance < required:
            return False, f"Insufficient balance: {portfolio.balance:.2f} < {required:.2f}"

        return True, "OK"

    def open_position(
        self, signal: Signal, portfolio: PortfolioState
    ) -> Optional[Position]:
        """Create and register a new position."""
        is_valid, reason = self.validate_signal(signal, portfolio)
        if not is_valid:
            logger.info("Signal rejected: %s — %s", signal, reason)
            return None

        stop_loss = signal.stop_loss or signal.price * (1 - self.cfg.stop_loss_pct)
        take_profit = signal.take_profit or signal.price * (1 + self.cfg.take_profit_pct)

        quantity = self.calculate_position_size(
            portfolio.balance, signal.price, stop_loss
        )
        if quantity <= 0:
            return None

        cost = quantity * signal.price
        portfolio.balance -= cost

        position = Position(
            symbol=signal.symbol,
            entry_price=signal.price,
            quantity=quantity,
            side="long" if signal.is_entry else "short",
            stop_loss=stop_loss,
            take_profit=take_profit,
            trailing_stop_pct=self.cfg.trailing_stop_pct,
            highest_price=signal.price,
            lowest_price=signal.price,
        )
        portfolio.open_positions[signal.symbol] = position
        logger.info("Opened %s | qty=%.6f @ %.4f | SL=%.4f TP=%.4f",
                    signal.symbol, quantity, signal.price, stop_loss, take_profit)
        return position

    def close_position(
        self, symbol: str, exit_price: float, reason: str, portfolio: PortfolioState
    ) -> Optional[float]:
        """Close a position and update portfolio."""
        pos = portfolio.open_positions.pop(symbol, None)
        if pos is None:
            return None

        pnl = pos.close(exit_price, reason)
        portfolio.balance += exit_price * pos.quantity
        portfolio.total_trades += 1
        if pnl > 0:
            portfolio.winning_trades += 1

        portfolio.closed_trades.append({
            "symbol": symbol,
            "entry": pos.entry_price,
            "exit": exit_price,
            "qty": pos.quantity,
            "side": pos.side,
            "pnl": pnl,
            "pnl_pct": pnl / (pos.entry_price * pos.quantity),
            "reason": reason,
            "opened_at": pos.opened_at.isoformat(),
            "closed_at": datetime.utcnow().isoformat(),
        })
        logger.info("Closed %s @ %.4f | PnL=%.4f | reason=%s", symbol, exit_price, pnl, reason)
        return pnl

    def check_exits(
        self, portfolio: PortfolioState, prices: Dict[str, float]
    ) -> List[Tuple[str, str]]:
        """Check all open positions for exit conditions. Returns list of (symbol, reason)."""
        exits = []
        for symbol, position in list(portfolio.open_positions.items()):
            price = prices.get(symbol)
            if price is None:
                continue
            reason = position.update(price)
            if reason:
                exits.append((symbol, reason))
        return exits
