"""Main trading engine – orchestrates exchange, strategy, risk, and portfolio."""

from __future__ import annotations

import logging
import time
from typing import Any

from rich.console import Console
from rich.live import Live
from rich.table import Table

from bot.core.config import BotConfig
from bot.core.exchange import ExchangeConnector
from bot.core.models import Side, SignalType
from bot.core.portfolio import Portfolio
from bot.core.risk import RiskManager
from bot.strategies.registry import get_strategy

logger = logging.getLogger(__name__)
console = Console()

TIMEFRAME_SECONDS = {
    "1m": 60,
    "5m": 300,
    "15m": 900,
    "30m": 1800,
    "1h": 3600,
    "4h": 14400,
    "1d": 86400,
}


class TradingEngine:
    """Real-time (paper / live) trading loop."""

    def __init__(self, config: BotConfig) -> None:
        self.config = config
        self.exchange = ExchangeConnector(config.exchange)
        strategy_params = config.strategies.get(config.trading.strategy, {})
        self.strategy = get_strategy(config.trading.strategy, strategy_params)
        self.risk_mgr = RiskManager(config.risk)
        self.portfolio = Portfolio(config.trading.initial_balance)
        self.symbol = config.trading.symbol
        self.timeframe = config.trading.timeframe
        self._running = False

    def _status_table(self) -> Table:
        summary = self.portfolio.summary()
        pos = self.portfolio.get_position(self.symbol)
        table = Table(title="🤖 Trading Bot Status")
        table.add_column("Field", style="cyan")
        table.add_column("Value", style="green")
        table.add_row("Mode", self.config.trading.mode.upper())
        table.add_row("Exchange", self.exchange.name)
        table.add_row("Symbol", self.symbol)
        table.add_row("Strategy", self.strategy.name)
        table.add_row("Balance", f"${self.portfolio.balance:,.2f}")
        table.add_row("Total Trades", str(summary["total_trades"]))
        table.add_row(
            "P&L", f"${summary.get('total_pnl', 0):,.2f}"
        )
        table.add_row(
            "Position",
            f"{pos.side.value.upper()} {pos.amount:.8f} @ {pos.entry_price:.2f}"
            if pos
            else "None",
        )
        return table

    def run(self) -> None:
        """Start the main trading loop."""
        self._running = True
        interval = TIMEFRAME_SECONDS.get(self.timeframe, 3600)

        console.print(
            f"[bold green]Starting {self.config.trading.mode.upper()} "
            f"trading on {self.symbol}[/bold green]"
        )
        console.print(f"Strategy: [bold]{self.strategy.name}[/bold]")
        console.print(f"Timeframe: {self.timeframe}  |  Interval: {interval}s")
        console.print("Press Ctrl+C to stop.\n")

        try:
            while self._running:
                self._tick()
                with Live(self._status_table(), refresh_per_second=1):
                    time.sleep(interval)
        except KeyboardInterrupt:
            console.print("\n[yellow]Shutting down...[/yellow]")
        finally:
            self._running = False
            self._close_all()
            console.print("[bold]Final portfolio summary:[/bold]")
            self._print_summary()

    def _tick(self) -> None:
        """Execute one analysis cycle."""
        try:
            df = self.exchange.fetch_ohlcv(
                self.symbol, self.timeframe, limit=200
            )
        except Exception as e:
            logger.error("Failed to fetch data: %s", e)
            return

        signal = self.strategy.analyze(df)
        signal.symbol = self.symbol

        current_price = float(df["close"].iloc[-1])
        pos = self.portfolio.get_position(self.symbol)

        self.risk_mgr.set_open_positions(self.portfolio.positions)

        if pos:
            should_close, reason = self.risk_mgr.should_close_position(
                pos, current_price
            )
            if should_close:
                self._execute_close(pos, current_price, reason)
                pos = None

            if pos and self.config.risk.trailing_stop:
                new_ts = self.risk_mgr.update_trailing_stop(pos, current_price)
                if new_ts is not None:
                    pos.trailing_stop_price = new_ts

        if signal.type == SignalType.BUY and pos is None:
            allowed, reason = self.risk_mgr.can_open_trade(
                self.portfolio.balance
            )
            if allowed:
                amount = self.risk_mgr.position_size(
                    self.portfolio.balance, current_price
                )
                if amount > 0:
                    self._execute_open(current_price, amount)

        elif signal.type == SignalType.SELL and pos is not None:
            self._execute_close(pos, current_price, "strategy_signal")

        self.portfolio.snapshot({self.symbol: current_price})

    def _execute_open(self, price: float, amount: float) -> None:
        sl = self.risk_mgr.stop_loss_price(price, Side.BUY)
        tp = self.risk_mgr.take_profit_price(price, Side.BUY)

        if self.config.trading.mode == "live":
            try:
                self.exchange.create_market_buy(self.symbol, amount)
            except Exception as e:
                logger.error("Order failed: %s", e)
                return

        self.portfolio.open_position(
            symbol=self.symbol,
            side=Side.BUY,
            price=price,
            amount=amount,
            stop_loss=sl,
            take_profit=tp,
        )
        console.print(
            f"[green]▲ BUY[/green]  {amount:.8f} {self.symbol} @ ${price:,.2f}"
        )

    def _execute_close(
        self, pos: Any, price: float, reason: str
    ) -> None:
        if self.config.trading.mode == "live":
            try:
                self.exchange.create_market_sell(self.symbol, pos.amount)
            except Exception as e:
                logger.error("Close order failed: %s", e)
                return

        trade = self.portfolio.close_position(
            pos, price, strategy=self.strategy.name
        )
        self.risk_mgr.record_pnl(trade.pnl)
        color = "green" if trade.pnl >= 0 else "red"
        console.print(
            f"[{color}]▼ SELL[/{color}] ({reason})  "
            f"P&L: ${trade.pnl:,.2f} ({trade.pnl_pct * 100:.2f}%)"
        )

    def _close_all(self) -> None:
        """Close all positions on shutdown."""
        for pos in list(self.portfolio.positions):
            try:
                ticker = self.exchange.fetch_ticker(self.symbol)
                price = ticker.get("last", pos.entry_price)
            except Exception:
                price = pos.entry_price
            self._execute_close(pos, price, "shutdown")

    def _print_summary(self) -> None:
        summary = self.portfolio.summary()
        table = Table(show_lines=True)
        table.add_column("Metric", style="cyan")
        table.add_column("Value", style="green")
        for k, v in summary.items():
            if k in ("equity_curve",):
                continue
            if isinstance(v, float):
                table.add_row(k, f"{v:,.4f}")
            else:
                table.add_row(k, str(v))
        console.print(table)
