"""Unit tests for risk management module."""
import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

import pandas as pd
from trading_bot.risk_management.manager import RiskManager, PortfolioState, Position
from trading_bot.strategies.base import Signal, SignalType


def make_portfolio(balance=10_000.0) -> PortfolioState:
    return PortfolioState(balance=balance, initial_balance=balance)


def make_buy_signal(price=50_000.0, confidence=0.75) -> Signal:
    return Signal(
        symbol="BTC/USDT",
        signal_type=SignalType.BUY,
        confidence=confidence,
        price=price,
        timestamp=pd.Timestamp.utcnow(),
        stop_loss=price * 0.97,
        take_profit=price * 1.06,
        strategy_name="test",
    )


class TestPositionSizing:
    def test_basic_position_size(self):
        rm = RiskManager()
        qty = rm.calculate_position_size(10_000, 50_000, 48_500)
        assert qty > 0

    def test_zero_risk_returns_zero(self):
        rm = RiskManager()
        qty = rm.calculate_position_size(10_000, 50_000, 50_000)
        assert qty == 0.0


class TestSignalValidation:
    def test_valid_signal(self):
        rm = RiskManager()
        portfolio = make_portfolio()
        sig = make_buy_signal()
        valid, reason = rm.validate_signal(sig, portfolio)
        assert valid, reason

    def test_rejects_low_confidence(self):
        rm = RiskManager()
        portfolio = make_portfolio()
        sig = make_buy_signal(confidence=0.40)
        valid, reason = rm.validate_signal(sig, portfolio)
        assert not valid
        assert "confidence" in reason.lower()

    def test_rejects_max_trades_reached(self):
        rm = RiskManager()
        portfolio = make_portfolio(balance=50_000)
        # Fill up positions
        for i in range(rm.trading_cfg.max_open_trades):
            sym = f"COIN{i}/USDT"
            portfolio.open_positions[sym] = Position(
                symbol=sym, entry_price=100.0, quantity=1.0,
                side="long", stop_loss=95.0, take_profit=110.0,
                trailing_stop_pct=0.02, highest_price=100.0, lowest_price=100.0,
            )
        sig = make_buy_signal()
        valid, reason = rm.validate_signal(sig, portfolio)
        assert not valid
        assert "max open trades" in reason.lower()


class TestPositionLifecycle:
    def test_open_and_close_long(self):
        rm = RiskManager()
        portfolio = make_portfolio(balance=50_000)
        sig = make_buy_signal(price=50_000)
        pos = rm.open_position(sig, portfolio)
        assert pos is not None
        assert "BTC/USDT" in portfolio.open_positions
        assert portfolio.balance < 50_000  # funds deducted

        pnl = rm.close_position("BTC/USDT", 53_000, "take_profit", portfolio)
        assert pnl > 0
        assert "BTC/USDT" not in portfolio.open_positions
        assert portfolio.total_trades == 1
        assert portfolio.winning_trades == 1

    def test_stop_loss_triggered(self):
        pos = Position(
            symbol="BTC/USDT", entry_price=50_000, quantity=0.01,
            side="long", stop_loss=48_500, take_profit=53_000,
            trailing_stop_pct=0.02, highest_price=50_000, lowest_price=50_000,
        )
        reason = pos.update(48_000)
        assert reason == "stop_loss"

    def test_take_profit_triggered(self):
        pos = Position(
            symbol="BTC/USDT", entry_price=50_000, quantity=0.01,
            side="long", stop_loss=48_500, take_profit=53_000,
            trailing_stop_pct=0.02, highest_price=50_000, lowest_price=50_000,
        )
        reason = pos.update(54_000)
        assert reason == "take_profit"

    def test_trailing_stop(self):
        pos = Position(
            symbol="BTC/USDT", entry_price=50_000, quantity=0.01,
            side="long", stop_loss=48_000, take_profit=60_000,
            trailing_stop_pct=0.02, highest_price=50_000, lowest_price=50_000,
        )
        # Price goes up to 55k
        pos.update(55_000)
        assert pos.highest_price == 55_000
        # Trailing stop is now 55000 * 0.98 = 53900
        reason = pos.update(53_000)
        assert reason == "trailing_stop"
