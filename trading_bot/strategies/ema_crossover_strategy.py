"""
EMA Crossover Strategy (with Multi-Timeframe Trend Filter)
Fast EMA crosses above/below slow EMA, filtered by ADX and Supertrend.
"""

import pandas as pd
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal
from trading_bot.utils.indicators import ema, atr, adx, rsi


class EMACrossoverStrategy(BaseStrategy):
    name = "ema_crossover"
    weight = 1.25

    def __init__(self, config=None):
        super().__init__(config)
        cfg = config.strategy if config else None
        self.fast = getattr(cfg, "ema_fast", 9)
        self.slow = getattr(cfg, "ema_slow", 21)
        self.adx_threshold = getattr(cfg, "adx_threshold", 25.0)

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        close = df["close"]
        high = df["high"]
        low = df["low"]

        fast_ema = ema(close, self.fast)
        slow_ema = ema(close, self.slow)
        long_ema = ema(close, 50)   # trend filter
        very_long = ema(close, 200) # macro trend filter

        adx_df = adx(high, low, close, 14)
        atr_val = atr(high, low, close, 14)
        rsi_vals = rsi(close, 14)

        curr_fast = self._last(fast_ema)
        prev_fast = self._prev(fast_ema)
        curr_slow = self._last(slow_ema)
        prev_slow = self._prev(slow_ema)
        curr_long = self._last(long_ema)
        curr_very_long = self._last(very_long)
        curr_adx = self._last(adx_df["adx"])
        curr_plus_di = self._last(adx_df["plus_di"])
        curr_minus_di = self._last(adx_df["minus_di"])
        curr_rsi = self._last(rsi_vals)
        current_price = self._last(close)
        current_atr = self._last(atr_val)

        trend_filter = curr_adx > self.adx_threshold
        uptrend_context = current_price > curr_long > curr_very_long
        downtrend_context = current_price < curr_long < curr_very_long

        signal = Signal.HOLD
        confidence = 0.0
        reason = ""

        # Bullish crossover
        if prev_fast <= prev_slow and curr_fast > curr_slow:
            base_conf = 0.60
            if trend_filter:
                base_conf += 0.10
            if uptrend_context:
                base_conf += 0.15
            if curr_rsi > 50:
                base_conf += 0.05
            signal = Signal.BUY
            confidence = min(base_conf, 0.95)
            reason = (f"EMA{self.fast}/EMA{self.slow} bullish cross"
                      f" | ADX={curr_adx:.1f} | trend={'up' if uptrend_context else 'neutral'}")

        # Bearish crossover
        elif prev_fast >= prev_slow and curr_fast < curr_slow:
            base_conf = 0.60
            if trend_filter:
                base_conf += 0.10
            if downtrend_context:
                base_conf += 0.15
            if curr_rsi < 50:
                base_conf += 0.05
            signal = Signal.SELL
            confidence = min(base_conf, 0.95)
            reason = (f"EMA{self.fast}/EMA{self.slow} bearish cross"
                      f" | ADX={curr_adx:.1f} | trend={'down' if downtrend_context else 'neutral'}")

        # Trend riding: EMA alignment + DI direction
        elif curr_fast > curr_slow and curr_plus_di > curr_minus_di and trend_filter:
            if 45 < curr_rsi < 70:
                signal = Signal.BUY
                confidence = 0.50
                reason = f"EMA bullish alignment | DI+={curr_plus_di:.1f} DI-={curr_minus_di:.1f}"

        elif curr_fast < curr_slow and curr_minus_di > curr_plus_di and trend_filter:
            if 30 < curr_rsi < 55:
                signal = Signal.SELL
                confidence = 0.50
                reason = f"EMA bearish alignment | DI-={curr_minus_di:.1f} DI+={curr_plus_di:.1f}"

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
