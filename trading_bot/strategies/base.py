"""Base strategy interface and signal data structures."""
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, Dict, Any
import pandas as pd


class SignalType(Enum):
    BUY = "BUY"
    SELL = "SELL"
    HOLD = "HOLD"
    STRONG_BUY = "STRONG_BUY"
    STRONG_SELL = "STRONG_SELL"


@dataclass
class Signal:
    symbol: str
    signal_type: SignalType
    confidence: float          # 0.0 – 1.0
    price: float
    timestamp: pd.Timestamp
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    strategy_name: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def is_entry(self) -> bool:
        return self.signal_type in (SignalType.BUY, SignalType.STRONG_BUY)

    @property
    def is_exit(self) -> bool:
        return self.signal_type in (SignalType.SELL, SignalType.STRONG_SELL)

    def __repr__(self) -> str:
        return (
            f"Signal({self.symbol} {self.signal_type.value} "
            f"@ {self.price:.4f} conf={self.confidence:.2f})"
        )


class BaseStrategy(ABC):
    """All strategies must inherit from this class."""

    name: str = "base"

    def __init__(self, params: Optional[Dict[str, Any]] = None):
        self.params = params or {}

    @abstractmethod
    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        """Given OHLCV DataFrame, return a trading Signal."""

    def _add_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        """Hook for subclasses to compute indicators."""
        return df

    def validate_dataframe(self, df: pd.DataFrame) -> bool:
        required = {"open", "high", "low", "close", "volume"}
        return required.issubset(set(df.columns))
