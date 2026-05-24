"""
RSI + Divergence Strategy
Generates BUY when RSI exits oversold territory and SELL when exiting overbought.
Combines with RSI divergence detection for higher-confidence signals.
"""

import pandas as pd
import numpy as np
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal
from trading_bot.utils.indicators import rsi, atr


class RSIStrategy(BaseStrategy):
    name = "rsi"
    weight = 1.2

    def __init__(self, config=None):
        super().__init__(config)
        cfg = config.strategy if config else None
        self.period = getattr(cfg, "rsi_period", 14)
        self.oversold = getattr(cfg, "rsi_oversold", 30.0)
        self.overbought = getattr(cfg, "rsi_overbought", 70.0)

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        close = df["close"]
        high = df["high"]
        low = df["low"]

        rsi_vals = rsi(close, self.period)
        atr_val = atr(high, low, close, 14)

        current_rsi = self._last(rsi_vals)
        prev_rsi = self._prev(rsi_vals)
        current_price = self._last(close)
        current_atr = self._last(atr_val)

        signal = Signal.HOLD
        confidence = 0.0
        reason = ""

        # Classic RSI crossover
        if prev_rsi < self.oversold and current_rsi >= self.oversold:
            signal = Signal.BUY
            confidence = 0.6 + 0.4 * ((self.oversold - min(prev_rsi, self.oversold)) / self.oversold)
            reason = f"RSI crossed above oversold ({current_rsi:.1f})"

        elif prev_rsi > self.overbought and current_rsi <= self.overbought:
            signal = Signal.SELL
            confidence = 0.6 + 0.4 * ((min(prev_rsi, 100) - self.overbought) / (100 - self.overbought))
            reason = f"RSI crossed below overbought ({current_rsi:.1f})"

        # Hidden divergence (trend continuation)
        elif current_rsi < 45 and self._bullish_divergence(close.tail(30), rsi_vals.tail(30)):
            signal = Signal.BUY
            confidence = 0.55
            reason = "Bullish RSI divergence detected"

        elif current_rsi > 55 and self._bearish_divergence(close.tail(30), rsi_vals.tail(30)):
            signal = Signal.SELL
            confidence = 0.55
            reason = "Bearish RSI divergence detected"

        # Extreme levels
        elif current_rsi <= 20:
            signal = Signal.BUY
            confidence = 0.75
            reason = f"Extreme oversold RSI ({current_rsi:.1f})"

        elif current_rsi >= 80:
            signal = Signal.SELL
            confidence = 0.75
            reason = f"Extreme overbought RSI ({current_rsi:.1f})"

        stop_loss = current_price - 2 * current_atr if signal == Signal.BUY else None
        take_profit = current_price + 3 * current_atr if signal == Signal.BUY else None
        if signal == Signal.SELL:
            stop_loss = current_price + 2 * current_atr
            take_profit = current_price - 3 * current_atr

        return TradeSignal(
            signal=signal, symbol=symbol, strategy=self.name,
            confidence=confidence, price=current_price,
            stop_loss=stop_loss, take_profit=take_profit, reason=reason,
        )

    @staticmethod
    def _bullish_divergence(price: pd.Series, rsi_vals: pd.Series) -> bool:
        """Price makes lower low, RSI makes higher low."""
        if len(price) < 10:
            return False
        mid = len(price) // 2
        p1_low = price.iloc[:mid].min()
        p2_low = price.iloc[mid:].min()
        r1_low = rsi_vals.iloc[:mid].min()
        r2_low = rsi_vals.iloc[mid:].min()
        return p2_low < p1_low and r2_low > r1_low

    @staticmethod
    def _bearish_divergence(price: pd.Series, rsi_vals: pd.Series) -> bool:
        """Price makes higher high, RSI makes lower high."""
        if len(price) < 10:
            return False
        mid = len(price) // 2
        p1_high = price.iloc[:mid].max()
        p2_high = price.iloc[mid:].max()
        r1_high = rsi_vals.iloc[:mid].max()
        r2_high = rsi_vals.iloc[mid:].max()
        return p2_high > p1_high and r2_high < r1_high
