"""
Hybrid strategy — combines RSI, MACD, Bollinger Bands, and EMA Crossover.
Uses a weighted voting system to produce high-confidence signals.
"""
import pandas as pd
from typing import List
from .base import BaseStrategy, Signal, SignalType
from .indicators import add_all_indicators
from .rsi_strategy import RSIStrategy
from .macd_strategy import MACDStrategy
from .bollinger_strategy import BollingerBandsStrategy
from .ema_crossover import EMACrossoverStrategy


# Weight each sub-strategy's vote
STRATEGY_WEIGHTS = {
    "rsi": 0.25,
    "macd": 0.30,
    "bollinger": 0.20,
    "ema_crossover": 0.25,
}

SIGNAL_SCORES = {
    SignalType.STRONG_BUY: 2,
    SignalType.BUY: 1,
    SignalType.HOLD: 0,
    SignalType.SELL: -1,
    SignalType.STRONG_SELL: -2,
}


class HybridStrategy(BaseStrategy):
    name = "hybrid"

    def __init__(self, params=None):
        super().__init__(params)
        self.sub_strategies: List[BaseStrategy] = [
            RSIStrategy(),
            MACDStrategy(),
            BollingerBandsStrategy(),
            EMACrossoverStrategy(),
        ]

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        df = add_all_indicators(df)
        last = df.iloc[-1]
        price = last["close"]
        ts = df.index[-1]

        votes: List[Signal] = []
        for strategy in self.sub_strategies:
            sig = strategy.generate_signal(df, symbol)
            votes.append(sig)

        # Weighted score
        weighted_score = 0.0
        total_confidence = 0.0
        details = {}
        for sig in votes:
            weight = STRATEGY_WEIGHTS.get(sig.strategy_name, 0.25)
            score = SIGNAL_SCORES.get(sig.signal_type, 0)
            weighted_score += score * weight * sig.confidence
            total_confidence += weight * sig.confidence
            details[sig.strategy_name] = {
                "signal": sig.signal_type.value,
                "confidence": sig.confidence,
            }

        avg_confidence = total_confidence / len(votes)

        # Map score to signal type
        if weighted_score >= 1.2:
            signal_type = SignalType.STRONG_BUY
            final_confidence = min(0.95, 0.70 + weighted_score * 0.08)
        elif weighted_score >= 0.5:
            signal_type = SignalType.BUY
            final_confidence = min(0.85, 0.55 + weighted_score * 0.10)
        elif weighted_score <= -1.2:
            signal_type = SignalType.STRONG_SELL
            final_confidence = min(0.95, 0.70 + abs(weighted_score) * 0.08)
        elif weighted_score <= -0.5:
            signal_type = SignalType.SELL
            final_confidence = min(0.85, 0.55 + abs(weighted_score) * 0.10)
        else:
            signal_type = SignalType.HOLD
            final_confidence = 0.5

        # Use ATR for dynamic SL/TP
        atr_val = last.get("atr", price * 0.02)
        sl = (price - 2.0 * atr_val) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None
        tp = (price + 3.5 * atr_val) if signal_type in (SignalType.BUY, SignalType.STRONG_BUY) else None

        return Signal(
            symbol=symbol,
            signal_type=signal_type,
            confidence=final_confidence,
            price=price,
            timestamp=ts,
            stop_loss=sl,
            take_profit=tp,
            strategy_name=self.name,
            metadata={
                "weighted_score": weighted_score,
                "votes": details,
                "atr": atr_val,
            },
        )
