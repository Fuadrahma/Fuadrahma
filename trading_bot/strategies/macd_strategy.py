"""
MACD Strategy
Signal line crossover + zero-line crossover + histogram momentum.
"""

import pandas as pd
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal
from trading_bot.utils.indicators import macd, atr, adx


class MACDStrategy(BaseStrategy):
    name = "macd"
    weight = 1.3

    def __init__(self, config=None):
        super().__init__(config)
        cfg = config.strategy if config else None
        self.fast = getattr(cfg, "macd_fast", 12)
        self.slow = getattr(cfg, "macd_slow", 26)
        self.signal_period = getattr(cfg, "macd_signal", 9)
        self.adx_threshold = getattr(cfg, "adx_threshold", 25.0)

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        close = df["close"]
        high = df["high"]
        low = df["low"]

        macd_df = macd(close, self.fast, self.slow, self.signal_period)
        adx_df = adx(high, low, close, 14)
        atr_val = atr(high, low, close, 14)

        macd_line = macd_df["macd"]
        signal_line = macd_df["signal"]
        histogram = macd_df["histogram"]

        curr_macd = self._last(macd_line)
        prev_macd = self._prev(macd_line)
        curr_sig = self._last(signal_line)
        prev_sig = self._prev(signal_line)
        curr_hist = self._last(histogram)
        prev_hist = self._prev(histogram)
        curr_adx = self._last(adx_df["adx"])
        current_price = self._last(close)
        current_atr = self._last(atr_val)

        signal = Signal.HOLD
        confidence = 0.0
        reason = ""

        trend_filter = curr_adx > self.adx_threshold

        # Signal line bullish crossover
        if prev_macd < prev_sig and curr_macd >= curr_sig:
            signal = Signal.BUY
            confidence = 0.60 if not trend_filter else 0.75
            reason = f"MACD bullish crossover (ADX={curr_adx:.1f})"

        # Signal line bearish crossover
        elif prev_macd > prev_sig and curr_macd <= curr_sig:
            signal = Signal.SELL
            confidence = 0.60 if not trend_filter else 0.75
            reason = f"MACD bearish crossover (ADX={curr_adx:.1f})"

        # Zero-line crossover (stronger trend signal)
        elif prev_macd < 0 and curr_macd >= 0:
            signal = Signal.BUY
            confidence = 0.70
            reason = "MACD zero-line bullish cross"

        elif prev_macd > 0 and curr_macd <= 0:
            signal = Signal.SELL
            confidence = 0.70
            reason = "MACD zero-line bearish cross"

        # Histogram divergence (early signal)
        elif curr_macd < curr_sig and prev_hist < curr_hist < 0:
            signal = Signal.BUY
            confidence = 0.45
            reason = "MACD histogram bullish divergence"

        elif curr_macd > curr_sig and prev_hist > curr_hist > 0:
            signal = Signal.SELL
            confidence = 0.45
            reason = "MACD histogram bearish divergence"

        stop_loss = current_price - 2 * current_atr if signal == Signal.BUY else None
        take_profit = current_price + 4 * current_atr if signal == Signal.BUY else None
        if signal == Signal.SELL:
            stop_loss = current_price + 2 * current_atr
            take_profit = current_price - 4 * current_atr

        return TradeSignal(
            signal=signal, symbol=symbol, strategy=self.name,
            confidence=confidence, price=current_price,
            stop_loss=stop_loss, take_profit=take_profit, reason=reason,
        )
