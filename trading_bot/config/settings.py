"""
Central configuration for the trading bot.
All settings can be overridden via environment variables or config file.
"""
import os
from dataclasses import dataclass, field
from typing import List, Dict, Optional


@dataclass
class ExchangeConfig:
    name: str = os.getenv("EXCHANGE", "binance")
    api_key: str = os.getenv("API_KEY", "")
    api_secret: str = os.getenv("API_SECRET", "")
    testnet: bool = os.getenv("TESTNET", "true").lower() == "true"
    paper_trading: bool = os.getenv("PAPER_TRADING", "true").lower() == "true"


@dataclass
class TradingConfig:
    symbols: List[str] = field(default_factory=lambda: [
        "BTC/USDT", "ETH/USDT", "BNB/USDT", "SOL/USDT", "XRP/USDT"
    ])
    timeframe: str = os.getenv("TIMEFRAME", "1h")
    strategy: str = os.getenv("STRATEGY", "hybrid")
    max_open_trades: int = int(os.getenv("MAX_OPEN_TRADES", "5"))
    stake_amount: float = float(os.getenv("STAKE_AMOUNT", "100"))
    stake_currency: str = os.getenv("STAKE_CURRENCY", "USDT")


@dataclass
class RiskConfig:
    max_risk_per_trade: float = float(os.getenv("MAX_RISK_PER_TRADE", "0.02"))   # 2%
    stop_loss_pct: float = float(os.getenv("STOP_LOSS_PCT", "0.03"))              # 3%
    take_profit_pct: float = float(os.getenv("TAKE_PROFIT_PCT", "0.06"))          # 6%
    trailing_stop: bool = os.getenv("TRAILING_STOP", "true").lower() == "true"
    trailing_stop_pct: float = float(os.getenv("TRAILING_STOP_PCT", "0.02"))      # 2%
    max_drawdown_pct: float = float(os.getenv("MAX_DRAWDOWN_PCT", "0.15"))        # 15%
    risk_reward_min: float = float(os.getenv("RISK_REWARD_MIN", "1.5"))


@dataclass
class NotificationConfig:
    telegram_token: str = os.getenv("TELEGRAM_TOKEN", "")
    telegram_chat_id: str = os.getenv("TELEGRAM_CHAT_ID", "")
    enable_telegram: bool = os.getenv("ENABLE_TELEGRAM", "false").lower() == "true"
    notify_on_trade: bool = True
    notify_on_signal: bool = True
    notify_on_error: bool = True


@dataclass
class MLConfig:
    model_type: str = os.getenv("ML_MODEL", "ensemble")
    lookback_periods: int = int(os.getenv("ML_LOOKBACK", "60"))
    prediction_horizon: int = int(os.getenv("ML_HORIZON", "5"))
    retrain_interval_hours: int = int(os.getenv("ML_RETRAIN_HOURS", "24"))
    min_confidence: float = float(os.getenv("ML_MIN_CONFIDENCE", "0.65"))
    features: List[str] = field(default_factory=lambda: [
        "rsi", "macd", "macd_signal", "bb_upper", "bb_lower", "bb_mid",
        "ema_9", "ema_21", "ema_55", "volume_ratio", "atr", "obv_normalized",
        "price_change_1h", "price_change_4h", "price_change_24h"
    ])


@dataclass
class DashboardConfig:
    host: str = os.getenv("DASHBOARD_HOST", "0.0.0.0")
    port: int = int(os.getenv("DASHBOARD_PORT", "8080"))
    secret_key: str = os.getenv("DASHBOARD_SECRET", "change-me-in-production")
    debug: bool = os.getenv("DASHBOARD_DEBUG", "false").lower() == "true"


@dataclass
class BotConfig:
    exchange: ExchangeConfig = field(default_factory=ExchangeConfig)
    trading: TradingConfig = field(default_factory=TradingConfig)
    risk: RiskConfig = field(default_factory=RiskConfig)
    notifications: NotificationConfig = field(default_factory=NotificationConfig)
    ml: MLConfig = field(default_factory=MLConfig)
    dashboard: DashboardConfig = field(default_factory=DashboardConfig)
    db_path: str = os.getenv("DB_PATH", "trading_bot/data/bot.db")
    log_level: str = os.getenv("LOG_LEVEL", "INFO")


# Singleton config instance
config = BotConfig()
