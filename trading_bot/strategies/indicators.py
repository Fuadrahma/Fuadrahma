"""
Technical indicator library — pure NumPy/Pandas, no external TA-Lib required.
All functions accept and return pandas Series/DataFrames.
"""
import numpy as np
import pandas as pd
from typing import Tuple


def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def sma(series: pd.Series, period: int) -> pd.Series:
    return series.rolling(window=period).mean()


def rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1 / period, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def macd(
    series: pd.Series,
    fast: int = 12,
    slow: int = 26,
    signal: int = 9,
) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """Returns (macd_line, signal_line, histogram)."""
    macd_line = ema(series, fast) - ema(series, slow)
    signal_line = ema(macd_line, signal)
    histogram = macd_line - signal_line
    return macd_line, signal_line, histogram


def bollinger_bands(
    series: pd.Series, period: int = 20, std_dev: float = 2.0
) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """Returns (upper, middle, lower)."""
    middle = sma(series, period)
    std = series.rolling(window=period).std()
    upper = middle + std_dev * std
    lower = middle - std_dev * std
    return upper, middle, lower


def atr(high: pd.Series, low: pd.Series, close: pd.Series, period: int = 14) -> pd.Series:
    tr1 = high - low
    tr2 = (high - close.shift()).abs()
    tr3 = (low - close.shift()).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    return tr.ewm(alpha=1 / period, adjust=False).mean()


def stochastic(
    high: pd.Series, low: pd.Series, close: pd.Series,
    k_period: int = 14, d_period: int = 3
) -> Tuple[pd.Series, pd.Series]:
    """Returns (K%, D%)."""
    lowest_low = low.rolling(window=k_period).min()
    highest_high = high.rolling(window=k_period).max()
    k = 100 * (close - lowest_low) / (highest_high - lowest_low).replace(0, np.nan)
    d = k.rolling(window=d_period).mean()
    return k, d


def obv(close: pd.Series, volume: pd.Series) -> pd.Series:
    direction = np.sign(close.diff()).fillna(0)
    return (direction * volume).cumsum()


def vwap(high: pd.Series, low: pd.Series, close: pd.Series, volume: pd.Series) -> pd.Series:
    typical_price = (high + low + close) / 3
    return (typical_price * volume).cumsum() / volume.cumsum()


def cci(high: pd.Series, low: pd.Series, close: pd.Series, period: int = 20) -> pd.Series:
    typical_price = (high + low + close) / 3
    mean_dev = typical_price.rolling(window=period).apply(
        lambda x: np.mean(np.abs(x - np.mean(x))), raw=True
    )
    return (typical_price - sma(typical_price, period)) / (0.015 * mean_dev)


def williams_r(high: pd.Series, low: pd.Series, close: pd.Series, period: int = 14) -> pd.Series:
    highest_high = high.rolling(window=period).max()
    lowest_low = low.rolling(window=period).min()
    return -100 * (highest_high - close) / (highest_high - lowest_low).replace(0, np.nan)


def add_all_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """Compute all standard indicators and attach to a copy of the DataFrame."""
    df = df.copy()
    close, high, low, vol = df["close"], df["high"], df["low"], df["volume"]

    # Trend
    df["ema_9"] = ema(close, 9)
    df["ema_21"] = ema(close, 21)
    df["ema_55"] = ema(close, 55)
    df["ema_200"] = ema(close, 200)
    df["sma_50"] = sma(close, 50)
    df["sma_200"] = sma(close, 200)

    # Momentum
    df["rsi"] = rsi(close, 14)
    df["rsi_fast"] = rsi(close, 7)
    df["macd"], df["macd_signal"], df["macd_hist"] = macd(close)
    df["stoch_k"], df["stoch_d"] = stochastic(high, low, close)
    df["cci"] = cci(high, low, close)
    df["williams_r"] = williams_r(high, low, close)

    # Volatility
    bb_upper, bb_mid, bb_lower = bollinger_bands(close)
    df["bb_upper"] = bb_upper
    df["bb_mid"] = bb_mid
    df["bb_lower"] = bb_lower
    df["bb_width"] = (bb_upper - bb_lower) / bb_mid
    df["bb_pct"] = (close - bb_lower) / (bb_upper - bb_lower).replace(0, np.nan)
    df["atr"] = atr(high, low, close)
    df["atr_pct"] = df["atr"] / close

    # Volume
    df["obv"] = obv(close, vol)
    df["vwap"] = vwap(high, low, close, vol)
    df["volume_sma"] = sma(vol, 20)
    df["volume_ratio"] = vol / df["volume_sma"]

    # Price changes
    df["price_change_1"] = close.pct_change(1)
    df["price_change_4"] = close.pct_change(4)
    df["price_change_24"] = close.pct_change(24)

    return df
