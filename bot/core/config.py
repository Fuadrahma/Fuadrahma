"""Configuration loader with YAML + environment variable support."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from dotenv import load_dotenv


@dataclass
class ExchangeConfig:
    name: str = "binance"
    sandbox: bool = True
    rate_limit: bool = True
    api_key: str = ""
    api_secret: str = ""


@dataclass
class RiskConfig:
    max_position_pct: float = 0.02
    stop_loss_pct: float = 0.03
    take_profit_pct: float = 0.06
    max_open_trades: int = 3
    trailing_stop: bool = False
    trailing_stop_pct: float = 0.02
    max_daily_loss_pct: float = 0.05


@dataclass
class TradingConfig:
    mode: str = "paper"
    symbol: str = "BTC/USDT"
    timeframe: str = "1h"
    strategy: str = "ema_crossover"
    base_currency: str = "USDT"
    initial_balance: float = 10000


@dataclass
class BacktestConfig:
    start_date: str = "2024-01-01"
    end_date: str = "2024-12-31"
    initial_balance: float = 10000
    commission_pct: float = 0.001


@dataclass
class BotConfig:
    exchange: ExchangeConfig = field(default_factory=ExchangeConfig)
    trading: TradingConfig = field(default_factory=TradingConfig)
    risk: RiskConfig = field(default_factory=RiskConfig)
    backtest: BacktestConfig = field(default_factory=BacktestConfig)
    strategies: dict[str, dict[str, Any]] = field(default_factory=dict)
    log_level: str = "INFO"
    log_file: str = "logs/trading.log"


def load_config(path: str | Path = "config.yaml") -> BotConfig:
    """Load configuration from YAML file and merge with env vars."""
    load_dotenv()

    config_path = Path(path)
    raw: dict[str, Any] = {}
    if config_path.exists():
        with open(config_path) as f:
            raw = yaml.safe_load(f) or {}

    exc_raw = raw.get("exchange", {})
    exchange = ExchangeConfig(
        name=exc_raw.get("name", "binance"),
        sandbox=exc_raw.get("sandbox", True),
        rate_limit=exc_raw.get("rate_limit", True),
        api_key=os.getenv("API_KEY", ""),
        api_secret=os.getenv("API_SECRET", ""),
    )

    t_raw = raw.get("trading", {})
    trading = TradingConfig(
        mode=t_raw.get("mode", "paper"),
        symbol=t_raw.get("symbol", "BTC/USDT"),
        timeframe=t_raw.get("timeframe", "1h"),
        strategy=t_raw.get("strategy", "ema_crossover"),
        base_currency=t_raw.get("base_currency", "USDT"),
        initial_balance=float(t_raw.get("initial_balance", 10000)),
    )

    r_raw = raw.get("risk", {})
    risk = RiskConfig(
        max_position_pct=float(r_raw.get("max_position_pct", 0.02)),
        stop_loss_pct=float(r_raw.get("stop_loss_pct", 0.03)),
        take_profit_pct=float(r_raw.get("take_profit_pct", 0.06)),
        max_open_trades=int(r_raw.get("max_open_trades", 3)),
        trailing_stop=bool(r_raw.get("trailing_stop", False)),
        trailing_stop_pct=float(r_raw.get("trailing_stop_pct", 0.02)),
        max_daily_loss_pct=float(r_raw.get("max_daily_loss_pct", 0.05)),
    )

    b_raw = raw.get("backtest", {})
    backtest = BacktestConfig(
        start_date=b_raw.get("start_date", "2024-01-01"),
        end_date=b_raw.get("end_date", "2024-12-31"),
        initial_balance=float(b_raw.get("initial_balance", 10000)),
        commission_pct=float(b_raw.get("commission_pct", 0.001)),
    )

    log_raw = raw.get("logging", {})

    return BotConfig(
        exchange=exchange,
        trading=trading,
        risk=risk,
        backtest=backtest,
        strategies=raw.get("strategies", {}),
        log_level=log_raw.get("level", "INFO"),
        log_file=log_raw.get("file", "logs/trading.log"),
    )
