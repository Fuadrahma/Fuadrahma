"""Tests for all trading strategies."""

from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from bot.core.models import SignalType
from bot.strategies.bollinger import BollingerBandsStrategy
from bot.strategies.ema_crossover import EMACrossover
from bot.strategies.macd import MACDStrategy
from bot.strategies.multi_indicator import MultiIndicatorStrategy
from bot.strategies.registry import get_strategy, list_strategies
from bot.strategies.rsi import RSIStrategy
from bot.utils.data import generate_sample_data


def _make_df(prices: list[float]) -> pd.DataFrame:
    """Create a minimal OHLCV DataFrame from a list of close prices."""
    n = len(prices)
    idx = pd.date_range("2024-01-01", periods=n, freq="h")
    arr = np.array(prices)
    return pd.DataFrame(
        {
            "open": arr,
            "high": arr * 1.001,
            "low": arr * 0.999,
            "close": arr,
            "volume": np.ones(n) * 1000,
        },
        index=idx,
    )


class TestEMACrossover:
    def test_returns_signal(self):
        df = generate_sample_data(days=30, seed=1)
        strategy = EMACrossover({"fast_period": 9, "slow_period": 21})
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.SELL, SignalType.HOLD)
        assert signal.price > 0

    def test_buy_on_crossover(self):
        slow_below = list(np.linspace(100, 95, 25))
        cross_up = list(np.linspace(95, 110, 10))
        prices = slow_below + cross_up
        df = _make_df(prices)
        strategy = EMACrossover({"fast_period": 5, "slow_period": 20})
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.HOLD)

    def test_insufficient_rows(self):
        df = _make_df([100, 101])
        strategy = EMACrossover({"fast_period": 9, "slow_period": 21})
        with pytest.raises(ValueError, match="requires"):
            strategy.analyze(df)


class TestRSI:
    def test_returns_signal(self):
        df = generate_sample_data(days=30, seed=2)
        strategy = RSIStrategy({"period": 14, "overbought": 70, "oversold": 30})
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.SELL, SignalType.HOLD)
        assert "rsi" in signal.metadata

    def test_metadata_has_rsi_value(self):
        df = generate_sample_data(days=30, seed=3)
        strategy = RSIStrategy()
        signal = strategy.analyze(df)
        assert 0 <= signal.metadata["rsi"] <= 100


class TestMACD:
    def test_returns_signal(self):
        df = generate_sample_data(days=60, seed=4)
        strategy = MACDStrategy()
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.SELL, SignalType.HOLD)

    def test_metadata_has_histogram(self):
        df = generate_sample_data(days=60, seed=5)
        strategy = MACDStrategy()
        signal = strategy.analyze(df)
        assert "histogram" in signal.metadata


class TestBollingerBands:
    def test_returns_signal(self):
        df = generate_sample_data(days=30, seed=6)
        strategy = BollingerBandsStrategy()
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.SELL, SignalType.HOLD)

    def test_metadata_has_bands(self):
        df = generate_sample_data(days=30, seed=7)
        strategy = BollingerBandsStrategy()
        signal = strategy.analyze(df)
        assert "upper" in signal.metadata
        assert "lower" in signal.metadata
        assert "mid" in signal.metadata


class TestMultiIndicator:
    def test_returns_signal(self):
        df = generate_sample_data(days=60, seed=8)
        strategy = MultiIndicatorStrategy()
        signal = strategy.analyze(df)
        assert signal.type in (SignalType.BUY, SignalType.SELL, SignalType.HOLD)

    def test_metadata_has_votes(self):
        df = generate_sample_data(days=60, seed=9)
        strategy = MultiIndicatorStrategy()
        signal = strategy.analyze(df)
        assert "buy_votes" in signal.metadata
        assert "sell_votes" in signal.metadata


class TestRegistry:
    def test_list_strategies(self):
        names = list_strategies()
        assert "ema_crossover" in names
        assert "rsi" in names
        assert "macd" in names
        assert "bollinger_bands" in names
        assert "multi_indicator" in names

    def test_get_known_strategy(self):
        s = get_strategy("rsi", {"period": 14})
        assert s.name == "rsi"

    def test_get_unknown_raises(self):
        with pytest.raises(ValueError, match="Unknown strategy"):
            get_strategy("nonexistent")
