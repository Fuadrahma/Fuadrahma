"""Abstract base for all trading strategies."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

import pandas as pd

from bot.core.models import Signal


class Strategy(ABC):
    """Every strategy must implement `analyze` and return a Signal."""

    name: str = "base"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        self.params = params or {}

    @abstractmethod
    def analyze(self, df: pd.DataFrame) -> Signal:
        """Analyze a DataFrame of OHLCV data and return a trading signal."""

    def _require_rows(self, df: pd.DataFrame, n: int) -> None:
        if len(df) < n:
            raise ValueError(
                f"{self.name} requires >= {n} rows, got {len(df)}"
            )
