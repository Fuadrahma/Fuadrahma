"""
Main Trading Bot — live/paper trading loop.
Loads config, fetches data, runs ensemble strategy, executes orders,
and manages positions every loop_interval_seconds.
"""

from __future__ import annotations

import time
import signal as _signal
import sys
from datetime import datetime
from typing import Dict, List

from trading_bot.config import BotConfig, load_config
from trading_bot.data.fetcher import MarketDataFetcher
from trading_bot.strategies.rsi_strategy import RSIStrategy
from trading_bot.strategies.macd_strategy import MACDStrategy
from trading_bot.strategies.bollinger_strategy import BollingerStrategy
from trading_bot.strategies.ema_crossover_strategy import EMACrossoverStrategy
from trading_bot.strategies.vwap_strategy import VWAPStrategy
from trading_bot.strategies.ensemble import EnsembleStrategy
from trading_bot.risk.manager import RiskManager
from trading_bot.execution.executor import TradingExecutor
from trading_bot.notifications.notifier import Notifier
from trading_bot.utils.logger import setup_logger, get_logger

logger = get_logger("bot")


def build_ensemble(config: BotConfig) -> EnsembleStrategy:
    strategy_map = {
        "rsi": RSIStrategy,
        "macd": MACDStrategy,
        "bollinger": BollingerStrategy,
        "ema_crossover": EMACrossoverStrategy,
        "vwap": VWAPStrategy,
    }
    active = config.strategy.active_strategies
    strategies = [strategy_map[name](config) for name in active if name in strategy_map]
    return EnsembleStrategy(
        strategies=strategies,
        method=config.strategy.ensemble_method,
        min_confidence=0.55,
    )


class TradingBot:
    def __init__(self, config: BotConfig):
        self.config = config
        self.running = False

        setup_logger("trading_bot", config.log_file, config.log_level)

        self.fetcher = MarketDataFetcher(config.exchange, config.data_dir)
        self.ensemble = build_ensemble(config)
        self.risk = RiskManager(config, initial_capital=config.backtest.initial_capital)
        self.executor = TradingExecutor(self.risk, config)
        self.notifier = Notifier(
            config.telegram_token, config.telegram_chat_id, config.notifications_enabled
        )

        _signal.signal(_signal.SIGINT, self._handle_shutdown)
        _signal.signal(_signal.SIGTERM, self._handle_shutdown)

        mode = "PAPER" if config.paper_trading else "LIVE"
        logger.info(f"TradingBot initialized | mode={mode} | symbols={config.symbols}")

    def _handle_shutdown(self, signum, frame):
        logger.info("Shutdown signal received. Stopping bot...")
        self.running = False

    def run(self):
        self.running = True
        logger.info("Bot started. Press Ctrl+C to stop.")
        self.notifier.send("Trading bot started.", "info")

        while self.running:
            try:
                self._loop()
            except Exception as e:
                logger.error(f"Loop error: {e}", exc_info=True)
                self.notifier.alert(f"Loop error: {e}")
            time.sleep(self.config.loop_interval_seconds)

        self._shutdown()

    def _loop(self):
        prices: Dict[str, float] = {}

        for symbol in self.config.symbols:
            try:
                df = self.fetcher.fetch_ohlcv(
                    symbol, self.config.timeframe, self.config.lookback_candles
                )
                current_price = float(df["close"].iloc[-1])
                prices[symbol] = current_price

                signal = self.ensemble.generate_signal(df, symbol)
                logger.info(f"{symbol} | {signal}")

                order = self.executor.execute_signal(signal)
                if order and order.status == "filled":
                    pos = self.risk.open_positions.get(symbol)
                    if pos:
                        self.notifier.trade_opened(
                            symbol, pos.side, order.avg_fill_price,
                            order.filled_qty, signal.strategy
                        )
            except Exception as e:
                logger.error(f"Error processing {symbol}: {e}", exc_info=True)

        # Update trailing stops and check exits
        self.executor.update_and_check_exits(prices)

        stats = self.risk.stats()
        logger.info(
            f"Portfolio | Capital={stats['capital']:.2f} | "
            f"Trades={stats['total_trades']} | WinRate={stats.get('win_rate', 0):.1%} | "
            f"Open={stats['open_positions']}"
        )

    def _shutdown(self):
        stats = self.risk.stats()
        self.notifier.daily_summary(stats)
        logger.info(f"Bot stopped. Final stats: {stats}")
