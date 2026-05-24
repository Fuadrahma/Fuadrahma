from .base import BaseStrategy, Signal, SignalType
from .rsi_strategy import RSIStrategy
from .macd_strategy import MACDStrategy
from .bollinger_strategy import BollingerBandsStrategy
from .ema_crossover import EMACrossoverStrategy
from .hybrid_strategy import HybridStrategy

STRATEGIES = {
    "rsi": RSIStrategy,
    "macd": MACDStrategy,
    "bollinger": BollingerBandsStrategy,
    "ema_crossover": EMACrossoverStrategy,
    "hybrid": HybridStrategy,
}

__all__ = [
    "BaseStrategy", "Signal", "SignalType",
    "RSIStrategy", "MACDStrategy", "BollingerBandsStrategy",
    "EMACrossoverStrategy", "HybridStrategy",
    "STRATEGIES",
]
