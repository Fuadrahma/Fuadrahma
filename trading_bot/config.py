"""
Central configuration for the trading bot.
All parameters can be overridden via config.yaml or environment variables.
"""

import os
import yaml
from dataclasses import dataclass, field
from typing import List, Dict, Optional


@dataclass
class ExchangeConfig:
    name: str = "binance"
    api_key: str = ""
    api_secret: str = ""
    testnet: bool = True
    base_url: str = ""


@dataclass
class RiskConfig:
    max_position_size_pct: float = 0.05       # max 5% of portfolio per trade
    max_drawdown_pct: float = 0.15            # halt trading if drawdown > 15%
    stop_loss_pct: float = 0.02               # 2% stop-loss per trade
    take_profit_pct: float = 0.04             # 4% take-profit per trade
    trailing_stop_pct: float = 0.015          # 1.5% trailing stop
    max_open_positions: int = 5               # max concurrent open trades
    risk_per_trade_pct: float = 0.01          # risk 1% of capital per trade
    max_daily_loss_pct: float = 0.05          # halt after 5% daily loss
    use_kelly_criterion: bool = True          # size positions with Kelly


@dataclass
class StrategyConfig:
    active_strategies: List[str] = field(default_factory=lambda: [
        "rsi", "macd", "bollinger", "ema_crossover", "vwap"
    ])
    ensemble_method: str = "weighted_vote"    # weighted_vote | majority | unanimous
    rsi_period: int = 14
    rsi_oversold: float = 30.0
    rsi_overbought: float = 70.0
    macd_fast: int = 12
    macd_slow: int = 26
    macd_signal: int = 9
    bb_period: int = 20
    bb_std: float = 2.0
    ema_fast: int = 9
    ema_slow: int = 21
    vwap_period: int = 14
    atr_period: int = 14
    adx_period: int = 14
    adx_threshold: float = 25.0              # only trade when trend strength > 25


@dataclass
class BacktestConfig:
    initial_capital: float = 10_000.0
    commission_pct: float = 0.001            # 0.1% per trade
    slippage_pct: float = 0.0005             # 0.05% slippage
    start_date: str = "2023-01-01"
    end_date: str = "2024-12-31"


@dataclass
class BotConfig:
    symbols: List[str] = field(default_factory=lambda: [
        "BTC/USDT", "ETH/USDT", "BNB/USDT", "SOL/USDT", "XRP/USDT"
    ])
    timeframe: str = "1h"
    lookback_candles: int = 500
    paper_trading: bool = True
    log_level: str = "INFO"
    log_file: str = "logs/trading_bot.log"
    data_dir: str = "data/market"
    results_dir: str = "results"
    loop_interval_seconds: int = 60
    exchange: ExchangeConfig = field(default_factory=ExchangeConfig)
    risk: RiskConfig = field(default_factory=RiskConfig)
    strategy: StrategyConfig = field(default_factory=StrategyConfig)
    backtest: BacktestConfig = field(default_factory=BacktestConfig)
    telegram_token: str = ""
    telegram_chat_id: str = ""
    notifications_enabled: bool = False


def load_config(path: str = "config.yaml") -> BotConfig:
    """Load configuration, merging YAML file with environment variable overrides."""
    cfg = BotConfig()

    if os.path.exists(path):
        with open(path) as f:
            data = yaml.safe_load(f) or {}
        _apply_dict(cfg, data)

    # Environment variable overrides
    cfg.exchange.api_key = os.getenv("EXCHANGE_API_KEY", cfg.exchange.api_key)
    cfg.exchange.api_secret = os.getenv("EXCHANGE_API_SECRET", cfg.exchange.api_secret)
    cfg.telegram_token = os.getenv("TELEGRAM_TOKEN", cfg.telegram_token)
    cfg.telegram_chat_id = os.getenv("TELEGRAM_CHAT_ID", cfg.telegram_chat_id)
    if os.getenv("PAPER_TRADING", "").lower() in ("0", "false"):
        cfg.paper_trading = False

    return cfg


def _apply_dict(obj, data: dict):
    for key, val in data.items():
        if hasattr(obj, key):
            attr = getattr(obj, key)
            if hasattr(attr, "__dataclass_fields__") and isinstance(val, dict):
                _apply_dict(attr, val)
            else:
                setattr(obj, key, val)
