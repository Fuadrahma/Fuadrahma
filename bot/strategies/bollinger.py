"""Bollinger Bands mean-reversion strategy."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import pandas as pd
from ta.volatility import BollingerBands

from bot.core.models import Signal, SignalType
from bot.strategies.base import Strategy


class BollingerBandsStrategy(Strategy):
    """Buy when price touches lower band, sell at upper band."""

    name = "bollinger_bands"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        super().__init__(params)
        self.period: int = self.params.get("period", 20)
        self.std_dev: float = self.params.get("std_dev", 2.0)

    def analyze(self, df: pd.DataFrame) -> Signal:
        self._require_rows(df, self.period + 2)

        bb = BollingerBands(
            close=df["close"],
            window=self.period,
            window_dev=self.std_dev,
        )
        upper = bb.bollinger_hband()
        lower = bb.bollinger_lband()
        mid = bb.bollinger_mavg()

        price = float(df["close"].iloc[-1])
        prev_price = float(df["close"].iloc[-2])
        upper_val = float(upper.iloc[-1])
        lower_val = float(lower.iloc[-1])
        mid_val = float(mid.iloc[-1])

        ts = df.index[-1] if isinstance(df.index[-1], datetime) else datetime.utcnow()

        band_width = upper_val - lower_val if upper_val != lower_val else 1

        if prev_price >= lower_val and price < lower_val:
            return Signal(
                type=SignalType.BUY,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min((lower_val - price) / band_width * 2, 1.0),
                metadata={
                    "upper": upper_val,
                    "mid": mid_val,
                    "lower": lower_val,
                },
            )

        if prev_price <= upper_val and price > upper_val:
            return Signal(
                type=SignalType.SELL,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=min((price - upper_val) / band_width * 2, 1.0),
                metadata={
                    "upper": upper_val,
                    "mid": mid_val,
                    "lower": lower_val,
                },
            )

        return Signal(
            type=SignalType.HOLD,
            symbol="",
            price=price,
            timestamp=ts,
            strategy=self.name,
            metadata={"upper": upper_val, "mid": mid_val, "lower": lower_val},
        )
