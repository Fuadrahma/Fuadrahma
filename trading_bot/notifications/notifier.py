"""
Notification system — console log + optional Telegram alerts.
"""

from typing import Optional
from trading_bot.utils.logger import get_logger

logger = get_logger("notifications")


class Notifier:
    def __init__(self, telegram_token: str = "", chat_id: str = "",
                 enabled: bool = False):
        self.enabled = enabled and bool(telegram_token) and bool(chat_id)
        self.telegram_token = telegram_token
        self.chat_id = chat_id
        self._bot = None
        if self.enabled:
            self._init_telegram()

    def _init_telegram(self):
        try:
            import requests
            self._requests = requests
            logger.info("Telegram notifier initialized.")
        except ImportError:
            logger.warning("requests not available — Telegram notifications disabled.")
            self.enabled = False

    def send(self, message: str, level: str = "info"):
        logger.info(f"[NOTIFY] {message}")
        if self.enabled:
            self._send_telegram(f"[{level.upper()}] {message}")

    def _send_telegram(self, text: str):
        try:
            url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"
            self._requests.post(url, json={"chat_id": self.chat_id, "text": text}, timeout=5)
        except Exception as e:
            logger.warning(f"Telegram send failed: {e}")

    def trade_opened(self, symbol: str, side: str, price: float,
                     qty: float, strategy: str):
        msg = (f"Trade OPEN | {side.upper()} {symbol}\n"
               f"Price: {price:.4f} | Qty: {qty:.6f}\n"
               f"Strategy: {strategy}")
        self.send(msg, "trade")

    def trade_closed(self, symbol: str, pnl: float, pnl_pct: float, reason: str):
        emoji = "+" if pnl >= 0 else "-"
        msg = (f"Trade CLOSE | {symbol}\n"
               f"PnL: {emoji}{abs(pnl):.4f} ({pnl_pct:+.2%})\n"
               f"Reason: {reason}")
        self.send(msg, "trade")

    def alert(self, text: str):
        self.send(f"ALERT: {text}", "alert")

    def daily_summary(self, stats: dict):
        msg = (
            f"Daily Summary\n"
            f"Capital: {stats.get('capital', 0):.2f}\n"
            f"Total PnL: {stats.get('total_pnl', 0):+.4f}\n"
            f"Trades: {stats.get('total_trades', 0)}\n"
            f"Win Rate: {stats.get('win_rate', 0):.1%}\n"
            f"Profit Factor: {stats.get('profit_factor', 0):.2f}\n"
            f"Max Drawdown: {stats.get('max_drawdown', 0):.2%}"
        )
        self.send(msg, "summary")
