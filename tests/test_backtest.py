"""Tests for the backtesting engine."""

from __future__ import annotations

from bot.core.backtester import Backtester
from bot.core.config import BacktestConfig, RiskConfig
from bot.strategies.ema_crossover import EMACrossover
from bot.strategies.macd import MACDStrategy
from bot.strategies.rsi import RSIStrategy
from bot.utils.data import generate_sample_data


def _risk() -> RiskConfig:
    return RiskConfig(
        max_position_pct=0.02,
        stop_loss_pct=0.03,
        take_profit_pct=0.06,
        max_open_trades=3,
    )


def _bt_cfg() -> BacktestConfig:
    return BacktestConfig(initial_balance=10000, commission_pct=0.001)


class TestBacktester:
    def test_ema_crossover_backtest(self):
        df = generate_sample_data(days=180, seed=42)
        strat = EMACrossover({"fast_period": 9, "slow_period": 21})
        bt = Backtester(strat, _risk(), _bt_cfg())
        results = bt.run(df)
        assert results["total_trades"] >= 0
        assert "balance" in results
        assert "strategy" in results

    def test_rsi_backtest(self):
        df = generate_sample_data(days=180, seed=42)
        strat = RSIStrategy({"period": 14, "overbought": 70, "oversold": 30})
        bt = Backtester(strat, _risk(), _bt_cfg())
        results = bt.run(df)
        assert results["total_trades"] >= 0

    def test_macd_backtest(self):
        df = generate_sample_data(days=180, seed=42)
        strat = MACDStrategy()
        bt = Backtester(strat, _risk(), _bt_cfg())
        results = bt.run(df)
        assert results["total_trades"] >= 0

    def test_insufficient_data_raises(self):
        df = generate_sample_data(days=1, seed=42)
        strat = EMACrossover()
        bt = Backtester(strat, _risk(), _bt_cfg())
        import pytest

        with pytest.raises(ValueError, match="Need >="):
            bt.run(df.head(10))

    def test_results_contain_equity_curve(self):
        df = generate_sample_data(days=90, seed=42)
        strat = EMACrossover()
        bt = Backtester(strat, _risk(), _bt_cfg())
        results = bt.run(df)
        assert "equity_curve" in results
        assert isinstance(results["equity_curve"], list)
