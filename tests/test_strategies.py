"""Unit tests for all trading strategies."""
import pytest
import numpy as np
import pandas as pd
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from trading_bot.strategies import (
    RSIStrategy, MACDStrategy, BollingerBandsStrategy,
    EMACrossoverStrategy, HybridStrategy, SignalType
)
from trading_bot.strategies.indicators import add_all_indicators


def make_ohlcv(n=300, seed=42) -> pd.DataFrame:
    """Generate synthetic OHLCV data for testing."""
    rng = np.random.default_rng(seed)
    mu, sigma = 0.0001, 0.015
    returns = rng.normal(mu, sigma, n)
    price = 50_000 * np.cumprod(1 + returns)
    open_ = price
    close_ = price * (1 + rng.normal(0, 0.003, n))
    high_ = np.maximum(open_, close_) * (1 + rng.uniform(0, 0.005, n))
    low_ = np.minimum(open_, close_) * (1 - rng.uniform(0, 0.005, n))
    volume = rng.uniform(100, 1000, n)
    idx = pd.date_range(start="2024-01-01", periods=n, freq="1h")
    return pd.DataFrame({"open": open_, "high": high_, "low": low_,
                         "close": close_, "volume": volume}, index=idx)


DF = make_ohlcv(300)
SYMBOL = "BTC/USDT"


class TestIndicators:
    def test_add_all_indicators_shape(self):
        df = add_all_indicators(DF.copy())
        assert "rsi" in df.columns
        assert "macd" in df.columns
        assert "bb_upper" in df.columns
        assert "ema_9" in df.columns
        assert "atr" in df.columns

    def test_rsi_range(self):
        df = add_all_indicators(DF.copy())
        rsi = df["rsi"].dropna()
        assert (rsi >= 0).all() and (rsi <= 100).all()

    def test_bb_ordering(self):
        df = add_all_indicators(DF.copy())
        valid = df.dropna(subset=["bb_upper", "bb_mid", "bb_lower"])
        assert (valid["bb_upper"] >= valid["bb_mid"]).all()
        assert (valid["bb_mid"] >= valid["bb_lower"]).all()


class TestRSIStrategy:
    def test_returns_signal(self):
        sig = RSIStrategy().generate_signal(DF, SYMBOL)
        assert sig.symbol == SYMBOL
        assert isinstance(sig.signal_type, SignalType)

    def test_signal_confidence_range(self):
        sig = RSIStrategy().generate_signal(DF, SYMBOL)
        assert 0.0 <= sig.confidence <= 1.0

    def test_price_is_positive(self):
        sig = RSIStrategy().generate_signal(DF, SYMBOL)
        assert sig.price > 0


class TestMACDStrategy:
    def test_returns_signal(self):
        sig = MACDStrategy().generate_signal(DF, SYMBOL)
        assert sig.symbol == SYMBOL

    def test_valid_signal_type(self):
        sig = MACDStrategy().generate_signal(DF, SYMBOL)
        assert sig.signal_type in SignalType


class TestBollingerStrategy:
    def test_returns_signal(self):
        sig = BollingerBandsStrategy().generate_signal(DF, SYMBOL)
        assert sig.symbol == SYMBOL


class TestEMACrossoverStrategy:
    def test_returns_signal(self):
        sig = EMACrossoverStrategy().generate_signal(DF, SYMBOL)
        assert sig.symbol == SYMBOL

    def test_buy_has_stop_loss(self):
        """If signal is BUY, stop_loss should be set."""
        sig = EMACrossoverStrategy().generate_signal(DF, SYMBOL)
        if sig.signal_type in (SignalType.BUY, SignalType.STRONG_BUY):
            assert sig.stop_loss is not None
            assert sig.stop_loss < sig.price


class TestHybridStrategy:
    def test_returns_signal(self):
        sig = HybridStrategy().generate_signal(DF, SYMBOL)
        assert sig.symbol == SYMBOL

    def test_has_votes_metadata(self):
        sig = HybridStrategy().generate_signal(DF, SYMBOL)
        assert "votes" in sig.metadata

    def test_confidence_range(self):
        sig = HybridStrategy().generate_signal(DF, SYMBOL)
        assert 0.0 <= sig.confidence <= 1.0
