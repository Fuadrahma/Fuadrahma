"""Tests for portfolio tracking."""

from __future__ import annotations

import pytest

from bot.core.models import Side
from bot.core.portfolio import Portfolio


class TestPortfolio:
    def test_initial_state(self):
        p = Portfolio(10000)
        assert p.balance == 10000
        assert p.open_position_count == 0
        assert len(p.trades) == 0

    def test_open_position(self):
        p = Portfolio(10000)
        pos = p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)
        assert p.balance == pytest.approx(9000)
        assert p.open_position_count == 1
        assert pos.entry_price == 100

    def test_close_position_profit(self):
        p = Portfolio(10000)
        pos = p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)
        trade = p.close_position(pos, exit_price=110, commission_pct=0.001)
        assert trade.pnl > 0
        assert p.open_position_count == 0
        assert p.balance > 10000

    def test_close_position_loss(self):
        p = Portfolio(10000)
        pos = p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)
        trade = p.close_position(pos, exit_price=90, commission_pct=0.001)
        assert trade.pnl < 0
        assert p.balance < 10000

    def test_insufficient_balance(self):
        p = Portfolio(100)
        with pytest.raises(ValueError, match="Insufficient balance"):
            p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)

    def test_summary_empty(self):
        p = Portfolio(10000)
        s = p.summary()
        assert s["total_trades"] == 0

    def test_summary_with_trades(self):
        p = Portfolio(10000)
        pos = p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)
        p.close_position(pos, exit_price=110, commission_pct=0.001)
        s = p.summary()
        assert s["total_trades"] == 1
        assert s["winning_trades"] == 1

    def test_snapshot(self):
        p = Portfolio(10000)
        p.open_position("BTC/USDT", Side.BUY, price=100, amount=10)
        snap = p.snapshot({"BTC/USDT": 105})
        assert snap["equity"] > 0
        assert snap["open_positions"] == 1
