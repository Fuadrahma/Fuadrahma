"""Risk management engine - position sizing, stop-loss, take-profit, daily drawdown."""

from __future__ import annotations

import logging
from datetime import date

from bot.core.config import RiskConfig
from bot.core.models import Position, Side

logger = logging.getLogger(__name__)


class RiskManager:
    """Enforces risk rules before every trade."""

    def __init__(self, config: RiskConfig) -> None:
        self.cfg = config
        self._daily_pnl: float = 0.0
        self._last_reset: date = date.today()
        self._open_positions: list[Position] = []

    def _maybe_reset_daily(self) -> None:
        today = date.today()
        if today != self._last_reset:
            logger.info(
                "New trading day – resetting daily P&L (was %.2f)",
                self._daily_pnl,
            )
            self._daily_pnl = 0.0
            self._last_reset = today

    def record_pnl(self, pnl: float) -> None:
        self._maybe_reset_daily()
        self._daily_pnl += pnl

    def set_open_positions(self, positions: list[Position]) -> None:
        self._open_positions = list(positions)

    def can_open_trade(self, balance: float) -> tuple[bool, str]:
        """Return (allowed, reason)."""
        self._maybe_reset_daily()

        if len(self._open_positions) >= self.cfg.max_open_trades:
            return False, f"Max open trades reached ({self.cfg.max_open_trades})"

        max_loss = balance * self.cfg.max_daily_loss_pct
        if self._daily_pnl <= -max_loss:
            return False, (
                f"Daily loss limit hit: {self._daily_pnl:.2f} "
                f"(max -{max_loss:.2f})"
            )

        return True, "OK"

    def position_size(self, balance: float, price: float) -> float:
        """Calculate the maximum position size in base-asset units."""
        risk_amount = balance * self.cfg.max_position_pct
        if price <= 0:
            return 0.0
        return risk_amount / price

    def stop_loss_price(self, entry: float, side: Side) -> float:
        if side == Side.BUY:
            return entry * (1 - self.cfg.stop_loss_pct)
        return entry * (1 + self.cfg.stop_loss_pct)

    def take_profit_price(self, entry: float, side: Side) -> float:
        if side == Side.BUY:
            return entry * (1 + self.cfg.take_profit_pct)
        return entry * (1 - self.cfg.take_profit_pct)

    def update_trailing_stop(
        self, position: Position, current_price: float
    ) -> float | None:
        """Return updated trailing-stop price or None if trailing stop is disabled."""
        if not self.cfg.trailing_stop:
            return None

        if position.side == Side.BUY:
            new_stop = current_price * (1 - self.cfg.trailing_stop_pct)
            if position.trailing_stop_price is None:
                return new_stop
            return max(position.trailing_stop_price, new_stop)
        else:
            new_stop = current_price * (1 + self.cfg.trailing_stop_pct)
            if position.trailing_stop_price is None:
                return new_stop
            return min(position.trailing_stop_price, new_stop)

    def should_close_position(
        self, position: Position, current_price: float
    ) -> tuple[bool, str]:
        """Check if any risk rule triggers a position close."""
        if position.side == Side.BUY:
            if position.stop_loss and current_price <= position.stop_loss:
                return True, "stop_loss"
            if position.take_profit and current_price >= position.take_profit:
                return True, "take_profit"
            if position.trailing_stop_price and current_price <= position.trailing_stop_price:
                return True, "trailing_stop"
        else:
            if position.stop_loss and current_price >= position.stop_loss:
                return True, "stop_loss"
            if position.take_profit and current_price <= position.take_profit:
                return True, "take_profit"
            if position.trailing_stop_price and current_price >= position.trailing_stop_price:
                return True, "trailing_stop"

        return False, ""
