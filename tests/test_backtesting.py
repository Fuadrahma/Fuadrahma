"""Unit tests for the backtesting engine."""
import pytest
import numpy as np
import pandas as pd
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from trading_bot.backtesting import Backtester, BacktestResult
from trading_bot.strategies import HybridStrategy, RSIStrategy


def make_ohlcv(n=400, seed=7) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    returns = rng.normal(0.0002, 0.015, n)
    price = 50_000 * np.cumprod(1 + returns)
    open_ = price
    close_ = price * (1 + rng.normal(0, 0.003, n))
    high_ = np.maximum(open_, close_) * (1 + rng.uniform(0, 0.005, n))
    low_ = np.minimum(open_, close_) * (1 - rng.uniform(0, 0.005, n))
    volume = rng.uniform(100, 1000, n)
    idx = pd.date_range(start="2023-01-01", periods=n, freq="1h")
    return pd.DataFrame({"open": open_, "high": high_, "low": low_,
                         "close": close_, "volume": volume}, index=idx)


class TestBacktester:
    def test_backtest_returns_result(self):
        df = make_ohlcv(400)
        bt = Backtester(HybridStrategy())
        result = bt.run(df, "BTC/USDT")
        assert isinstance(result, BacktestResult)

    def test_result_has_equity_curve(self):
        df = make_ohlcv(400)
        bt = Backtester(RSIStrategy())
        result = bt.run(df, "BTC/USDT")
        assert len(result.equity_curve) > 0

    def test_win_rate_between_0_and_1(self):
        df = make_ohlcv(400)
        bt = Backtester(HybridStrategy())
        result = bt.run(df, "BTC/USDT")
        assert 0.0 <= result.win_rate <= 1.0

    def test_trade_count_consistent(self):
        df = make_ohlcv(400)
        bt = Backtester(HybridStrategy())
        result = bt.run(df, "BTC/USDT")
        assert result.winning_trades + result.losing_trades == result.total_trades

    def test_insufficient_data_raises(self):
        df = make_ohlcv(50)
        bt = Backtester(HybridStrategy())
        with pytest.raises(ValueError, match="Not enough data"):
            bt.run(df, "BTC/USDT")

    def test_result_str_contains_metrics(self):
        df = make_ohlcv(400)
        bt = Backtester(HybridStrategy())
        result = bt.run(df, "BTC/USDT")
        s = str(result)
        assert "Total Return" in s
        assert "Sharpe" in s
        assert "Win Rate" in s
