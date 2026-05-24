"""Tests for risk management."""

from __future__ import annotations

from datetime import UTC, datetime

from bot.core.config import RiskConfig
from bot.core.models import Position, Side
from bot.core.risk import RiskManager


def _default_config() -> RiskConfig:
    return RiskConfig(
        max_position_pct=0.02,
        stop_loss_pct=0.03,
        take_profit_pct=0.06,
        max_open_trades=3,
        trailing_stop=False,
        trailing_stop_pct=0.02,
        max_daily_loss_pct=0.05,
    )


def _make_pos(
    entry: float = 100.0, amount: float = 1.0, side: Side = Side.BUY
) -> Position:
    return Position(
        symbol="BTC/USDT",
        side=side,
        entry_price=entry,
        amount=amount,
        timestamp=datetime.now(UTC),
    )


class TestRiskManager:
    def test_position_size(self):
        rm = RiskManager(_default_config())
        size = rm.position_size(balance=10000, price=50000)
        assert size == pytest.approx(0.004, abs=0.001)

    def test_stop_loss_buy(self):
        rm = RiskManager(_default_config())
        sl = rm.stop_loss_price(entry=100.0, side=Side.BUY)
        assert sl == pytest.approx(97.0)

    def test_take_profit_buy(self):
        rm = RiskManager(_default_config())
        tp = rm.take_profit_price(entry=100.0, side=Side.BUY)
        assert tp == pytest.approx(106.0)

    def test_can_open_trade(self):
        rm = RiskManager(_default_config())
        allowed, _ = rm.can_open_trade(10000)
        assert allowed is True

    def test_max_open_trades_block(self):
        rm = RiskManager(_default_config())
        positions = [_make_pos() for _ in range(3)]
        rm.set_open_positions(positions)
        allowed, reason = rm.can_open_trade(10000)
        assert allowed is False
        assert "Max open trades" in reason

    def test_daily_loss_limit(self):
        rm = RiskManager(_default_config())
        rm.record_pnl(-600)
        allowed, reason = rm.can_open_trade(10000)
        assert allowed is False
        assert "Daily loss limit" in reason

    def test_should_close_stop_loss(self):
        rm = RiskManager(_default_config())
        pos = _make_pos(entry=100.0)
        pos.stop_loss = 97.0
        should, reason = rm.should_close_position(pos, current_price=96.0)
        assert should is True
        assert reason == "stop_loss"

    def test_should_close_take_profit(self):
        rm = RiskManager(_default_config())
        pos = _make_pos(entry=100.0)
        pos.take_profit = 106.0
        should, reason = rm.should_close_position(pos, current_price=107.0)
        assert should is True
        assert reason == "take_profit"

    def test_trailing_stop(self):
        cfg = _default_config()
        cfg.trailing_stop = True
        rm = RiskManager(cfg)
        pos = _make_pos(entry=100.0)
        ts = rm.update_trailing_stop(pos, current_price=105.0)
        assert ts is not None
        assert ts == pytest.approx(105.0 * 0.98)


import pytest
