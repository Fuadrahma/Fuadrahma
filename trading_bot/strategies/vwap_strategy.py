"""
VWAP Strategy
Price vs. VWAP position with volume confirmation and MFI filter.
"""

import pandas as pd
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal
from trading_bot.utils.indicators import vwap, atr, mfi, obv, rsi


class VWAPStrategy(BaseStrategy):
    name = "vwap"
    weight = 1.0

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        close = df["close"]
        high = df["high"]
        low = df["low"]
        volume = df["volume"]

        vwap_vals = vwap(high, low, close, volume)
        mfi_vals = mfi(high, low, close, volume, 14)
        obv_vals = obv(close, volume)
        rsi_vals = rsi(close, 14)
        atr_val = atr(high, low, close, 14)

        current_price = self._last(close)
        prev_price = self._prev(close)
        curr_vwap = self._last(vwap_vals)
        prev_vwap = self._prev(vwap_vals)
        curr_mfi = self._last(mfi_vals)
        curr_rsi = self._last(rsi_vals)
        current_atr = self._last(atr_val)

        # OBV trend
        obv_trend = obv_vals.diff(5).iloc[-1]
        vol_trend = volume.rolling(10).mean().iloc[-1] / volume.rolling(20).mean().iloc[-1]

        signal = Signal.HOLD
        confidence = 0.0
        reason = ""

        # Price crosses above VWAP (bullish)
        if prev_price < prev_vwap and current_price >= curr_vwap:
            base_conf = 0.55
            if curr_mfi > 50:
                base_conf += 0.10
            if obv_trend > 0:
                base_conf += 0.10
            if vol_trend > 1.1:
                base_conf += 0.05
            signal = Signal.BUY
            confidence = min(base_conf, 0.90)
            reason = f"Price crossed above VWAP | MFI={curr_mfi:.1f}"

        # Price crosses below VWAP (bearish)
        elif prev_price > prev_vwap and current_price <= curr_vwap:
            base_conf = 0.55
            if curr_mfi < 50:
                base_conf += 0.10
            if obv_trend < 0:
                base_conf += 0.10
            if vol_trend > 1.1:
                base_conf += 0.05
            signal = Signal.SELL
            confidence = min(base_conf, 0.90)
            reason = f"Price crossed below VWAP | MFI={curr_mfi:.1f}"

        # Strong VWAP trend continuation
        elif current_price > curr_vwap * 1.005 and curr_mfi > 60 and obv_trend > 0:
            if curr_rsi < 70:
                signal = Signal.BUY
                confidence = 0.50
                reason = f"Price riding above VWAP | MFI={curr_mfi:.1f} OBV bullish"

        elif current_price < curr_vwap * 0.995 and curr_mfi < 40 and obv_trend < 0:
            if curr_rsi > 30:
                signal = Signal.SELL
                confidence = 0.50
                reason = f"Price riding below VWAP | MFI={curr_mfi:.1f} OBV bearish"

        stop_loss = current_price - 1.5 * current_atr if signal == Signal.BUY else None
        take_profit = current_price + 3 * current_atr if signal == Signal.BUY else None
        if signal == Signal.SELL:
            stop_loss = current_price + 1.5 * current_atr
            take_profit = current_price - 3 * current_atr

        return TradeSignal(
            signal=signal, symbol=symbol, strategy=self.name,
            confidence=confidence, price=current_price,
            stop_loss=stop_loss, take_profit=take_profit, reason=reason,
        )
