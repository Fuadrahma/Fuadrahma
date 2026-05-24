"""CLI entry point for the trading bot."""

from __future__ import annotations

import click
from rich.console import Console

from bot.core.backtester import Backtester
from bot.core.config import load_config
from bot.core.engine import TradingEngine
from bot.strategies.registry import get_strategy, list_strategies
from bot.utils.data import generate_sample_data
from bot.utils.logger import setup_logging

console = Console()


@click.group()
def cli() -> None:
    """Advanced Crypto Trading Bot"""


@cli.command()
@click.option("--config", "-c", default="config.yaml", help="Config file path")
def trade(config: str) -> None:
    """Start live / paper trading."""
    cfg = load_config(config)
    setup_logging(cfg.log_level, cfg.log_file)

    console.print("[bold]🤖 Advanced Trading Bot v1.0[/bold]\n")
    engine = TradingEngine(cfg)
    engine.run()


@cli.command()
@click.option("--config", "-c", default="config.yaml", help="Config file path")
@click.option("--strategy", "-s", default=None, help="Override strategy name")
@click.option("--days", "-d", default=365, help="Days of sample data")
@click.option("--seed", default=42, help="Random seed for reproducibility")
def backtest(config: str, strategy: str | None, days: int, seed: int) -> None:
    """Run a backtest with historical or sample data."""
    cfg = load_config(config)
    setup_logging(cfg.log_level, cfg.log_file)

    strat_name = strategy or cfg.trading.strategy
    strat_params = cfg.strategies.get(strat_name, {})
    strat = get_strategy(strat_name, strat_params)

    console.print(f"[bold]📊 Backtesting: {strat_name}[/bold]")
    console.print(f"Generating {days} days of sample data (seed={seed})...\n")

    df = generate_sample_data(days=days, seed=seed)

    bt = Backtester(
        strategy=strat,
        risk_config=cfg.risk,
        backtest_config=cfg.backtest,
        symbol=cfg.trading.symbol,
    )
    results = bt.run(df)
    Backtester.print_report(results)


@cli.command(name="backtest-all")
@click.option("--config", "-c", default="config.yaml", help="Config file path")
@click.option("--days", "-d", default=365, help="Days of sample data")
@click.option("--seed", default=42, help="Random seed")
def backtest_all(config: str, days: int, seed: int) -> None:
    """Backtest ALL strategies and compare results."""
    cfg = load_config(config)
    setup_logging(cfg.log_level, cfg.log_file)

    df = generate_sample_data(days=days, seed=seed)
    console.print(
        f"[bold]📊 Comparing all strategies ({days} days, seed={seed})[/bold]\n"
    )

    from rich.table import Table

    table = Table(title="Strategy Comparison", show_lines=True)
    table.add_column("Strategy", style="cyan")
    table.add_column("Trades", justify="right")
    table.add_column("Win Rate", justify="right")
    table.add_column("P&L ($)", justify="right")
    table.add_column("Return %", justify="right")
    table.add_column("Max DD %", justify="right")
    table.add_column("Profit Factor", justify="right")

    for name in list_strategies():
        params = cfg.strategies.get(name, {})
        strat = get_strategy(name, params)
        bt = Backtester(
            strategy=strat,
            risk_config=cfg.risk,
            backtest_config=cfg.backtest,
            symbol=cfg.trading.symbol,
        )
        try:
            res = bt.run(df)
            pnl_color = "green" if res.get("total_pnl", 0) >= 0 else "red"
            table.add_row(
                name,
                str(res.get("total_trades", 0)),
                f"{res.get('win_rate', 0) * 100:.1f}%",
                f"[{pnl_color}]{res.get('total_pnl', 0):,.2f}[/{pnl_color}]",
                f"{res.get('return_pct', 0):.2f}%",
                f"{res.get('max_drawdown_pct', 0):.2f}%",
                f"{res.get('profit_factor', 0):.2f}",
            )
        except Exception as e:
            table.add_row(name, "-", "-", "-", "-", "-", f"Error: {e}")

    console.print(table)


@cli.command(name="list")
def list_cmd() -> None:
    """List all available strategies."""
    console.print("[bold]Available Strategies:[/bold]\n")
    for name in list_strategies():
        console.print(f"  • {name}")


if __name__ == "__main__":
    cli()
