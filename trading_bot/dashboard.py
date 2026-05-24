"""
CLI Dashboard — real-time terminal display of bot status.
Uses rich library for beautiful tables and live updates.
"""

from __future__ import annotations

import os
import sys
import time
from datetime import datetime
from typing import Optional

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.layout import Layout
    from rich.live import Live
    from rich.text import Text
    from rich import box
    HAS_RICH = True
except ImportError:
    HAS_RICH = False

from trading_bot.risk.manager import RiskManager
from trading_bot.utils.logger import get_logger

logger = get_logger("dashboard")


class Dashboard:
    def __init__(self, risk_manager: RiskManager):
        self.risk = risk_manager
        self.console = Console() if HAS_RICH else None
        self.start_time = datetime.utcnow()

    def render_once(self):
        """Print a single snapshot of the dashboard."""
        if HAS_RICH:
            self._render_rich()
        else:
            self._render_plain()

    def _render_rich(self):
        stats = self.risk.stats()
        console = self.console

        console.rule("[bold cyan]Trading Bot Dashboard[/bold cyan]")

        # Portfolio summary
        capital = stats.get("capital", 0)
        pnl = stats.get("total_pnl", 0)
        win_rate = stats.get("win_rate", 0)
        pf = stats.get("profit_factor", 0)
        drawdown = stats.get("max_drawdown", 0)
        sharpe = stats.get("sharpe_ratio", 0)

        pnl_color = "green" if pnl >= 0 else "red"
        summary_table = Table(box=box.ROUNDED, show_header=False, padding=(0, 2))
        summary_table.add_column("Key", style="bold yellow")
        summary_table.add_column("Value", style="bold white")
        summary_table.add_row("Capital", f"${capital:,.2f}")
        summary_table.add_row("Total PnL", f"[{pnl_color}]{pnl:+,.4f}[/{pnl_color}]")
        summary_table.add_row("Win Rate", f"{win_rate:.1%}")
        summary_table.add_row("Profit Factor", f"{pf:.2f}")
        summary_table.add_row("Sharpe Ratio", f"{sharpe:.3f}")
        summary_table.add_row("Max Drawdown", f"{drawdown:.2%}")
        summary_table.add_row("Total Trades", str(stats.get("total_trades", 0)))
        summary_table.add_row("Open Positions", str(stats.get("open_positions", 0)))
        console.print(Panel(summary_table, title="Portfolio Summary", border_style="cyan"))

        # Open positions
        if self.risk.open_positions:
            pos_table = Table(box=box.SIMPLE_HEAD, padding=(0, 1))
            pos_table.add_column("Symbol", style="bold")
            pos_table.add_column("Side", style="cyan")
            pos_table.add_column("Entry", justify="right")
            pos_table.add_column("Stop Loss", justify="right")
            pos_table.add_column("Take Profit", justify="right")
            pos_table.add_column("Qty", justify="right")

            for sym, pos in self.risk.open_positions.items():
                side_color = "green" if pos.side == "long" else "red"
                pos_table.add_row(
                    sym,
                    f"[{side_color}]{pos.side.upper()}[/{side_color}]",
                    f"{pos.entry_price:.4f}",
                    f"{pos.stop_loss:.4f}",
                    f"{pos.take_profit:.4f}",
                    f"{pos.quantity:.6f}",
                )
            console.print(Panel(pos_table, title="Open Positions", border_style="green"))
        else:
            console.print(Panel("[dim]No open positions[/dim]", title="Open Positions",
                                border_style="green"))

        # Recent trades
        recent = self.risk.trade_history[-10:]
        if recent:
            trade_table = Table(box=box.SIMPLE_HEAD, padding=(0, 1))
            trade_table.add_column("Symbol", style="bold")
            trade_table.add_column("Side")
            trade_table.add_column("Entry", justify="right")
            trade_table.add_column("Exit", justify="right")
            trade_table.add_column("PnL", justify="right")
            trade_table.add_column("Reason")

            for t in reversed(recent):
                pnl = t.get("pnl", 0)
                pnl_str = f"[green]{pnl:+.4f}[/green]" if pnl >= 0 else f"[red]{pnl:+.4f}[/red]"
                trade_table.add_row(
                    t.get("symbol", ""),
                    t.get("side", ""),
                    f"{t.get('entry_price', 0):.4f}",
                    f"{t.get('exit_price', 0):.4f}",
                    pnl_str,
                    t.get("reason", "")[:30],
                )
            console.print(Panel(trade_table, title="Recent Trades (last 10)", border_style="yellow"))

        uptime = str(datetime.utcnow() - self.start_time).split(".")[0]
        console.print(f"[dim]Uptime: {uptime} | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}[/dim]")

    def _render_plain(self):
        stats = self.risk.stats()
        print("=" * 55)
        print(" TRADING BOT DASHBOARD")
        print("=" * 55)
        print(f" Capital:       ${stats.get('capital', 0):,.2f}")
        print(f" Total PnL:     {stats.get('total_pnl', 0):+.4f}")
        print(f" Win Rate:      {stats.get('win_rate', 0):.1%}")
        print(f" Profit Factor: {stats.get('profit_factor', 0):.2f}")
        print(f" Open Positions:{stats.get('open_positions', 0)}")
        print(f" Total Trades:  {stats.get('total_trades', 0)}")
        print("=" * 55)
        for sym, pos in self.risk.open_positions.items():
            print(f"  {sym} | {pos.side.upper()} | entry={pos.entry_price:.4f}"
                  f" | SL={pos.stop_loss:.4f} | TP={pos.take_profit:.4f}")
