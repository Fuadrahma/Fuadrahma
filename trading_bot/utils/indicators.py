"""
Technical indicator calculations using pure numpy/pandas — no TA-Lib required.
All functions accept a pandas Series or DataFrame and return a Series.
"""

import numpy as np
import pandas as pd


# ── Trend indicators ────────────────────────────────────────────────────────

def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def sma(series: pd.Series, period: int) -> pd.Series:
    return series.rolling(window=period).mean()


def wma(series: pd.Series, period: int) -> pd.Series:
    weights = np.arange(1, period + 1)
    return series.rolling(period).apply(lambda x: np.dot(x, weights) / weights.sum(), raw=True)


def macd(series: pd.Series, fast: int = 12, slow: int = 26,
         signal: int = 9) -> pd.DataFrame:
    fast_ema = ema(series, fast)
    slow_ema = ema(series, slow)
    macd_line = fast_ema - slow_ema
    signal_line = ema(macd_line, signal)
    histogram = macd_line - signal_line
    return pd.DataFrame({"macd": macd_line, "signal": signal_line, "histogram": histogram})


def vwap(high: pd.Series, low: pd.Series, close: pd.Series,
         volume: pd.Series) -> pd.Series:
    tp = (high + low + close) / 3
    return (tp * volume).cumsum() / volume.cumsum()


def supertrend(high: pd.Series, low: pd.Series, close: pd.Series,
               period: int = 10, multiplier: float = 3.0) -> pd.DataFrame:
    atr_val = atr(high, low, close, period)
    hl2 = (high + low) / 2
    upper_band = hl2 + multiplier * atr_val
    lower_band = hl2 - multiplier * atr_val

    supertrend_vals = pd.Series(index=close.index, dtype=float)
    direction = pd.Series(index=close.index, dtype=int)

    for i in range(1, len(close)):
        prev_upper = upper_band.iloc[i - 1]
        prev_lower = lower_band.iloc[i - 1]
        prev_close = close.iloc[i - 1]

        upper_band.iloc[i] = (upper_band.iloc[i]
                               if upper_band.iloc[i] < prev_upper or prev_close > prev_upper
                               else prev_upper)
        lower_band.iloc[i] = (lower_band.iloc[i]
                               if lower_band.iloc[i] > prev_lower or prev_close < prev_lower
                               else prev_lower)

        if close.iloc[i] > upper_band.iloc[i]:
            direction.iloc[i] = 1
        elif close.iloc[i] < lower_band.iloc[i]:
            direction.iloc[i] = -1
        else:
            direction.iloc[i] = direction.iloc[i - 1] if i > 1 else 1

        supertrend_vals.iloc[i] = (lower_band.iloc[i]
                                    if direction.iloc[i] == 1
                                    else upper_band.iloc[i])

    return pd.DataFrame({"supertrend": supertrend_vals, "direction": direction})


# ── Momentum indicators ──────────────────────────────────────────────────────

def rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(com=period - 1, adjust=False).mean()
    avg_loss = loss.ewm(com=period - 1, adjust=False).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def stochastic(high: pd.Series, low: pd.Series, close: pd.Series,
               k_period: int = 14, d_period: int = 3) -> pd.DataFrame:
    lowest_low = low.rolling(k_period).min()
    highest_high = high.rolling(k_period).max()
    k = 100 * (close - lowest_low) / (highest_high - lowest_low).replace(0, np.nan)
    d = k.rolling(d_period).mean()
    return pd.DataFrame({"k": k, "d": d})


def cci(high: pd.Series, low: pd.Series, close: pd.Series,
        period: int = 20) -> pd.Series:
    tp = (high + low + close) / 3
    mean_tp = tp.rolling(period).mean()
    mad = tp.rolling(period).apply(lambda x: np.mean(np.abs(x - x.mean())), raw=True)
    return (tp - mean_tp) / (0.015 * mad.replace(0, np.nan))


