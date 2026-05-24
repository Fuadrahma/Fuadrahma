"""
Risk Management System
Kelly Criterion position sizing, drawdown guard, daily loss limit,
trailing stops, and position size calculator.
"""

from __future__ import annotations
import math
from dataclasses import dataclass, field
from datetime import datetime, date
from typing import Dict, Optional, List

from trading_bot.strategies.base import Signal, TradeSignal
from trading_bot.utils.logger import get_logger

logger = get_logger("risk.manager")


@dataclass
class Position:
    symbol: str
    side: str              # "long" | "short"
    entry_price: float
    quantity: float
    stop_loss: float
    take_profit: float
    trailing_stop_pct: float
    peak_price: float = 0.0
    open_time: datetime = field(default_factory=datetime.utcnow)
    unrealized_pnl: float = 0.0
    realized_pnl: float = 0.0

    def update_trailing_stop(self, current_price: float):
        if self.side == "long":
            if current_price > self.peak_price:
                self.peak_price = current_price
                self.stop_loss = max(
                    self.stop_loss,
                    self.peak_price * (1 - self.trailing_stop_pct)
                )
        else:
            if current_price < self.peak_price or self.peak_price == 0:
                self.peak_price = current_price
                self.stop_loss = min(
                    self.stop_loss,
                    self.peak_price * (1 + self.trailing_stop_pct)
                )

    def current_pnl_pct(self, current_price: float) -> float:
        if self.side == "long":
            return (current_price - self.entry_price) / self.entry_price
        return (self.entry_price - current_price) / self.entry_price

    def should_close(self, current_price: float) -> tuple[bool, str]:
        """Return (should_close, reason)."""
        if self.side == "long":
            if current_price <= self.stop_loss:
                return True, f"Stop-loss hit ({current_price:.4f} <= {self.stop_loss:.4f})"
            if current_price >= self.take_profit:
                return True, f"Take-profit hit ({current_price:.4f} >= {self.take_profit:.4f})"
        else:
            if current_price >= self.stop_loss:
                return True, f"Stop-loss hit ({current_price:.4f} >= {self.stop_loss:.4f})"
            if current_price <= self.take_profit:
                return True, f"Take-profit hit ({current_price:.4f} <= {self.take_profit:.4f})"
        return False, ""


