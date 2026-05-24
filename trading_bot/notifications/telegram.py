"""Telegram bot notification system."""
import logging
from typing import Optional

logger = logging.getLogger(__name__)

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


class TelegramNotifier:
    """Send trade signals and alerts to a Telegram chat."""

    BASE_URL = "https://api.telegram.org/bot{token}/sendMessage"

    def __init__(self, config=None):
        from trading_bot.config import config as default_config
        cfg = (config or default_config).notifications
        self.token = cfg.telegram_token
        self.chat_id = cfg.telegram_chat_id
        self.enabled = cfg.enable_telegram and bool(self.token) and bool(self.chat_id)
        if not self.enabled:
            logger.info("Telegram notifications disabled (missing token/chat_id)")

    def send(self, message: str, parse_mode: str = "HTML") -> bool:
        if not self.enabled or not REQUESTS_AVAILABLE:
            logger.debug("Telegram [SKIPPED]: %s", message[:80])
            return False
        try:
            url = self.BASE_URL.format(token=self.token)
            resp = requests.post(url, json={
                "chat_id": self.chat_id,
                "text": message,
                "parse_mode": parse_mode,
            }, timeout=10)
            resp.raise_for_status()
            return True
        except Exception as exc:
            logger.error("Telegram send error: %s", exc)
            return False

    def notify_signal(self, signal) -> bool:
        emoji = {"BUY": "🟢", "STRONG_BUY": "💚", "SELL": "🔴",
                 "STRONG_SELL": "❤️", "HOLD": "⚪"}.get(signal.signal_type.value, "⚪")
        msg = (
            f"{emoji} <b>{signal.signal_type.value}</b>\n"
            f"Symbol: <code>{signal.symbol}</code>\n"
            f"Price: <code>${signal.price:,.4f}</code>\n"
            f"Confidence: <code>{signal.confidence:.1%}</code>\n"
            f"Strategy: <code>{signal.strategy_name}</code>\n"
        )
        if signal.stop_loss:
            msg += f"Stop Loss: <code>${signal.stop_loss:,.4f}</code>\n"
        if signal.take_profit:
            msg += f"Take Profit: <code>${signal.take_profit:,.4f}</code>\n"
        return self.send(msg)

    def notify_trade_opened(self, symbol: str, side: str, price: float,
                             qty: float, sl: float, tp: float) -> bool:
        emoji = "🟢" if side == "long" else "🔴"
        msg = (
            f"{emoji} <b>TRADE OPENED</b>\n"
            f"Symbol: <code>{symbol}</code>\n"
            f"Side: <code>{side.upper()}</code>\n"
            f"Entry: <code>${price:,.4f}</code>\n"
            f"Quantity: <code>{qty:.6f}</code>\n"
            f"Stop Loss: <code>${sl:,.4f}</code>\n"
            f"Take Profit: <code>${tp:,.4f}</code>\n"
        )
        return self.send(msg)

    def notify_trade_closed(self, symbol: str, pnl: float, reason: str) -> bool:
        emoji = "✅" if pnl >= 0 else "❌"
        msg = (
            f"{emoji} <b>TRADE CLOSED</b>\n"
            f"Symbol: <code>{symbol}</code>\n"
            f"PnL: <code>${pnl:+,.4f}</code>\n"
            f"Reason: <code>{reason}</code>\n"
        )
        return self.send(msg)

    def notify_error(self, error: str) -> bool:
        return self.send(f"⚠️ <b>ERROR</b>\n<code>{error}</code>")

    def notify_portfolio_summary(self, portfolio) -> bool:
        msg = (
            f"📊 <b>Portfolio Summary</b>\n"
            f"Balance: <code>${portfolio.balance:,.2f}</code>\n"
            f"Equity: <code>${portfolio.equity:,.2f}</code>\n"
            f"Total Return: <code>{portfolio.total_return_pct:+.2f}%</code>\n"
            f"Open Positions: <code>{len(portfolio.open_positions)}</code>\n"
            f"Drawdown: <code>{portfolio.drawdown:.2%}</code>\n"
            f"Win Rate: <code>{portfolio.win_rate:.1%}</code>\n"
            f"Total Trades: <code>{portfolio.total_trades}</code>\n"
        )
        return self.send(msg)
