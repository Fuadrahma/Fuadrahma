"""RSI-based mean-reversion strategy with dynamic thresholds."""
import pandas as pd
from .base import BaseStrategy, Signal, SignalType
from .indicators import add_all_indicators


class RSIStrategy(BaseStrategy):
    name = "rsi"

    DEFAULT_PARAMS = {
        "rsi_period": 14,
        "oversold": 30,
        "overbought": 70,
        "extreme_oversold": 20,
        "extreme_overbought": 80,
        "confirm_with_volume": True,
    }

    def __init__(self, params=None):
        super().__init__({**self.DEFAULT_PARAMS, **(params or {})})

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        df = add_all_indicators(df)
        last = df.iloc[-1]
        prev = df.iloc[-2]

        rsi_val = last["rsi"]
        rsi_prev = prev["rsi"]
        price = last["close"]
        ts = df.index[-1]

        volume_ok = (last["volume_ratio"] > 1.2) if self.params["confirm_with_volume"] else True

        # Strong buy: RSI crosses above extreme oversold
        if rsi_prev <= self.params["extreme_oversold"] and rsi_val > self.params["extreme_oversold"] and volume_ok:
            return Signal(
                symbol=symbol, signal_type=SignalType.STRONG_BUY,
                confidence=0.85, price=price, timestamp=ts,
                stop_loss=price * (1 - 0.035),
                take_profit=price * (1 + 0.09),
                strategy_name=self.name,
                metadata={"rsi": rsi_val},
            )

        # Buy: RSI crosses above oversold
        if rsi_prev <= self.params["oversold"] and rsi_val > self.params["oversold"] and volume_ok:
            return Signal(
                symbol=symbol, signal_type=SignalType.BUY,
                confidence=0.70, price=price, timestamp=ts,
                stop_loss=price * (1 - 0.03),
                take_profit=price * (1 + 0.06),
                strategy_name=self.name,
                metadata={"rsi": rsi_val},
            )

        # Strong sell
        if rsi_prev >= self.params["extreme_overbought"] and rsi_val < self.params["extreme_overbought"] and volume_ok:
            return Signal(
                symbol=symbol, signal_type=SignalType.STRONG_SELL,
                confidence=0.85, price=price, timestamp=ts,
                strategy_name=self.name,
                metadata={"rsi": rsi_val},
            )

        # Sell
        if rsi_prev >= self.params["overbought"] and rsi_val < self.params["overbought"] and volume_ok:
            return Signal(
                symbol=symbol, signal_type=SignalType.SELL,
                confidence=0.70, price=price, timestamp=ts,
                strategy_name=self.name,
                metadata={"rsi": rsi_val},
            )

        return Signal(
            symbol=symbol, signal_type=SignalType.HOLD,
            confidence=0.5, price=price, timestamp=ts,
            strategy_name=self.name,
            metadata={"rsi": rsi_val},
        )
