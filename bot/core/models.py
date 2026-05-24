"""Domain models for orders, positions, and signals."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum


class Side(str, Enum):
    BUY = "buy"
    SELL = "sell"


class SignalType(str, Enum):
    BUY = "buy"
    SELL = "sell"
    HOLD = "hold"


@dataclass
class Signal:
    type: SignalType
    symbol: str
    price: float
    timestamp: datetime
    strategy: str
    confidence: float = 1.0
    metadata: dict = field(default_factory=dict)


@dataclass
class Position:
    symbol: str
    side: Side
    entry_price: float
    amount: float
    timestamp: datetime
    stop_loss: float | None = None
    take_profit: float | None = None
    trailing_stop_price: float | None = None
    order_id: str | None = None

    @property
    def value(self) -> float:
        return self.entry_price * self.amount

    def unrealized_pnl(self, current_price: float) -> float:
        if self.side == Side.BUY:
            return (current_price - self.entry_price) * self.amount
        return (self.entry_price - current_price) * self.amount

    def unrealized_pnl_pct(self, current_price: float) -> float:
        if self.entry_price == 0:
            return 0.0
        if self.side == Side.BUY:
            return (current_price - self.entry_price) / self.entry_price
        return (self.entry_price - current_price) / self.entry_price


@dataclass
class Trade:
    symbol: str
    side: Side
    entry_price: float
    exit_price: float
    amount: float
    entry_time: datetime
    exit_time: datetime
    pnl: float
    pnl_pct: float
    strategy: str
    commission: float = 0.0
