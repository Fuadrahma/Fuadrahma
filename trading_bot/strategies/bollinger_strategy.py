"""
Bollinger Bands Strategy
Mean reversion + breakout detection with squeeze indicator.
"""

import pandas as pd
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal
from trading_bot.utils.indicators import bollinger_bands, atr, rsi, keltner_channels


class BollingerStrategy(BaseStrategy):
    name = "bollinger"
    weight = 1.1

    def __init__(self, config=None):
        super().__init__(config)
        cfg = config.strategy if config else None
        self.period = getattr(cfg, "bb_period", 20)
        self.std_dev = getattr(cfg, "bb_std", 2.0)

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        close = df["close"]
        high = df["high"]
        low = df["low"]

        bb = bollinger_bands(close, self.period, self.std_dev)
        kc = keltner_channels(high, low, close)
        rsi_vals = rsi(close, 14)
        atr_val = atr(high, low, close, 14)

        current_price = self._last(close)
        prev_price = self._prev(close)
        curr_upper = self._last(bb["upper"])
        curr_lower = self._last(bb["lower"])
        curr_mid = self._last(bb["middle"])
        curr_pct_b = self._last(bb["pct_b"])
        curr_bw = self._last(bb["bandwidth"])
        prev_bw = self._prev(bb["bandwidth"])
        curr_rsi = self._last(rsi_vals)
        current_atr = self._last(atr_val)

        # Bollinger Squeeze: BB inside Keltner Channels
        kc_upper = self._last(kc["upper"])
        kc_lower = self._last(kc["lower"])
        squeeze = curr_upper < kc_upper and curr_lower > kc_lower

        signal = Signal.HOLD
        confidence = 0.0
        reason = ""

        if squeeze:
            # After squeeze release, trade in momentum direction
            if not (self._prev(bb["upper"]) < kc_upper and self._prev(bb["lower"]) > kc_lower):
                if current_price > curr_mid:
                    signal = Signal.BUY
                    confidence = 0.70
                    reason = "Bollinger squeeze breakout (upward)"
                else:
                    signal = Signal.SELL
                    confidence = 0.70
                    reason = "Bollinger squeeze breakout (downward)"
        else:
            # Mean reversion signals
            if current_price <= curr_lower and curr_rsi < 40:
                signal = Signal.BUY
                confidence = 0.65 + 0.1 * (1 - curr_pct_b)
                reason = f"Price at lower BB + RSI={curr_rsi:.1f}"

            elif current_price >= curr_upper and curr_rsi > 60:
                signal = Signal.SELL
                confidence = 0.65 + 0.1 * curr_pct_b
                reason = f"Price at upper BB + RSI={curr_rsi:.1f}"

            # Breakout signals (expanding bands)
            elif curr_bw > prev_bw * 1.2:
                if prev_price < curr_mid <= current_price:
                    signal = Signal.BUY
                    confidence = 0.55
                    reason = "BB expanding bullish breakout through midline"
                elif prev_price > curr_mid >= current_price:
                    signal = Signal.SELL
                    confidence = 0.55
                    reason = "BB expanding bearish breakdown through midline"

        stop_loss = current_price - 2 * current_atr if signal == Signal.BUY else None
        take_profit = curr_upper if signal == Signal.BUY else None
        if signal == Signal.SELL:
            stop_loss = current_price + 2 * current_atr
            take_profit = curr_lower

        return TradeSignal(
            signal=signal, symbol=symbol, strategy=self.name,
            confidence=confidence, price=current_price,
            stop_loss=stop_loss, take_profit=take_profit, reason=reason,
        )
