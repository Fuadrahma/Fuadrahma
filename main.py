#!/usr/bin/env python3
"""
Entry point for the Ultimate Trading Bot.

Usage:
  python main.py bot          # Run trading bot
  python main.py dashboard    # Launch web dashboard
  python main.py backtest     # Run backtests on all symbols
  python main.py signal BTC/USDT  # Get signal for a symbol
"""
import argparse
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("main")


def cmd_bot(args):
    from trading_bot.bot import TradingBot
    bot = TradingBot()
    bot.run()


def cmd_dashboard(args):
    from trading_bot.dashboard import create_app
    from trading_bot.bot import TradingBot
    import uvicorn

    bot = TradingBot()
    app = create_app(bot)
    logger.info("Dashboard running at http://localhost:8080")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")


def cmd_dashboard_only(args):
    """Dashboard without live bot (safe for demos)."""
    from trading_bot.dashboard import create_app
    import uvicorn

    app = create_app(bot=None)
    logger.info("Dashboard (demo) running at http://localhost:8080")
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")


def cmd_backtest(args):
    from trading_bot.exchange import ExchangeConnector
    from trading_bot.strategies import STRATEGIES
    from trading_bot.backtesting import Backtester

    symbols = args.symbols or ["BTC/USDT", "ETH/USDT", "SOL/USDT"]
    strategy_names = args.strategies or ["hybrid"]

    exchange = ExchangeConnector()

    for sym in symbols:
        df = exchange.fetch_ohlcv(sym, limit=500)
        for strat_name in strategy_names:
            strat_class = STRATEGIES.get(strat_name)
            if not strat_class:
                logger.warning("Unknown strategy: %s", strat_name)
                continue
            backtester = Backtester(strat_class())
            result = backtester.run(df, sym)
            print(result)


def cmd_signal(args):
    from trading_bot.exchange import ExchangeConnector
    from trading_bot.strategies import STRATEGIES, HybridStrategy

    exchange = ExchangeConnector()
    symbol = args.symbol or "BTC/USDT"
    df = exchange.fetch_ohlcv(symbol, limit=300)

    for name, strat_class in STRATEGIES.items():
        sig = strat_class().generate_signal(df, symbol)
        print(f"[{name:15s}] {sig.signal_type.value:12s} conf={sig.confidence:.2f}  price={sig.price:.4f}")


def main():
    parser = argparse.ArgumentParser(description="Ultimate Crypto Trading Bot")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("bot", help="Start the live trading bot")

    p_dash = sub.add_parser("dashboard", help="Launch web dashboard with bot")
    p_demo = sub.add_parser("demo", help="Launch dashboard in demo mode (no live bot)")

    p_bt = sub.add_parser("backtest", help="Run backtests")
    p_bt.add_argument("--symbols", nargs="+", default=None)
    p_bt.add_argument("--strategies", nargs="+", default=None)

    p_sig = sub.add_parser("signal", help="Get signal for a symbol")
    p_sig.add_argument("symbol", nargs="?", default="BTC/USDT")

    args = parser.parse_args()

    if args.command == "bot":
        cmd_bot(args)
    elif args.command == "dashboard":
        cmd_dashboard(args)
    elif args.command == "demo":
        cmd_dashboard_only(args)
    elif args.command == "backtest":
        cmd_backtest(args)
    elif args.command == "signal":
        cmd_signal(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
