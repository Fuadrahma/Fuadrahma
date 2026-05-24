"""Strategy registry - maps names to strategy classes."""

from __future__ import annotations

from typing import Any

from bot.strategies.base import Strategy
from bot.strategies.bollinger import BollingerBandsStrategy
from bot.strategies.ema_crossover import EMACrossover
from bot.strategies.macd import MACDStrategy
from bot.strategies.multi_indicator import MultiIndicatorStrategy
from bot.strategies.rsi import RSIStrategy

STRATEGIES: dict[str, type[Strategy]] = {
    "ema_crossover": EMACrossover,
    "rsi": RSIStrategy,
    "macd": MACDStrategy,
    "bollinger_bands": BollingerBandsStrategy,
    "multi_indicator": MultiIndicatorStrategy,
}


def get_strategy(name: str, params: dict[str, Any] | None = None) -> Strategy:
    """Look up a strategy by name and return an instance."""
    cls = STRATEGIES.get(name)
    if cls is None:
        available = ", ".join(STRATEGIES)
        raise ValueError(
            f"Unknown strategy '{name}'. Available: {available}"
        )
    return cls(params)


def list_strategies() -> list[str]:
    return list(STRATEGIES.keys())
