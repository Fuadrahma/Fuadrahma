"""Data utilities for fetching and generating OHLCV data."""

from __future__ import annotations

from datetime import datetime

import numpy as np
import pandas as pd


def generate_sample_data(
    days: int = 365,
    start_price: float = 40000.0,
    volatility: float = 0.02,
    trend: float = 0.0001,
    seed: int | None = None,
) -> pd.DataFrame:
    """
    Generate realistic synthetic OHLCV data for backtesting without an exchange.

    Uses geometric Brownian motion to simulate price movement.
    """
    if seed is not None:
        np.random.seed(seed)

    periods = days * 24  # hourly candles
    timestamps = pd.date_range(
        start=datetime(2024, 1, 1), periods=periods, freq="h"
    )

    prices = [start_price]
    for _ in range(1, periods):
        drift = trend
        shock = volatility * np.random.randn()
        new_price = prices[-1] * np.exp(drift + shock)
        prices.append(max(new_price, 1.0))

    prices_arr = np.array(prices)

    highs = prices_arr * (1 + np.abs(np.random.randn(periods)) * 0.005)
    lows = prices_arr * (1 - np.abs(np.random.randn(periods)) * 0.005)
    opens = np.roll(prices_arr, 1)
    opens[0] = start_price
    volumes = np.random.lognormal(mean=10, sigma=1, size=periods)

    df = pd.DataFrame(
        {
            "open": opens,
            "high": highs,
            "low": lows,
            "close": prices_arr,
            "volume": volumes,
        },
        index=timestamps,
    )
    df.index.name = "timestamp"
    return df
