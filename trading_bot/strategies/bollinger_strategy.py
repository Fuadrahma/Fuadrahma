"""Bollinger Bands squeeze + breakout strategy."""
import pandas as pd
from .base import BaseStrategy, Signal, SignalType
from .indicators import add_all_indicators


class BollingerBandsStrategy(BaseStrategy):
    name = "bollinger"

    DEFAULT_PARAMS = {
        "period": 20,
        "std_dev": 2.0,
        "squeeze_threshold": 0.03,   # BB width < 3% of price = squeeze
        "breakout_pct": 0.005,        # price must close X% outside band
    }

    def __init__(self, params=None):
        super().__init__({**self.DEFAULT_PARAMS, **(params or {})})

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> Signal:
        df = add_all_indicators(df)
        last = df.iloc[-1]
        prev = df.iloc[-2]

        price = last["close"]
        ts = df.index[-1]

        bb_width = last["bb_width"]
        bb_pct = last["bb_pct"]
        rsi_val = last["rsi"]
        squeeze = bb_width < self.params["squeeze_threshold"]

        # Mean reversion signals (touch band + RSI divergence)
        # Price touches lower band and RSI is oversold → buy
        if last["close"] <= last["bb_lower"] and rsi_val < 35:
            confidence = 0.75 + (0.10 if squeeze else 0.0)
            return Signal(
                symbol=symbol, signal_type=SignalType.BUY,
                confidence=min(confidence, 0.90), price=price, timestamp=ts,
                stop_loss=price * (1 - 0.025),
                take_profit=last["bb_mid"],
                strategy_name=self.name,
                metadata={"bb_pct": bb_pct, "bb_width": bb_width, "rsi": rsi_val},
            )

        # Price touches upper band and RSI is overbought → sell
        if last["close"] >= last["bb_upper"] and rsi_val > 65:
            confidence = 0.75 + (0.10 if squeeze else 0.0)
            return Signal(
                symbol=symbol, signal_type=SignalType.SELL,
                confidence=min(confidence, 0.90), price=price, timestamp=ts,
                strategy_name=self.name,
                metadata={"bb_pct": bb_pct, "bb_width": bb_width, "rsi": rsi_val},
            )

        # Breakout signals after squeeze
        if squeeze:
            prev_squeeze = prev["bb_width"] < self.params["squeeze_threshold"]
            if not prev_squeeze:
                # Squeeze released — watch for breakout direction
                if price > last["bb_upper"]:
                    return Signal(
                        symbol=symbol, signal_type=SignalType.STRONG_BUY,
                        confidence=0.82, price=price, timestamp=ts,
                        stop_loss=last["bb_mid"],
                        take_profit=price * 1.08,
                        strategy_name=self.name,
                        metadata={"squeeze_breakout": True, "direction": "up"},
                    )
                elif price < last["bb_lower"]:
                    return Signal(
                        symbol=symbol, signal_type=SignalType.STRONG_SELL,
                        confidence=0.82, price=price, timestamp=ts,
                        strategy_name=self.name,
                        metadata={"squeeze_breakout": True, "direction": "down"},
                    )

        return Signal(
            symbol=symbol, signal_type=SignalType.HOLD,
            confidence=0.5, price=price, timestamp=ts,
            strategy_name=self.name,
            metadata={"bb_pct": bb_pct, "bb_width": bb_width},
        )
