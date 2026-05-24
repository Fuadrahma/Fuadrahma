"""MACD (Moving Average Convergence Divergence) trend-following strategy."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import pandas as pd
from ta.trend import MACD as MACDIndicator

from bot.core.models import Signal, SignalType
from bot.strategies.base import Strategy


class MACDStrategy(Strategy):
    """Buy on bullish MACD crossover, sell on bearish crossover."""

    name = "macd"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        super().__init__(params)
        self.fast_period: int = self.params.get("fast_period", 12)
        self.slow_period: int = self.params.get("slow_period", 26)
        self.signal_period: int = self.params.get("signal_period", 9)

    def analyze(self, df: pd.DataFrame) -> Signal:
        self._require_rows(df, self.slow_period + self.signal_period + 2)

        macd_ind = MACDIndicator(
            close=df["close"],
            window_fast=self.fast_period,
            window_slow=self.slow_period,
            window_sign=self.signal_period,
        )
        macd_line = macd_ind.macd()
        signal_line = macd_ind.macd_signal()
        histogram = macd_ind.macd_diff()

        prev_hist = float(histogram.iloc[-2])
        curr_hist = float(histogram.iloc[-1])

        price = float(df["close"].iloc[-1])
        ts = df.index[-1] if isinstance(df.index[-1], datetime) else datetime.utcnow()

        if prev_hist <= 0 and curr_hist > 0:
            return Signal(
                type=SignalType.BUY,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min(abs(curr_hist) / price * 1000, 1.0),
                metadata={
                    "macd": float(macd_line.iloc[-1]),
                    "signal": float(signal_line.iloc[-1]),
                    "histogram": curr_hist,
                },
            )

        if prev_hist >= 0 and curr_hist < 0:
            return Signal(
                type=SignalType.SELL,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min(abs(curr_hist) / price * 1000, 1.0),
                metadata={
                    "macd": float(macd_line.iloc[-1]),
                    "signal": float(signal_line.iloc[-1]),
                    "histogram": curr_hist,
                },
            )

        return Signal(
            type=SignalType.HOLD,
            symbol="",
            price=price,
            timestamp=ts,
            strategy=self.name,
            metadata={"histogram": curr_hist},
        )
