"""
Entry point for the trading bot.
Supports three modes: live/paper trading, backtest, and analysis.
"""

import argparse
import os
import sys
import json
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Powerful Multi-Strategy Algorithmic Trading Bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python -m trading_bot.main backtest --symbol BTC/USDT --bars 1000
  python -m trading_bot.main trade --paper
  python -m trading_bot.main backtest --all-symbols
        """,
    )
    parser.add_argument("mode", choices=["trade", "backtest", "status"],
                        help="Operating mode")
    parser.add_argument("--config", default="config.yaml", help="Path to config file")
    parser.add_argument("--symbol", default=None, help="Symbol to trade/backtest (e.g. BTC/USDT)")
    parser.add_argument("--all-symbols", action="store_true",
                        help="Backtest all configured symbols")
    parser.add_argument("--bars", type=int, default=500,
                        help="Number of historical bars to use for backtesting")
    parser.add_argument("--timeframe", default=None,
                        help="Candle timeframe (e.g. 1h, 4h, 1d)")
    parser.add_argument("--paper", action="store_true",
                        help="Force paper trading mode")
    parser.add_argument("--output", default=None,
                        help="Output file for backtest results (JSON)")
    return parser.parse_args()


def main():
    args = parse_args()

    from trading_bot.config import load_config
    from trading_bot.utils.logger import setup_logger

    config = load_config(args.config)

    if args.timeframe:
        config.timeframe = args.timeframe
    if args.paper:
        config.paper_trading = True

    os.makedirs("logs", exist_ok=True)
    os.makedirs("results", exist_ok=True)
    setup_logger("trading_bot", config.log_file, config.log_level)

    if args.mode == "trade":
        from trading_bot.bot import TradingBot
        bot = TradingBot(config)
        bot.run()

    elif args.mode == "backtest":
        _run_backtest(config, args)

    elif args.mode == "status":
        _show_status(config)


def _run_backtest(config, args):
    from trading_bot.data.fetcher import MarketDataFetcher
    from trading_bot.bot import build_ensemble
    from trading_bot.backtesting.engine import BacktestEngine

    fetcher = MarketDataFetcher(config.exchange, config.data_dir)
    ensemble = build_ensemble(config)
    engine = BacktestEngine(ensemble, config)

    symbols = config.symbols if args.all_symbols else [args.symbol or config.symbols[0]]
    all_results = []

    for symbol in symbols:
        print(f"\nBacktesting {symbol}...")
        df = fetcher.fetch_ohlcv(symbol, config.timeframe, args.bars)
        result = engine.run(df, symbol)
        print(result.summary())
        all_results.append({
            "symbol": result.symbol,
            "initial_capital": result.initial_capital,
            "final_capital": result.final_capital,
            "total_return_pct": result.total_return_pct,
            "total_trades": result.total_trades,
            "win_rate": result.win_rate,
            "profit_factor": result.profit_factor,
            "sharpe_ratio": result.sharpe_ratio,
            "sortino_ratio": result.sortino_ratio,
            "calmar_ratio": result.calmar_ratio,
            "max_drawdown": result.max_drawdown,
        })

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w") as f:
            json.dump(all_results, f, indent=2)
        print(f"\nResults saved to {args.output}")

    if len(all_results) > 1:
        print("\n" + "=" * 55)
        print(" MULTI-SYMBOL SUMMARY")
        print("=" * 55)
        avg_return = sum(r["total_return_pct"] for r in all_results) / len(all_results)
        avg_sharpe = sum(r["sharpe_ratio"] for r in all_results) / len(all_results)
        print(f" Avg Return:  {avg_return:+.2%}")
        print(f" Avg Sharpe:  {avg_sharpe:.3f}")
        best = max(all_results, key=lambda r: r["total_return_pct"])
        print(f" Best Symbol: {best['symbol']} ({best['total_return_pct']:+.2%})")
        print("=" * 55)


def _show_status(config):
    from trading_bot.risk.manager import RiskManager
    from trading_bot.dashboard import Dashboard
    risk = RiskManager(config)
    dash = Dashboard(risk)
    dash.render_once()


if __name__ == "__main__":
    main()