def williams_r(high: pd.Series, low: pd.Series, close: pd.Series,
               period: int = 14) -> pd.Series:
    highest_high = high.rolling(period).max()
    lowest_low = low.rolling(period).min()
    return -100 * (highest_high - close) / (highest_high - lowest_low).replace(0, np.nan)


def roc(series: pd.Series, period: int = 12) -> pd.Series:
    return 100 * (series - series.shift(period)) / series.shift(period).replace(0, np.nan)


# ── Volatility indicators ────────────────────────────────────────────────────

def bollinger_bands(series: pd.Series, period: int = 20,
                    std_dev: float = 2.0) -> pd.DataFrame:
    middle = sma(series, period)
    std = series.rolling(period).std()
    upper = middle + std_dev * std
    lower = middle - std_dev * std
    pct_b = (series - lower) / (upper - lower).replace(0, np.nan)
    bandwidth = (upper - lower) / middle.replace(0, np.nan)
    return pd.DataFrame({
        "upper": upper, "middle": middle, "lower": lower,
        "pct_b": pct_b, "bandwidth": bandwidth
    })


def atr(high: pd.Series, low: pd.Series, close: pd.Series,
        period: int = 14) -> pd.Series:
    tr = pd.concat([
        high - low,
        (high - close.shift()).abs(),
        (low - close.shift()).abs()
    ], axis=1).max(axis=1)
    return tr.ewm(com=period - 1, adjust=False).mean()


def keltner_channels(high: pd.Series, low: pd.Series, close: pd.Series,
                     ema_period: int = 20, atr_period: int = 10,
                     multiplier: float = 2.0) -> pd.DataFrame:
    middle = ema(close, ema_period)
    atr_val = atr(high, low, close, atr_period)
    upper = middle + multiplier * atr_val
    lower = middle - multiplier * atr_val
    return pd.DataFrame({"upper": upper, "middle": middle, "lower": lower})


# ── Trend strength ───────────────────────────────────────────────────────────

def adx(high: pd.Series, low: pd.Series, close: pd.Series,
        period: int = 14) -> pd.DataFrame:
    up_move = high.diff()
    down_move = -low.diff()

    plus_dm = up_move.where((up_move > down_move) & (up_move > 0), 0.0)
    minus_dm = down_move.where((down_move > up_move) & (down_move > 0), 0.0)

    atr_val = atr(high, low, close, period)
    plus_di = 100 * ema(plus_dm, period) / atr_val.replace(0, np.nan)
    minus_di = 100 * ema(minus_dm, period) / atr_val.replace(0, np.nan)
    dx = 100 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan)
    adx_val = ema(dx, period)
    return pd.DataFrame({"adx": adx_val, "plus_di": plus_di, "minus_di": minus_di})


# ── Volume indicators ────────────────────────────────────────────────────────

def obv(close: pd.Series, volume: pd.Series) -> pd.Series:
    direction = np.sign(close.diff()).fillna(0)
    return (direction * volume).cumsum()


def mfi(high: pd.Series, low: pd.Series, close: pd.Series,
        volume: pd.Series, period: int = 14) -> pd.Series:
    tp = (high + low + close) / 3
    raw_mf = tp * volume
    pos_mf = raw_mf.where(tp > tp.shift(1), 0)
    neg_mf = raw_mf.where(tp < tp.shift(1), 0)
    mf_ratio = pos_mf.rolling(period).sum() / neg_mf.rolling(period).sum().replace(0, np.nan)
    return 100 - (100 / (1 + mf_ratio))


def cmf(high: pd.Series, low: pd.Series, close: pd.Series,
        volume: pd.Series, period: int = 20) -> pd.Series:
    clv = ((close - low) - (high - close)) / (high - low).replace(0, np.nan)
    mf_volume = clv * volume
    return mf_volume.rolling(period).sum() / volume.rolling(period).sum().replace(0, np.nan)
