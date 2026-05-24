"""Multi-EMA golden/death cross strategy."""
import pandas as pd
from .base import BaseStrategy, Signal, SignalType
from .indicators import add_all_indicators


class EMACrossoverStrategy(BaseStrategy):
    name = "ema_crossover"

    DEFAULT_PARAMS = {
        "fast_ema": 9,
        "slow_ema": 21,
        "trend_ema": 55,
        "long_trend_ema": 200,
    }

    def __init__(self, params=None):
        super().__init__({**self.DEFAULT_PARAMS, **(params or {})})

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        df = add_all_indicators(df)
        last = df.iloc[-1]
        prev = df.iloc[-2]

        price = last["close"]
        ts = df.index[-1]

        fast = last["ema_9"]
        slow = last["ema_21"]
        trend = last["ema_55"]
        long_trend = last["ema_200"]

        fast_prev = prev["ema_9"]
        slow_prev = prev["ema_21"]

        # Long-term trend alignment
        bull_trend = price > long_trend > 0
        bear_trend = price < long_trend

        # Golden cross: fast EMA crosses above slow EMA
        golden_cross = fast_prev <= slow_prev and fast > slow
        # Death cross: fast EMA crosses below slow EMA
        death_cross = fast_prev >= slow_prev and fast < slow

        # Volume confirmation
        vol_confirmed = last["volume_ratio"] > 1.0

        signal_type = SignalType.HOLD
        confidence = 0.5

        if golden_cross and bull_trend and vol_confirmed:
            signal_type = SignalType.STRONG_BUY
            confidence = 0.88
        elif golden_cross and bull_trend:
            signal_type = SignalType.BUY
            confidence = 0.72
        elif golden_cross:
            signal_type = SignalType.BUY
            confidence = 0.60
        elif death_cross and bear_trend and vol_confirmed:
            signal_type = SignalType.STRONG_SELL
            confidence = 0.88
        elif death_cross and bear_trend:
            signal_type = SignalType.SELL
            confidence = 0.72
        elif death_cross:
            signal_type = SignalType.SELL
            confidence = 0.60

        sl = price * (1 - 0.03) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None
        tp = price * (1 + 0.08) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None

        return Signal(
            symbol=symbol, signal_type=signal_type,
            confidence=confidence, price=price, timestamp=ts,
            stop_loss=sl, take_profit=tp,
            strategy_name=self.name,
            metadata={
                "ema_9": fast, "ema_21": slow, "ema_55": trend,
                "ema_200": long_trend, "bull_trend": bull_trend,
            },
        )
