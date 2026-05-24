"""Multi-indicator composite strategy combining RSI + MACD + BB + EMA."""

from __future__ import annotations

from datetime import datetime
from typing import Any

import pandas as pd
from ta.momentum import RSIIndicator
from ta.trend import MACD as MACDIndicator, EMAIndicator
from ta.volatility import BollingerBands

from bot.core.models import Signal, SignalType
from bot.strategies.base import Strategy


class MultiIndicatorStrategy(Strategy):
    """
    Confluence-based strategy requiring agreement from multiple indicators.

    Buy when >= 3 indicators agree on bullish signal.
    Sell when >= 3 indicators agree on bearish signal.
    """

    name = "multi_indicator"

    def __init__(self, params: dict[str, Any] | None = None) -> None:
        super().__init__(params)
        self.rsi_period = self.params.get("rsi_period", 14)
        self.rsi_overbought = self.params.get("rsi_overbought", 70)
        self.rsi_oversold = self.params.get("rsi_oversold", 30)
        self.macd_fast = self.params.get("macd_fast", 12)
        self.macd_slow = self.params.get("macd_slow", 26)
        self.macd_signal = self.params.get("macd_signal", 9)
        self.bb_period = self.params.get("bb_period", 20)
        self.bb_std = self.params.get("bb_std", 2.0)
        self.ema_fast = self.params.get("ema_fast", 9)
        self.ema_slow = self.params.get("ema_slow", 21)
        self._min_rows = max(
            self.macd_slow + self.macd_signal, self.bb_period, self.ema_slow
        ) + 2

    def analyze(self, df: pd.DataFrame) -> Signal:
        self._require_rows(df, self._min_rows)

        price = float(df["close"].iloc[-1])
        ts = df.index[-1] if isinstance(df.index[-1], datetime) else datetime.utcnow()

        buy_votes = 0
        sell_votes = 0
        meta: dict[str, Any] = {}

        # --- RSI ---
        rsi = RSIIndicator(close=df["close"], window=self.rsi_period).rsi()
        curr_rsi = float(rsi.iloc[-1])
        meta["rsi"] = curr_rsi
        if curr_rsi < self.rsi_oversold:
            buy_votes += 1
        elif curr_rsi > self.rsi_overbought:
            sell_votes += 1

        # --- MACD ---
        macd_ind = MACDIndicator(
            close=df["close"],
            window_fast=self.macd_fast,
            window_slow=self.macd_slow,
            window_sign=self.macd_signal,
        )
        hist = macd_ind.macd_diff()
        prev_hist, curr_hist = float(hist.iloc[-2]), float(hist.iloc[-1])
        meta["macd_hist"] = curr_hist
        if prev_hist <= 0 and curr_hist > 0:
            buy_votes += 1
        elif prev_hist >= 0 and curr_hist < 0:
            sell_votes += 1

        # --- Bollinger Bands ---
        bb = BollingerBands(
            close=df["close"], window=self.bb_period, window_dev=self.bb_std
        )
        lower_bb = float(bb.bollinger_lband().iloc[-1])
        upper_bb = float(bb.bollinger_hband().iloc[-1])
        meta["bb_lower"] = lower_bb
        meta["bb_upper"] = upper_bb
        if price < lower_bb:
            buy_votes += 1
        elif price > upper_bb:
            sell_votes += 1

        # --- EMA crossover ---
        fast_ema = EMAIndicator(close=df["close"], window=self.ema_fast).ema_indicator()
        slow_ema = EMAIndicator(close=df["close"], window=self.ema_slow).ema_indicator()
        curr_fast = float(fast_ema.iloc[-1])
        prev_fast = float(fast_ema.iloc[-2])
        curr_slow = float(slow_ema.iloc[-1])
        prev_slow = float(slow_ema.iloc[-2])
        meta["ema_fast"] = curr_fast
        meta["ema_slow"] = curr_slow

        if prev_fast <= prev_slow and curr_fast > curr_slow:
            buy_votes += 1
        elif prev_fast >= prev_slow and curr_fast < curr_slow:
            sell_votes += 1

        meta["buy_votes"] = buy_votes
        meta["sell_votes"] = sell_votes
        total_indicators = 4
        threshold = 3

        if buy_votes >= threshold:
            return Signal(
                type=SignalType.BUY,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=buy_votes / total_indicators,
                metadata=meta,
            )

        if sell_votes >= threshold:
            return Signal(
                type=SignalType.SELL,
                symbol="",
                price=price,
                timestamp=ts,
                strategy=self.name,
                confidence=sell_votes / total_indicators,
                metadata=meta,
            )

        return Signal(
            type=SignalType.HOLD,
            symbol="",
            price=price,
            timestamp=ts,
            strategy=self.name,
            metadata=meta,
        )
