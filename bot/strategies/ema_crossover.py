"""EMA Crossover strategy – fast/slow exponential moving average crossover."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import pandas as pd
from ta.trend import EMAIndicator

from bot.core.models import Signal, SignalType
from bot.strategies.base import Strategy


class EMACrossover(Strategy):
    """Buy when fast EMA crosses above slow EMA, sell on cross below."""

    name = "ema_crossover"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        super().__init__(params)
        self.fast_period: int = self.params.get("fast_period", 9)
        self.slow_period: int = self.params.get("slow_period", 21)

    def analyze(self, df: pd.DataFrame) -> Signal:
        self._require_rows(df, self.slow_period + 2)

        fast = EMAIndicator(close=df["close"], window=self.fast_period).ema_indicator()
        slow = EMAIndicator(close=df["close"], window=self.slow_period).ema_indicator()

        prev_fast, curr_fast = fast.iloc[-2], fast.iloc[-1]
        prev_slow, curr_slow = slow.iloc[-2], slow.iloc[-1]

        price = float(df["close"].iloc[-1])
        ts = df.index[-1] if isinstance(df.index[-1], datetime) else datetime.utcnow()

        if prev_fast <= prev_slow and curr_fast > curr_slow:
            return Signal(
                type=SignalType.BUY,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min(abs(curr_fast - curr_slow) / price * 100, 1.0),
                metadata={"fast_ema": curr_fast, "slow_ema": curr_slow},
            )

        if prev_fast >= prev_slow and curr_fast < curr_slow:
            return Signal(
                type=SignalType.SELL,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min(abs(curr_slow - curr_fast) / price * 100, 1.0),
                metadata={"fast_ema": curr_fast, "slow_ema": curr_slow},
            )

        return Signal(
            type=SignalType.HOLD,
            symbol="",
            price=price,
            timestamp=ts,
            strategy=self.name,
        )
