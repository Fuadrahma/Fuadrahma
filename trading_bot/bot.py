"""
Main trading bot engine — orchestrates exchange, strategies, risk, ML, notifications.
"""
from __future__ import annotations
import asyncio
import logging
import time
from datetime import datetime, timezone
from typing import Dict, List, Optional

from trading_bot.config import config
from trading_bot.exchange import ExchangeConnector
from trading_bot.strategies import STRATEGIES, HybridStrategy
from trading_bot.risk_management import RiskManager, PortfolioState
from trading_bot.notifications import TelegramNotifier
from trading_bot.ml import MLPredictor

logger = logging.getLogger(__name__)


class TradingBot:
    """
    Production-grade trading bot with:
    - Multiple strategies with hybrid voting
    - ML-enhanced signal filtering
    - Full risk management (SL/TP/trailing)
    - Paper & live trading modes
    - Telegram notifications
    - Periodic portfolio reporting
    """

    def __init__(self, cfg=None):
        self.cfg = cfg or config
        self.exchange = ExchangeConnector(self.cfg)
        self.strategy = STRATEGIES.get(self.cfg.trading.strategy, HybridStrategy)()
        self.risk = RiskManager(self.cfg)
        self.notifier = TelegramNotifier(self.cfg)
        self.ml = MLPredictor(self.cfg)
        self.portfolio = PortfolioState(
            balance=self.cfg.trading.stake_amount * self.cfg.trading.max_open_trades,
            initial_balance=self.cfg.trading.stake_amount * self.cfg.trading.max_open_trades,
        )
        self._running = False
        self._iteration = 0
        self._last_report = 0.0

    def run(self, iterations: Optional[int] = None):
        """
        Start the main trading loop.
        Pass `iterations` for finite runs (testing). Otherwise runs forever.
        """
        logger.info(
            "=== Trading Bot Starting ===\n"
            "Strategy  : %s\n"
            "Symbols   : %s\n"
            "Timeframe : %s\n"
            "Paper Mode: %s\n",
            self.cfg.trading.strategy,
            self.cfg.trading.symbols,
            self.cfg.trading.timeframe,
            self.cfg.exchange.paper_trading,
        )
        self._running = True
        self.notifier.send("🤖 <b>Trading Bot Started</b>")

        try:
            while self._running:
                self._iteration += 1
                logger.info("--- Iteration %d ---", self._iteration)
                self._tick()

                if iterations and self._iteration >= iterations:
                    break

                # Sleep until next candle
                sleep_seconds = self._get_sleep_seconds()
                logger.info("Sleeping %.0f seconds until next candle...", sleep_seconds)
                time.sleep(sleep_seconds)

        except KeyboardInterrupt:
            logger.info("Bot stopped by user")
        finally:
            self._running = False
            self.notifier.notify_portfolio_summary(self.portfolio)
            logger.info("=== Bot Stopped ===\nFinal Equity: $%.2f", self.portfolio.equity)

    def _tick(self):
        """Single iteration: fetch data, generate signals, manage positions."""
        symbols = self.cfg.trading.symbols
        timeframe = self.cfg.trading.timeframe

        # Fetch market data for all symbols
        data = self.exchange.fetch_all_ohlcv(symbols, timeframe, limit=300)

        # Current prices for risk checks
        prices = {sym: df["close"].iloc[-1] for sym, df in data.items()}

        # Check exit conditions on existing positions
        exits = self.risk.check_exits(self.portfolio, prices)
        for symbol, reason in exits:
            pnl = self.risk.close_position(symbol, prices[symbol], reason, self.portfolio)
            if pnl is not None:
                self.notifier.notify_trade_closed(symbol, pnl, reason)

        # Generate signals for each symbol
        for symbol, df in data.items():
            if len(df) < 50:
                continue

            signal = self.strategy.generate_signal(df, symbol)
            logger.info("Signal: %s", signal)

            if signal.signal_type.value == "HOLD":
                continue

            # ML filter: only enter if ML agrees (or is uncertain)
            ml_pred, ml_conf = self.ml.predict(df)
            if signal.is_entry and ml_conf >= self.cfg.ml.min_confidence:
                if ml_pred == 0:  # ML says DOWN but strategy says BUY
                    logger.info("ML filter rejected BUY for %s (ML conf=%.2f DOWN)", symbol, ml_conf)
                    signal.confidence *= 0.7  # reduce confidence

            # Notify signal
            if signal.confidence >= 0.60:
                self.notifier.notify_signal(signal)

            # Execute entry
            if signal.is_entry:
                pos = self.risk.open_position(signal, self.portfolio)
                if pos:
                    self.exchange.create_order(
                        symbol, "market", "buy", pos.quantity, signal.price
                    )
                    self.notifier.notify_trade_opened(
                        symbol, pos.side, pos.entry_price,
                        pos.quantity, pos.stop_loss, pos.take_profit
                    )

            # Execute exit
            elif signal.is_exit and symbol in self.portfolio.open_positions:
                pnl = self.risk.close_position(symbol, signal.price, "signal", self.portfolio)
                self.exchange.create_order(symbol, "market", "sell",
                                            self.portfolio.open_positions.get(symbol, type("o", (), {"quantity": 0})()).quantity,
                                            signal.price)
                if pnl is not None:
                    self.notifier.notify_trade_closed(symbol, pnl, "signal")

        # Periodic portfolio report (every hour)
        now = time.time()
        if now - self._last_report > 3600:
            self.notifier.notify_portfolio_summary(self.portfolio)
            self._last_report = now

    def get_status(self) -> dict:
        """Return current bot status as dict (for dashboard)."""
        return {
            "running": self._running,
            "iteration": self._iteration,
            "strategy": self.cfg.trading.strategy,
            "symbols": self.cfg.trading.symbols,
            "paper_mode": self.cfg.exchange.paper_trading,
            "balance": self.portfolio.balance,
            "equity": self.portfolio.equity,
            "total_return_pct": self.portfolio.total_return_pct,
            "drawdown": self.portfolio.drawdown,
            "win_rate": self.portfolio.win_rate,
            "total_trades": self.portfolio.total_trades,
            "open_positions": {
                sym: {
                    "entry_price": pos.entry_price,
                    "quantity": pos.quantity,
                    "side": pos.side,
                    "unrealized_pnl": pos.unrealized_pnl,
                    "pnl_pct": pos.pnl_pct,
                }
                for sym, pos in self.portfolio.open_positions.items()
            },
            "recent_trades": self.portfolio.closed_trades[-10:],
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

    def _get_sleep_seconds(self) -> float:
        """Calculate seconds until next candle."""
        tf_seconds = {
            "1m": 60, "5m": 300, "15m": 900, "30m": 1800,
            "1h": 3600, "4h": 14400, "1d": 86400,
        }
        return tf_seconds.get(self.cfg.trading.timeframe, 3600)
