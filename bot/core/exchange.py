"""Exchange connector using ccxt for multi-exchange support."""

from __future__ import annotations

import logging
from typing import Any

import ccxt
import pandas as pd

from bot.core.config import ExchangeConfig

logger = logging.getLogger(__name__)


class ExchangeConnector:
    """Manages connection to a crypto exchange via ccxt."""

    def __init__(self, config: ExchangeConfig) -> None:
        exchange_class = getattr(ccxt, config.name, None)
        if exchange_class is None:
            raise ValueError(f"Unsupported exchange: {config.name}")

        params: dict[str, Any] = {
            "enableRateLimit": config.rate_limit,
        }
        if config.api_key:
            params["apiKey"] = config.api_key
        if config.api_secret:
            params["secret"] = config.api_secret

        self.exchange: ccxt.Exchange = exchange_class(params)

        if config.sandbox:
            self.exchange.set_sandbox_mode(True)
            logger.info("Exchange running in SANDBOX mode")

        self._name = config.name
        logger.info("Connected to %s", self._name)

    @property
    def name(self) -> str:
        return self._name

    def fetch_ohlcv(
        self,
        symbol: str,
        timeframe: str = "1h",
        limit: int = 500,
        since: int | None = None,
    ) -> pd.DataFrame:
        """Fetch OHLCV candles and return as a DataFrame."""
        params: dict[str, Any] = {}
        if since is not None:
            params["since"] = since

        raw = self.exchange.fetch_ohlcv(
            symbol, timeframe=timeframe, limit=limit, params=params
        )
        df = pd.DataFrame(
            raw, columns=["timestamp", "open", "high", "low", "close", "volume"]
        )
        df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
        df.set_index("timestamp", inplace=True)
        return df

    def fetch_ticker(self, symbol: str) -> dict[str, Any]:
        return self.exchange.fetch_ticker(symbol)

    def fetch_balance(self) -> dict[str, Any]:
        return self.exchange.fetch_balance()

    def create_market_buy(
        self, symbol: str, amount: float
    ) -> dict[str, Any]:
        logger.info("MARKET BUY  %s  amount=%.8f", symbol, amount)
        return self.exchange.create_market_buy_order(symbol, amount)

    def create_market_sell(
        self, symbol: str, amount: float
    ) -> dict[str, Any]:
        logger.info("MARKET SELL %s  amount=%.8f", symbol, amount)
        return self.exchange.create_market_sell_order(symbol, amount)

    def create_limit_buy(
        self, symbol: str, amount: float, price: float
    ) -> dict[str, Any]:
        logger.info(
            "LIMIT BUY  %s  amount=%.8f  price=%.2f", symbol, amount, price
        )
        return self.exchange.create_limit_buy_order(symbol, amount, price)

    def create_limit_sell(
        self, symbol: str, amount: float, price: float
    ) -> dict[str, Any]:
        logger.info(
            "LIMIT SELL %s  amount=%.8f  price=%.2f", symbol, amount, price
        )
        return self.exchange.create_limit_sell_order(symbol, amount, price)

    def cancel_order(self, order_id: str, symbol: str) -> dict[str, Any]:
        logger.info("CANCEL order=%s  symbol=%s", order_id, symbol)
        return self.exchange.cancel_order(order_id, symbol)

    def fetch_open_orders(self, symbol: str) -> list[dict[str, Any]]:
        return self.exchange.fetch_open_orders(symbol)
