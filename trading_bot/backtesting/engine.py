"""
Backtesting Engine
Walk-forward simulation with full PnL accounting, commission, slippage,
and comprehensive performance metrics.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from datetime import datetime

import pandas as pd
import numpy as np

from trading_bot.strategies.base import Signal, TradeSignal
from trading_bot.strategies.ensemble import EnsembleStrategy
from trading_bot.utils.logger import get_logger

logger = get_logger("backtest.engine")


@dataclass
class BacktestTrade:
    symbol: str
    side: str
    entry_time: datetime
    exit_time: datetime
    entry_price: float
    exit_price: float
    quantity: float
    pnl: float
    pnl_pct: float
    commission: float
    exit_reason: str
    strategy: str


@dataclass
class BacktestResult:
    symbol: str
    initial_capital: float
    final_capital: float
    trades: List[BacktestTrade] = field(default_factory=list)
    equity_curve: pd.Series = field(default_factory=pd.Series)

    @property
    def total_pnl(self) -> float:
        return self.final_capital - self.initial_capital

    @property
    def total_return_pct(self) -> float:
        return self.total_pnl / self.initial_capital

    @property
    def total_trades(self) -> int:
        return len(self.trades)

    @property
    def win_rate(self) -> float:
        if not self.trades:
            return 0.0
        wins = sum(1 for t in self.trades if t.pnl > 0)
        return wins / self.total_trades

    @property
    def profit_factor(self) -> float:
        gains = sum(t.pnl for t in self.trades if t.pnl > 0)
        losses = abs(sum(t.pnl for t in self.trades if t.pnl <= 0))
        return gains / losses if losses else float("inf")

    @property
    def max_drawdown(self) -> float:
        if self.equity_curve.empty:
            return 0.0
        roll_max = self.equity_curve.cummax()
        dd = (self.equity_curve - roll_max) / roll_max
        return abs(dd.min())

    @property
    def sharpe_ratio(self) -> float:
        if self.equity_curve.empty or len(self.equity_curve) < 2:
            return 0.0
        returns = self.equity_curve.pct_change().dropna()
        if returns.std() == 0:
            return 0.0
        return (returns.mean() / returns.std()) * math.sqrt(252)

    @property
    def sortino_ratio(self) -> float:
        if self.equity_curve.empty or len(self.equity_curve) < 2:
            return 0.0
        returns = self.equity_curve.pct_change().dropna()
        downside = returns[returns < 0]
        if downside.empty or downside.std() == 0:
            return 0.0
        return (returns.mean() / downside.std()) * math.sqrt(252)

    @property
    def calmar_ratio(self) -> float:
        if self.max_drawdown == 0:
            return 0.0
        return self.total_return_pct / self.max_drawdown

    @property
    def avg_trade_duration_bars(self) -> float:
        if not self.trades:
            return 0.0
        return sum(
            (t.exit_time - t.entry_time).total_seconds()
            for t in self.trades
        ) / len(self.trades) / 3600  # in hours

    def summary(self) -> str:
        lines = [
            f"{'═' * 55}",
            f"  BACKTEST RESULTS — {self.symbol}",
            f"{'═' * 55}",
            f"  Capital:       {self.initial_capital:>12,.2f} → {self.final_capital:>12,.2f}",
            f"  Total Return:  {self.total_return_pct:>+11.2%}",
            f"  Total PnL:     {self.total_pnl:>+12.4f}",
            f"{'─' * 55}",
            f"  Trades:        {self.total_trades:>12}",
            f"  Win Rate:      {self.win_rate:>12.1%}",
            f"  Profit Factor: {self.profit_factor:>12.2f}",
            f"{'─' * 55}",
            f"  Sharpe Ratio:  {self.sharpe_ratio:>12.3f}",
            f"  Sortino Ratio: {self.sortino_ratio:>12.3f}",
            f"  Calmar Ratio:  {self.calmar_ratio:>12.3f}",
            f"  Max Drawdown:  {self.max_drawdown:>12.2%}",
            f"  Avg Duration:  {self.avg_trade_duration_bars:>10.1f} hrs",
            f"{'═' * 55}",
        ]
        return "\n".join(lines)


class BacktestEngine:
    """
    Walk-forward backtesting engine.
    Each bar generates a signal; positions are held until SL/TP or reversal.
    """

    def __init__(self, strategy: EnsembleStrategy, config=None):
        self.strategy = strategy
        self.cfg = config.backtest if config else None
        self.initial_capital = getattr(self.cfg, "initial_capital", 10_000.0)
        self.commission_pct = getattr(self.cfg, "commission_pct", 0.001)
        self.slippage_pct = getattr(self.cfg, "slippage_pct", 0.0005)
        self.sl_pct = getattr(config.risk if config else None, "stop_loss_pct", 0.02) if config else 0.02
        self.tp_pct = getattr(config.risk if config else None, "take_profit_pct", 0.04) if config else 0.04
        self.max_pos_pct = getattr(config.risk if config else None, "max_position_size_pct", 0.05) if config else 0.05
        self.min_bars = 50  # warm-up period before trading

    def run(self, df: pd.DataFrame, symbol: str) -> BacktestResult:
        logger.info(f"Starting backtest for {symbol} | {len(df)} bars")
        capital = self.initial_capital
        equity_curve: List[Tuple[datetime, float]] = []
        trades: List[BacktestTrade] = []

        # Position state
        in_trade = False
        side: str = ""
        entry_price: float = 0.0
        stop_loss: float = 0.0
        take_profit: float = 0.0
        quantity: float = 0.0
        entry_time: Optional[datetime] = None
        entry_strategy: str = ""

        for i in range(self.min_bars, len(df)):
            window = df.iloc[:i + 1]
            current_bar = df.iloc[i]
            current_time = df.index[i]
            high = current_bar["high"]
            low = current_bar["low"]
            close = current_bar["close"]

            if in_trade:
                exit_price, exit_reason = self._check_exit(
                    side, high, low, close, stop_loss, take_profit
                )
                if exit_price is not None:
                    pnl, commission, net = self._calc_pnl(
                        side, entry_price, exit_price, quantity
                    )
                    capital += net
                    trades.append(BacktestTrade(
                        symbol=symbol, side=side,
                        entry_time=entry_time, exit_time=current_time,
                        entry_price=entry_price, exit_price=exit_price,
                        quantity=quantity, pnl=pnl, pnl_pct=pnl / (entry_price * quantity),
                        commission=commission, exit_reason=exit_reason,
                        strategy=entry_strategy,
                    ))
                    in_trade = False

            if not in_trade and i % 1 == 0:  # signal every bar
                try:
                    sig: TradeSignal = self.strategy.generate_signal(window, symbol)
                except Exception:
                    equity_curve.append((current_time, capital))
                    continue

                if sig.signal != Signal.HOLD and sig.confidence >= 0.40:
                    notional = capital * self.max_pos_pct * sig.confidence
                    slip = self.slippage_pct if sig.signal == Signal.BUY else -self.slippage_pct
                    ep = close * (1 + slip)
                    qty = notional / ep
                    commission_cost = ep * qty * self.commission_pct
                    capital -= commission_cost

                    in_trade = True
                    side = "long" if sig.signal == Signal.BUY else "short"
                    entry_price = ep
                    quantity = qty
                    entry_time = current_time
                    entry_strategy = sig.strategy

                    if side == "long":
                        stop_loss = sig.stop_loss or ep * (1 - self.sl_pct)
                        take_profit = sig.take_profit or ep * (1 + self.tp_pct)
                    else:
                        stop_loss = sig.stop_loss or ep * (1 + self.sl_pct)
                        take_profit = sig.take_profit or ep * (1 - self.tp_pct)

            equity_curve.append((current_time, capital))

        # Close any open position at end of data
        if in_trade:
            close = df["close"].iloc[-1]
            pnl, commission, net = self._calc_pnl(side, entry_price, close, quantity)
            capital += net
            trades.append(BacktestTrade(
                symbol=symbol, side=side,
                entry_time=entry_time, exit_time=df.index[-1],
                entry_price=entry_price, exit_price=close,
                quantity=quantity, pnl=pnl, pnl_pct=pnl / (entry_price * quantity),
                commission=commission, exit_reason="end_of_data",
                strategy=entry_strategy,
            ))

        eq_ts = [t for t, _ in equity_curve]
        eq_vals = [v for _, v in equity_curve]
        eq_series = pd.Series(eq_vals, index=pd.DatetimeIndex(eq_ts))

        result = BacktestResult(
            symbol=symbol,
            initial_capital=self.initial_capital,
            final_capital=capital,
            trades=trades,
            equity_curve=eq_series,
        )
        logger.info(f"Backtest complete: {result.total_trades} trades | "
                    f"return={result.total_return_pct:+.2%} | sharpe={result.sharpe_ratio:.2f}")
        return result

    def _check_exit(self, side: str, high: float, low: float, close: float,
                    stop_loss: float, take_profit: float) -> Tuple[Optional[float], str]:
        if side == "long":
            if low <= stop_loss:
                return stop_loss, "stop_loss"
            if high >= take_profit:
                return take_profit, "take_profit"
        else:
            if high >= stop_loss:
                return stop_loss, "stop_loss"
            if low <= take_profit:
                return take_profit, "take_profit"
        return None, ""

    def _calc_pnl(self, side: str, entry: float, exit_: float,
                   qty: float) -> Tuple[float, float, float]:
        if side == "long":
            gross_pnl = (exit_ - entry) * qty
        else:
            gross_pnl = (entry - exit_) * qty
        commission = (entry + exit_) * qty * self.commission_pct * 0.5
        return gross_pnl, commission, gross_pnl - commission