class RiskManager:
    def __init__(self, config=None, initial_capital: float = 10_000.0):
        self.cfg = config.risk if config else None
        self.capital = initial_capital
        self.peak_capital = initial_capital
        self.daily_start_capital = initial_capital
        self.last_reset_date: Optional[date] = None
        self.open_positions: Dict[str, Position] = {}
        self.trade_history: List[dict] = []
        self._reset_daily_if_needed()

        # Win rate tracker for Kelly
        self._wins = 0
        self._losses = 0
        self._avg_win_pct = 0.02
        self._avg_loss_pct = 0.01

    # ── Daily reset ──────────────────────────────────────────────────────────

    def _reset_daily_if_needed(self):
        today = date.today()
        if self.last_reset_date != today:
            self.daily_start_capital = self.capital
            self.last_reset_date = today

    # ── Guards ───────────────────────────────────────────────────────────────

    def can_trade(self) -> tuple[bool, str]:
        self._reset_daily_if_needed()

        # Max drawdown guard
        max_dd = getattr(self.cfg, "max_drawdown_pct", 0.15)
        current_dd = (self.peak_capital - self.capital) / (self.peak_capital or 1)
        if current_dd > max_dd:
            return False, f"Max drawdown breached: {current_dd:.1%} > {max_dd:.1%}"

        # Daily loss limit
        daily_loss_limit = getattr(self.cfg, "max_daily_loss_pct", 0.05)
        daily_loss = (self.daily_start_capital - self.capital) / (self.daily_start_capital or 1)
        if daily_loss > daily_loss_limit:
            return False, f"Daily loss limit breached: {daily_loss:.1%} > {daily_loss_limit:.1%}"

        # Max open positions
        max_pos = getattr(self.cfg, "max_open_positions", 5)
        if len(self.open_positions) >= max_pos:
            return False, f"Max open positions reached ({max_pos})"

        return True, "OK"

    # ── Position sizing ──────────────────────────────────────────────────────

    def position_size(self, signal: TradeSignal) -> float:
        """Return the notional amount (in base currency) to allocate."""
        if self.cfg is None:
            return self.capital * 0.02

        if getattr(self.cfg, "use_kelly_criterion", True):
            return self._kelly_size(signal)
        return self._fixed_risk_size(signal)

    def _fixed_risk_size(self, signal: TradeSignal) -> float:
        risk_pct = getattr(self.cfg, "risk_per_trade_pct", 0.01)
        max_pct = getattr(self.cfg, "max_position_size_pct", 0.05)
        risk_amount = self.capital * risk_pct

        if signal.stop_loss and signal.price:
            risk_per_unit = abs(signal.price - signal.stop_loss)
            if risk_per_unit > 0:
                units = risk_amount / risk_per_unit
                notional = units * signal.price
                return min(notional, self.capital * max_pct)

        return self.capital * min(risk_pct * 2, max_pct)

    def _kelly_size(self, signal: TradeSignal) -> float:
        """Half-Kelly position sizing for conservative risk."""
        max_pct = getattr(self.cfg, "max_position_size_pct", 0.05)
        total_trades = self._wins + self._losses
        if total_trades < 10:
            return self._fixed_risk_size(signal)

        win_rate = self._wins / total_trades
        if self._avg_loss_pct == 0:
            return self._fixed_risk_size(signal)

        rr = self._avg_win_pct / self._avg_loss_pct
        kelly = win_rate - (1 - win_rate) / rr
        half_kelly = max(kelly * 0.5, 0.0)  # half-Kelly for safety
        half_kelly = min(half_kelly, max_pct)

        # Scale by signal confidence
        sized = half_kelly * signal.confidence
        return self.capital * min(sized, max_pct)

    # ── Position management ──────────────────────────────────────────────────

    def open_position(self, signal: TradeSignal) -> Optional[Position]:
        ok, reason = self.can_trade()
        if not ok:
            logger.warning(f"Risk block: {reason}")
            return None

        if signal.symbol in self.open_positions:
            logger.info(f"Already have open position for {signal.symbol}")
            return None

        notional = self.position_size(signal)
        if notional <= 0 or signal.price <= 0:
            return None

        qty = notional / signal.price

        sl_pct = getattr(self.cfg, "stop_loss_pct", 0.02)
        tp_pct = getattr(self.cfg, "take_profit_pct", 0.04)
        trail_pct = getattr(self.cfg, "trailing_stop_pct", 0.015)

        if signal.signal == Signal.BUY:
            stop_loss = signal.stop_loss or signal.price * (1 - sl_pct)
            take_profit = signal.take_profit or signal.price * (1 + tp_pct)
            side = "long"
        else:
            stop_loss = signal.stop_loss or signal.price * (1 + sl_pct)
            take_profit = signal.take_profit or signal.price * (1 - tp_pct)
            side = "short"

        pos = Position(
            symbol=signal.symbol, side=side,
            entry_price=signal.price, quantity=qty,
            stop_loss=stop_loss, take_profit=take_profit,
            trailing_stop_pct=trail_pct, peak_price=signal.price,
        )
        self.open_positions[signal.symbol] = pos
        logger.info(f"Opened {side.upper()} {signal.symbol}: "
                    f"qty={qty:.6f} entry={signal.price:.4f} "
                    f"SL={stop_loss:.4f} TP={take_profit:.4f}")
        return pos

    def close_position(self, symbol: str, exit_price: float, reason: str = "") -> Optional[dict]:
        pos = self.open_positions.pop(symbol, None)
        if pos is None:
            return None

        if pos.side == "long":
            pnl = (exit_price - pos.entry_price) * pos.quantity
        else:
            pnl = (pos.entry_price - exit_price) * pos.quantity

        self.capital += pnl
        self.peak_capital = max(self.peak_capital, self.capital)

        pnl_pct = pnl / (pos.entry_price * pos.quantity)
        if pnl > 0:
            self._wins += 1
            self._avg_win_pct = (self._avg_win_pct * (self._wins - 1) + pnl_pct) / self._wins
        else:
            self._losses += 1
            self._avg_loss_pct = (self._avg_loss_pct * (self._losses - 1) + abs(pnl_pct)) / self._losses

        trade = {
            "symbol": symbol, "side": pos.side,
            "entry_price": pos.entry_price, "exit_price": exit_price,
            "quantity": pos.quantity, "pnl": pnl, "pnl_pct": pnl_pct,
            "entry_time": pos.open_time.isoformat(),
            "exit_time": datetime.utcnow().isoformat(),
            "reason": reason,
        }
        self.trade_history.append(trade)
        logger.info(f"Closed {pos.side.upper()} {symbol}: PnL={pnl:+.4f} ({pnl_pct:+.2%}) | {reason}")
        return trade

    def update_positions(self, prices: Dict[str, float]):
        """Update trailing stops and check exit conditions."""
        to_close = []
        for symbol, pos in self.open_positions.items():
            price = prices.get(symbol)
            if price is None:
                continue
            pos.update_trailing_stop(price)
            pos.unrealized_pnl = pos.current_pnl_pct(price) * pos.entry_price * pos.quantity
            should_close, reason = pos.should_close(price)
            if should_close:
                to_close.append((symbol, price, reason))

        for symbol, price, reason in to_close:
            self.close_position(symbol, price, reason)

    # ── Statistics ───────────────────────────────────────────────────────────

    def stats(self) -> dict:
        total = len(self.trade_history)
        if total == 0:
            return {"total_trades": 0, "capital": self.capital}

        pnls = [t["pnl"] for t in self.trade_history]
        winners = [p for p in pnls if p > 0]
        losers = [p for p in pnls if p <= 0]

        win_rate = len(winners) / total
        gross_profit = sum(winners) if winners else 0
        gross_loss = abs(sum(losers)) if losers else 1e-9
        profit_factor = gross_profit / gross_loss

        max_dd = self._max_drawdown()
        sharpe = self._sharpe([t["pnl_pct"] for t in self.trade_history])

        return {
            "total_trades": total, "win_rate": win_rate,
            "profit_factor": profit_factor, "sharpe_ratio": sharpe,
            "max_drawdown": max_dd, "capital": self.capital,
            "total_pnl": sum(pnls), "open_positions": len(self.open_positions),
        }

    def _max_drawdown(self) -> float:
        equity = self.daily_start_capital
        peak = equity
        max_dd = 0.0
        for t in self.trade_history:
            equity += t["pnl"]
            peak = max(peak, equity)
            dd = (peak - equity) / peak
            max_dd = max(max_dd, dd)
        return max_dd

    @staticmethod
    def _sharpe(returns: list, risk_free: float = 0.0, periods: int = 252) -> float:
        import math
        if len(returns) < 2:
            return 0.0
        mean = sum(returns) / len(returns)
        variance = sum((r - mean) ** 2 for r in returns) / (len(returns) - 1)
        std = math.sqrt(variance) if variance > 0 else 1e-9
        return (mean - risk_free) / std * math.sqrt(periods)
