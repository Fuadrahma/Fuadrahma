"""
Ensemble Strategy — aggregates signals from multiple strategies.
Methods: weighted_vote, majority, unanimous, confidence_weighted.
"""

from typing import List, Dict
import pandas as pd
from trading_bot.strategies.base import BaseStrategy, TradeSignal, Signal


class EnsembleStrategy:
    """Combines multiple strategy signals into a single consensus signal."""

    def __init__(self, strategies: List[BaseStrategy], method: str = "weighted_vote",
                 min_confidence: float = 0.40):
        self.strategies = strategies
        self.method = method
        self.min_confidence = min_confidence

    def generate_signal(self, df: pd.DataFrame, symbol: str) -> TradeSignal:
        signals: List[TradeSignal] = []
        for strat in self.strategies:
            try:
                sig = strat.generate_signal(df, symbol)
                signals.append(sig)
            except Exception:
                pass

        if not signals:
            current_price = df["close"].iloc[-1]
            return TradeSignal(Signal.HOLD, symbol, "ensemble", 0.0, current_price)

        if self.method == "weighted_vote":
            return self._weighted_vote(signals, symbol)
        elif self.method == "majority":
            return self._majority(signals, symbol)
        elif self.method == "unanimous":
            return self._unanimous(signals, symbol)
        else:
            return self._confidence_weighted(signals, symbol)

    def _weighted_vote(self, signals: List[TradeSignal], symbol: str) -> TradeSignal:
        buy_score = 0.0
        sell_score = 0.0
        active_weight = 0.0   # weight of strategies that gave non-HOLD signals
        total_weight = 0.0
        reasons = []
        current_price = signals[0].price

        strat_weight = {s.name: s.weight for s in self.strategies}

        for sig in signals:
            weight = strat_weight.get(sig.strategy, 1.0)
            total_weight += weight
            score = sig.confidence * weight
            if sig.signal == Signal.BUY:
                buy_score += score
                active_weight += weight
                reasons.append(f"+{sig.strategy}({sig.confidence:.2f})")
            elif sig.signal == Signal.SELL:
                sell_score += score
                active_weight += weight
                reasons.append(f"-{sig.strategy}({sig.confidence:.2f})")

        # Use active_weight as denominator so HOLD strategies don't dilute the signal
        denominator = active_weight if active_weight > 0 else (total_weight or 1)
        net = (buy_score - sell_score) / denominator
        confidence = abs(net)

        if confidence < self.min_confidence:
            final_signal = Signal.HOLD
        elif net > 0:
            final_signal = Signal.BUY
        else:
            final_signal = Signal.SELL

        # Aggregate SL/TP from agreeing signals
        agreeing = [s for s in signals if s.signal == final_signal]
        stop_loss = None
        take_profit = None
        if agreeing:
            sls = [s.stop_loss for s in agreeing if s.stop_loss is not None]
            tps = [s.take_profit for s in agreeing if s.take_profit is not None]
            if sls:
                stop_loss = (min(sls) if final_signal == Signal.BUY else max(sls))
            if tps:
                take_profit = (max(tps) if final_signal == Signal.BUY else min(tps))

        return TradeSignal(
            signal=final_signal, symbol=symbol, strategy="ensemble",
            confidence=min(confidence, 1.0), price=current_price,
            stop_loss=stop_loss, take_profit=take_profit,
            reason=f"Ensemble[{self.method}]: " + " | ".join(reasons[:5]),
        )

    def _majority(self, signals: List[TradeSignal], symbol: str) -> TradeSignal:
        buy_count = sum(1 for s in signals if s.signal == Signal.BUY)
        sell_count = sum(1 for s in signals if s.signal == Signal.SELL)
        n = len(signals)
        current_price = signals[0].price

        if buy_count > n / 2:
            conf = sum(s.confidence for s in signals if s.signal == Signal.BUY) / buy_count
            return TradeSignal(Signal.BUY, symbol, "ensemble", conf, current_price,
                               reason=f"Majority BUY ({buy_count}/{n})")
        elif sell_count > n / 2:
            conf = sum(s.confidence for s in signals if s.signal == Signal.SELL) / sell_count
            return TradeSignal(Signal.SELL, symbol, "ensemble", conf, current_price,
                               reason=f"Majority SELL ({sell_count}/{n})")
        return TradeSignal(Signal.HOLD, symbol, "ensemble", 0.0, current_price,
                           reason=f"No majority (BUY={buy_count}, SELL={sell_count})")

    def _unanimous(self, signals: List[TradeSignal], symbol: str) -> TradeSignal:
        current_price = signals[0].price
        non_hold = [s for s in signals if s.signal != Signal.HOLD]
        if not non_hold:
            return TradeSignal(Signal.HOLD, symbol, "ensemble", 0.0, current_price)
        first = non_hold[0].signal
        if all(s.signal == first for s in non_hold):
            conf = sum(s.confidence for s in non_hold) / len(non_hold)
            return TradeSignal(first, symbol, "ensemble", conf, current_price,
                               reason=f"Unanimous {first.name}")
        return TradeSignal(Signal.HOLD, symbol, "ensemble", 0.0, current_price,
                           reason="Conflicting signals — no consensus")

    def _confidence_weighted(self, signals: List[TradeSignal], symbol: str) -> TradeSignal:
        buy_conf = sum(s.confidence for s in signals if s.signal == Signal.BUY)
        sell_conf = sum(s.confidence for s in signals if s.signal == Signal.SELL)
        total_conf = buy_conf + sell_conf or 1
        current_price = signals[0].price
        net = (buy_conf - sell_conf) / total_conf
        if abs(net) < self.min_confidence:
            return TradeSignal(Signal.HOLD, symbol, "ensemble", 0.0, current_price)
        final = Signal.BUY if net > 0 else Signal.SELL
        return TradeSignal(final, symbol, "ensemble", abs(net), current_price,
                           reason=f"Confidence-weighted {final.name} (net={net:.2f})")
