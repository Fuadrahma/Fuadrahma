"""Portfolio tracker for paper and live trading."""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

from bot.core.models import Position, Side, Trade

logger = logging.getLogger(__name__)


class Portfolio:
    """Track balance, open positions, and trade history."""

    def __init__(self, initial_balance: float) -> None:
        self.initial_balance = initial_balance
        self.balance = initial_balance
        self.positions: list[Position] = []
        self.trades: list[Trade] = []
        self.equity_curve: list[dict[str, Any]] = []

    @property
    def open_position_count(self) -> int:
        return len(self.positions)

    def get_position(self, symbol: str) -> Position | None:
        for p in self.positions:
            if p.symbol == symbol:
                return p
        return None

    def open_position(
        self,
        symbol: str,
        side: Side,
        price: float,
        amount: float,
        stop_loss: float | None = None,
        take_profit: float | None = None,
    ) -> Position:
        cost = price * amount
        if cost > self.balance:
            raise ValueError(
                f"Insufficient balance: need {cost:.2f}, have {self.balance:.2f}"
            )
        self.balance -= cost

        pos = Position(
            symbol=symbol,
            side=side,
            entry_price=price,
            amount=amount,
            timestamp=datetime.now(UTC),
            stop_loss=stop_loss,
            take_profit=take_profit,
        )
        self.positions.append(pos)
        logger.info(
            "OPEN  %s %s  price=%.2f  amount=%.8f  cost=%.2f",
            side.value.upper(),
            symbol,
            price,
            amount,
            cost,
        )
        return pos

    def close_position(
        self,
        position: Position,
        exit_price: float,
        strategy: str = "",
        commission_pct: float = 0.001,
    ) -> Trade:
        pnl = position.unrealized_pnl(exit_price)
        commission = position.amount * exit_price * commission_pct
        net_pnl = pnl - commission
        pnl_pct = position.unrealized_pnl_pct(exit_price)

        proceeds = exit_price * position.amount
        self.balance += proceeds - commission

        trade = Trade(
            symbol=position.symbol,
            side=position.side,
            entry_price=position.entry_price,
            exit_price=exit_price,
            amount=position.amount,
            entry_time=position.timestamp,
            exit_time=datetime.now(UTC),
            pnl=net_pnl,
            pnl_pct=pnl_pct,
            strategy=strategy,
            commission=commission,
        )
        self.trades.append(trade)
        self.positions.remove(position)

        logger.info(
            "CLOSE %s  entry=%.2f  exit=%.2f  pnl=%.2f (%.2f%%)",
            position.symbol,
            position.entry_price,
            exit_price,
            net_pnl,
            pnl_pct * 100,
        )
        return trade

    def snapshot(self, current_prices: dict[str, float]) -> dict[str, Any]:
        """Record a point-in-time equity snapshot."""
        unrealized = sum(
            p.unrealized_pnl(current_prices.get(p.symbol, p.entry_price))
            for p in self.positions
        )
        equity = self.balance + sum(
            p.amount * current_prices.get(p.symbol, p.entry_price)
            for p in self.positions
        )
        snap = {
            "timestamp": datetime.now(UTC).isoformat(),
            "balance": self.balance,
            "equity": equity,
            "unrealized_pnl": unrealized,
            "open_positions": self.open_position_count,
            "total_trades": len(self.trades),
        }
        self.equity_curve.append(snap)
        return snap

    def summary(self) -> dict[str, Any]:
        """Return aggregate performance metrics."""
        if not self.trades:
            return {
                "total_trades": 0,
                "balance": self.balance,
                "pnl": 0.0,
                "return_pct": 0.0,
            }

        wins = [t for t in self.trades if t.pnl > 0]
        losses = [t for t in self.trades if t.pnl <= 0]
        total_pnl = sum(t.pnl for t in self.trades)
        avg_win = sum(t.pnl for t in wins) / len(wins) if wins else 0
        avg_loss = sum(t.pnl for t in losses) / len(losses) if losses else 0

        return {
            "total_trades": len(self.trades),
            "winning_trades": len(wins),
            "losing_trades": len(losses),
            "win_rate": len(wins) / len(self.trades) if self.trades else 0,
            "total_pnl": total_pnl,
            "avg_win": avg_win,
            "avg_loss": avg_loss,
            "profit_factor": (
                abs(sum(t.pnl for t in wins) / sum(t.pnl for t in losses))
                if losses and sum(t.pnl for t in losses) != 0
                else float("inf")
            ),
            "balance": self.balance,
            "return_pct": (self.balance - self.initial_balance)
            / self.initial_balance
            * 100,
            "max_drawdown_pct": self._max_drawdown(),
        }

    def _max_drawdown(self) -> float:
        if not self.equity_curve:
            return 0.0
        peak = 0.0
        max_dd = 0.0
        for snap in self.equity_curve:
            equity = snap["equity"]
            if equity > peak:
                peak = equity
            dd = (peak - equity) / peak if peak > 0 else 0
            if dd > max_dd:
                max_dd = dd
        return max_dd * 100
