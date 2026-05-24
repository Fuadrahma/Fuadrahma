"""MACD momentum strategy with histogram confirmation."""
import pandas as pd
from .base import BaseStrategy, Signal, SignalType
from .indicators import add_all_indicators


class MACDStrategy(BaseStrategy):
    name = "macd"

    DEFAULT_PARAMS = {
        "fast": 12,
        "slow": 26,
        "signal": 9,
        "hist_threshold": 0.0,
    }

    def __init__(self, params=None):
        super().__init__({**self.DEFAULT_PARAMS, **(params or {})})

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        df = add_all_indicators(df)
        last = df.iloc[-1]
        prev = df.iloc[-2]
        prev2 = df.iloc[-3]

        price = last["close"]
        ts = df.index[-1]
        macd = last["macd"]
        macd_signal = last["macd_signal"]
        hist = last["macd_hist"]
        hist_prev = prev["macd_hist"]
        hist_prev2 = prev2["macd_hist"]

        # Bullish crossover + accelerating histogram
        bull_cross = prev["macd"] <= prev["macd_signal"] and macd > macd_signal
        hist_accelerating_up = hist > hist_prev > hist_prev2

        # Bearish crossover + decelerating histogram
        bear_cross = prev["macd"] >= prev["macd_signal"] and macd < macd_signal
        hist_accelerating_dn = hist < hist_prev < hist_prev2

        trend_up = last["ema_21"] > last["ema_55"]
        trend_dn = last["ema_21"] < last["ema_55"]

        confidence = 0.0
        signal_type = SignalType.HOLD

        if bull_cross and trend_up:
            confidence = 0.82 if hist_accelerating_up else 0.65
            signal_type = SignalType.STRONG_BUY if confidence >= 0.80 else SignalType.BUY
        elif bear_cross and trend_dn:
            confidence = 0.82 if hist_accelerating_dn else 0.65
            signal_type = SignalType.STRONG_SELL if confidence >= 0.80 else SignalType.SELL
        elif bull_cross:
            confidence = 0.60
            signal_type = SignalType.BUY
        elif bear_cross:
            confidence = 0.60
            signal_type = SignalType.SELL

        sl = price * (1 - 0.025) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None
        tp = price * (1 + 0.06) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None

        return Signal(
            symbol=symbol, signal_type=signal_type,
            confidence=confidence or 0.5, price=price, timestamp=ts,
            stop_loss=sl, take_profit=tp,
            strategy_name=self.name,
            metadata={"macd": macd, "signal": macd_signal, "hist": hist},
        )
