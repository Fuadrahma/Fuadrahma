"""
Vectorized backtesting engine with full performance analytics.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass, field
from typing import List, Dict, Optional
import numpy as np
import pandas as pd

from trading_bot.strategies.base import BaseStrategy, SignalType
from trading_bot.risk_management.manager import RiskManager, PortfolioState

logger = logging.getLogger(__name__)


@dataclass
class BacktestResult:
    symbol: str
    strategy_name: str
    initial_balance: float
    final_balance: float
    total_return_pct: float
    annualized_return_pct: float
    max_drawdown_pct: float
    sharpe_ratio: float
    sortino_ratio: float
    calmar_ratio: float
    win_rate: float
    total_trades: int
    winning_trades: int
    losing_trades: int
    avg_trade_pct: float
    avg_win_pct: float
    avg_loss_pct: float
    profit_factor: float
    max_consecutive_losses: int
    trades: List[dict] = field(default_factory=list)
    equity_curve: List[float] = field(default_factory=list)

    def __str__(self) -> str:
        return (
            f"\n{'='*60}\n"
            f"  Backtest: {self.strategy_name} on {self.symbol}\n"
            f"{'='*60}\n"
            f"  Initial Balance : ${self.initial_balance:,.2f}\n"
            f"  Final Balance   : ${self.final_balance:,.2f}\n"
            f"  Total Return    : {self.total_return_pct:+.2f}%\n"
            f"  Ann. Return     : {self.annualized_return_pct:+.2f}%\n"
            f"  Max Drawdown    : {self.max_drawdown_pct:.2f}%\n"
            f"  Sharpe Ratio    : {self.sharpe_ratio:.3f}\n"
            f"  Sortino Ratio   : {self.sortino_ratio:.3f}\n"
            f"  Calmar Ratio    : {self.calmar_ratio:.3f}\n"
            f"  Win Rate        : {self.win_rate:.1%}\n"
            f"  Total Trades    : {self.total_trades}\n"
            f"  Profit Factor   : {self.profit_factor:.2f}\n"
            f"  Avg Trade       : {self.avg_trade_pct:+.2f}%\n"
            f"  Avg Win         : {self.avg_win_pct:+.2f}%\n"
            f"  Avg Loss        : {self.avg_loss_pct:+.2f}%\n"
            f"  Max Consec Loss : {self.max_consecutive_losses}\n"
            f"{'='*60}\n"
        )


class Backtester:
    """Event-driven backtester that reuses the live trading logic."""

    def __init__(
        self,
        strategy: BaseStrategy,
        initial_balance: float = 10_000.0,
        commission: float = 0.001,   # 0.1% Taker fee
        slippage: float = 0.0005,    # 0.05%
        config=None,
    ):
        self.strategy = strategy
        self.initial_balance = initial_balance
        self.commission = commission
        self.slippage = slippage
        self.risk_manager = RiskManager(config)

    def run(self, df: pd.DataFrame, symbol: str) -> BacktestResult:
        """
        Run backtest on OHLCV DataFrame.
        Requires at least 250 rows for reliable indicator warm-up.
        """
        WARMUP = 200
        if len(df) < WARMUP + 10:
            raise ValueError(f"Not enough data: {len(df)} rows < {WARMUP + 10}")

        portfolio = PortfolioState(
            balance=self.initial_balance,
            initial_balance=self.initial_balance,
        )
        equity_curve: List[float] = []

        for i in range(WARMUP, len(df)):
            window = df.iloc[:i+1]
            current_price = window.iloc[-1]["close"]
            ts = window.index[-1]

            # Update existing positions
            exits = self.risk_manager.check_exits(
                portfolio, {symbol: current_price}
            )
            for sym, reason in exits:
                exit_price = current_price * (1 - self.slippage)
                self.risk_manager.close_position(sym, exit_price, reason, portfolio)

            # Generate signal
            signal = self.strategy.generate_signal(window, symbol)

            # Entry
            if signal.is_entry and symbol not in portfolio.open_positions:
                # Apply slippage to entry
                signal.price = signal.price * (1 + self.slippage)
                if signal.stop_loss:
                    signal.stop_loss = signal.stop_loss * (1 - self.slippage)
                pos = self.risk_manager.open_position(signal, portfolio)
                if pos:
                    # Deduct commission
                    commission_cost = pos.quantity * pos.entry_price * self.commission
                    portfolio.balance -= commission_cost

            # Exit signal
            elif signal.is_exit and symbol in portfolio.open_positions:
                exit_price = current_price * (1 - self.slippage)
                self.risk_manager.close_position(symbol, exit_price, "signal", portfolio)

            equity_curve.append(portfolio.equity)

        # Close all remaining positions at last price
        last_price = df.iloc[-1]["close"]
        for symbol_open in list(portfolio.open_positions.keys()):
            self.risk_manager.close_position(symbol_open, last_price, "end_of_test", portfolio)

        return self._compute_metrics(
            portfolio, equity_curve, df, symbol
        )

    def _compute_metrics(
        self,
        portfolio: PortfolioState,
        equity_curve: List[float],
        df: pd.DataFrame,
        symbol: str,
    ) -> BacktestResult:
        trades = portfolio.closed_trades
        initial = self.initial_balance
        final = portfolio.equity
        total_return = (final - initial) / initial * 100

        eq = pd.Series(equity_curve)
        daily_returns = eq.pct_change().dropna()

        # Annualized return
        n_periods = len(df)
        if n_periods > 0:
            periods_per_year = self._periods_per_year(df)
            ann_factor = periods_per_year / n_periods
            ann_return = ((final / initial) ** ann_factor - 1) * 100
            ann_return = float(ann_return) if np.isfinite(ann_return) else total_return
        else:
            ann_return = 0.0

        # Max drawdown
        peak = eq.cummax()
        dd = ((eq - peak) / peak).min() * 100

        # Sharpe/Sortino
        rf_rate = 0.04 / periods_per_year if n_periods > 0 else 0.0
        excess = daily_returns - rf_rate
        sharpe = (excess.mean() / excess.std() * np.sqrt(periods_per_year)) if (len(excess) > 0 and excess.std() > 0) else 0.0
        sharpe = float(sharpe) if np.isfinite(sharpe) else 0.0
        downside = daily_returns[daily_returns < 0].std()
        sortino = (excess.mean() / downside * np.sqrt(periods_per_year)) if (len(excess) > 0 and downside > 0) else 0.0
        sortino = float(sortino) if np.isfinite(sortino) else 0.0

        # Calmar
        calmar = ann_return / abs(dd) if abs(dd) > 0 else 0.0
        calmar = float(calmar) if np.isfinite(calmar) else 0.0

        # Trade stats
        pnl_pcts = [t["pnl_pct"] * 100 for t in trades]
        wins = [p for p in pnl_pcts if p > 0]
        losses = [p for p in pnl_pcts if p <= 0]
        win_rate = len(wins) / len(trades) if trades else 0.0
        avg_trade = np.mean(pnl_pcts) if pnl_pcts else 0.0
        avg_win = np.mean(wins) if wins else 0.0
        avg_loss = np.mean(losses) if losses else 0.0
        gross_profit = sum(t["pnl"] for t in trades if t["pnl"] > 0)
        gross_loss = abs(sum(t["pnl"] for t in trades if t["pnl"] <= 0))
        profit_factor = gross_profit / gross_loss if gross_loss > 0 else (gross_profit if gross_profit > 0 else 0.0)

        # Max consecutive losses
        max_consec = 0
        current_consec = 0
        for t in trades:
            if t["pnl"] <= 0:
                current_consec += 1
                max_consec = max(max_consec, current_consec)
            else:
                current_consec = 0

        return BacktestResult(
            symbol=symbol,
            strategy_name=self.strategy.name,
            initial_balance=initial,
            final_balance=final,
            total_return_pct=total_return,
            annualized_return_pct=ann_return,
            max_drawdown_pct=abs(dd),
            sharpe_ratio=sharpe,
            sortino_ratio=sortino,
            calmar_ratio=calmar,
            win_rate=win_rate,
            total_trades=len(trades),
            winning_trades=len(wins),
            losing_trades=len(losses),
            avg_trade_pct=avg_trade,
            avg_win_pct=avg_win,
            avg_loss_pct=avg_loss,
            profit_factor=profit_factor,
            max_consecutive_losses=max_consec,
            trades=trades,
            equity_curve=equity_curve,
        )

    @staticmethod
    def _periods_per_year(df: pd.DataFrame) -> float:
        """Estimate candle periods per year from DataFrame index."""
        if len(df) < 2:
            return 365.0
        delta = (df.index[-1] - df.index[-2]).total_seconds()
        seconds_per_year = 365.25 * 24 * 3600
        return seconds_per_year / delta if delta > 0 else 365.0
