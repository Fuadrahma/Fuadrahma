"""Base strategy interface."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional
import pandas as pd


class Signal(Enum):
    BUY = 1
    SELL = -1
    HOLD = 0


@dataclass
class TradeSignal:
    signal: Signal
    symbol: str
    strategy: str
    confidence: float          # 0.0 – 1.0
    price: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    reason: str = ""

    def __repr__(self) -> str:
        return (f"TradeSignal({self.strategy}|{self.symbol}|{self.signal.name}"
                f"|conf={self.confidence:.2f}|price={self.price:.4f})")


class BaseStrategy(ABC):
    name: str = "base"
    weight: float = 1.0

    def __init__(self, config=None):
        self.config = config

    @abstractmethod
    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        """Analyse OHLCV DataFrame and return a TradeSignal."""

    def _last(self, series: pd.Series):
        return series.iloc[-1]

    def _prev(self, series: pd.Series, n: int = 1):
        return series.iloc[-1 - n]
