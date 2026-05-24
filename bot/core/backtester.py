"""Backtesting engine – replay historical data through a strategy."""

from __future__ import annotations

import logging
from typing import Any

import pandas as pd
from rich.console import Console
from rich.table import Table

from bot.core.config import BacktestConfig, RiskConfig
from bot.core.models import Side, SignalType
from bot.core.portfolio import Portfolio
from bot.core.risk import RiskManager
from bot.strategies.base import Strategy

logger = logging.getLogger(__name__)
console = Console()


class Backtester:
    """Walk-forward backtester with commission and risk management."""

    def __init__(
        self,
        strategy: Strategy,
        risk_config: RiskConfig,
        backtest_config: BacktestConfig,
        symbol: str = "BTC/USDT",
    ) -> None:
        self.strategy = strategy
        self.risk_cfg = risk_config
        self.bt_cfg = backtest_config
        self.symbol = symbol

    def run(self, df: pd.DataFrame) -> dict[str, Any]:
        """
        Run backtest on the provided OHLCV DataFrame.

        Returns a summary dict with performance metrics.
        """
        portfolio = Portfolio(self.bt_cfg.initial_balance)
        risk_mgr = RiskManager(self.risk_cfg)

        min_window = 50
        if len(df) < min_window:
            raise ValueError(
                f"Need >= {min_window} rows for backtest, got {len(df)}"
            )

        logger.info(
            "Backtest START | strategy=%s | rows=%d | balance=%.2f",
            self.strategy.name,
            len(df),
            portfolio.balance,
        )

        for i in range(min_window, len(df)):
            window = df.iloc[: i + 1]
            current_price = float(window["close"].iloc[-1])

            risk_mgr.set_open_positions(portfolio.positions)
            pos = portfolio.get_position(self.symbol)
            if pos:
                should_close, reason = risk_mgr.should_close_position(
                    pos, current_price
                )
                if should_close:
                    trade = portfolio.close_position(
                        pos,
                        current_price,
                        strategy=self.strategy.name,
                        commission_pct=self.bt_cfg.commission_pct,
                    )
                    risk_mgr.record_pnl(trade.pnl)
                    logger.debug(
                        "Risk close (%s) at %.2f  pnl=%.2f",
                        reason,
                        current_price,
                        trade.pnl,
                    )
                    pos = None

                if pos and self.risk_cfg.trailing_stop:
                    new_ts = risk_mgr.update_trailing_stop(pos, current_price)
                    if new_ts is not None:
                        pos.trailing_stop_price = new_ts

            signal = self.strategy.analyze(window)
            signal.symbol = self.symbol

            if signal.type == SignalType.BUY and pos is None:
                allowed, reason = risk_mgr.can_open_trade(portfolio.balance)
                if allowed:
                    amount = risk_mgr.position_size(
                        portfolio.balance, current_price
                    )
                    if amount > 0:
                        sl = risk_mgr.stop_loss_price(current_price, Side.BUY)
                        tp = risk_mgr.take_profit_price(
                            current_price, Side.BUY
                        )
                        portfolio.open_position(
                            symbol=self.symbol,
                            side=Side.BUY,
                            price=current_price,
                            amount=amount,
                            stop_loss=sl,
                            take_profit=tp,
                        )

            elif signal.type == SignalType.SELL and pos is not None:
                trade = portfolio.close_position(
                    pos,
                    current_price,
                    strategy=self.strategy.name,
                    commission_pct=self.bt_cfg.commission_pct,
                )
                risk_mgr.record_pnl(trade.pnl)

            portfolio.snapshot({self.symbol: current_price})

        # Close any remaining positions at last price
        last_price = float(df["close"].iloc[-1])
        for pos in list(portfolio.positions):
            trade = portfolio.close_position(
                pos,
                last_price,
                strategy=self.strategy.name,
                commission_pct=self.bt_cfg.commission_pct,
            )
            risk_mgr.record_pnl(trade.pnl)

        summary = portfolio.summary()
        summary["strategy"] = self.strategy.name
        summary["symbol"] = self.symbol
        summary["period"] = f"{df.index[0]} → {df.index[-1]}"
        summary["equity_curve"] = portfolio.equity_curve

        logger.info("Backtest DONE | %s", summary)
        return summary

    @staticmethod
    def print_report(results: dict[str, Any]) -> None:
        """Pretty-print backtest results to the console."""
        table = Table(title="📊 Backtest Results", show_lines=True)
        table.add_column("Metric", style="cyan", justify="right")
        table.add_column("Value", style="green")

        table.add_row("Strategy", results.get("strategy", ""))
        table.add_row("Symbol", results.get("symbol", ""))
        table.add_row("Period", results.get("period", ""))
        table.add_row("Total Trades", str(results.get("total_trades", 0)))
        table.add_row("Winning Trades", str(results.get("winning_trades", 0)))
        table.add_row("Losing Trades", str(results.get("losing_trades", 0)))
        table.add_row(
            "Win Rate", f"{results.get('win_rate', 0) * 100:.1f}%"
        )
        table.add_row("Total P&L", f"${results.get('total_pnl', 0):,.2f}")
        table.add_row(
            "Return", f"{results.get('return_pct', 0):,.2f}%"
        )
        table.add_row(
            "Profit Factor", f"{results.get('profit_factor', 0):,.2f}"
        )
        table.add_row(
            "Max Drawdown", f"{results.get('max_drawdown_pct', 0):,.2f}%"
        )
        table.add_row("Final Balance", f"${results.get('balance', 0):,.2f}")

        console.print(table)
