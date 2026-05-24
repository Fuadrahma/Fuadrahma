"""RSI (Relative Strength Index) mean-reversion strategy."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import pandas as pd
from ta.momentum import RSIIndicator

from bot.core.models import Signal, SignalType
from bot.strategies.base import Strategy


class RSIStrategy(Strategy):
    """Buy when RSI dips below oversold, sell when RSI rises above overbought."""

    name = "rsi"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        super().__init__(params)
        self.period: int = self.params.get("period", 14)
        self.overbought: float = self.params.get("overbought", 70)
        self.oversold: float = self.params.get("oversold", 30)

    def analyze(self, df: pd.DataFrame) -> Signal:
        self._require_rows(df, self.period + 2)

        rsi = RSIIndicator(close=df["close"], window=self.period).rsi()
        prev_rsi, curr_rsi = float(rsi.iloc[-2]), float(rsi.iloc[-1])

        price = float(df["close"].iloc[-1])
        ts = df.index[-1] if isinstance(df.index[-1], datetime) else datetime.utcnow()

        if prev_rsi <= self.oversold and curr_rsi > self.oversold:
            return Signal(
                type=SignalType.BUY,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=1 - curr_rsi / 100,
                metadata={"rsi": curr_rsi},
            )

        if prev_rsi >= self.overbought and curr_rsi < self.overbought:
            return Signal(
                type=SignalType.SELL,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=curr_rsi / 100,
                metadata={"rsi": curr_rsi},
            )

        return Signal(
            type=SignalType.HOLD,
            symbol="",
            price=price,
            timestamp=ts,
            strategy=self.name,
            metadata={"rsi": curr_rsi},
        )
