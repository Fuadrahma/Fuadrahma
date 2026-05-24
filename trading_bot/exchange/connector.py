"""
Exchange connector using ccxt.
Supports paper trading mode — no real orders are placed.
"""
from __future__ import annotations
import logging
import time
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timezone

import pandas as pd

logger = logging.getLogger(__name__)

try:
    import ccxt
    CCXT_AVAILABLE = True
except ImportError:
    CCXT_AVAILABLE = False
    logger.warning("ccxt not installed — running in simulation mode only")


class ExchangeConnector:
    """Unified exchange interface with paper trading support."""

    def __init__(self, config=None):
        from trading_bot.config import config as default_config
        cfg = config or default_config
        self.exchange_cfg = cfg.exchange
        self.paper_trading = self.exchange_cfg.paper_trading
        self._exchange = None
        self._paper_orders: List[dict] = []
        self._paper_balance: Dict[str, float] = {"USDT": 10_000.0}

        if not self.paper_trading and CCXT_AVAILABLE:
            self._init_exchange()

    def _init_exchange(self):
        """Initialize real exchange connection."""
        exchange_class = getattr(ccxt, self.exchange_cfg.name, None)
        if exchange_class is None:
            raise ValueError(f"Unknown exchange: {self.exchange_cfg.name}")

        params = {
            "apiKey": self.exchange_cfg.api_key,
            "secret": self.exchange_cfg.api_secret,
            "enableRateLimit": True,
        }
        if self.exchange_cfg.testnet:
            params["options"] = {"defaultType": "future"}

        self._exchange = exchange_class(params)
        if self.exchange_cfg.testnet:
            self._exchange.set_sandbox_mode(True)
        logger.info("Connected to %s (testnet=%s)", self.exchange_cfg.name, self.exchange_cfg.testnet)

    def fetch_ohlcv(
        self,
        symbol: str,
        timeframe: str = "1h",
        limit: int = 500,
    ) -> pd.DataFrame:
        """Fetch OHLCV candles and return as DataFrame."""
        if self._exchange is not None:
            raw = self._exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
            df = pd.DataFrame(raw, columns=["timestamp", "open", "high", "low", "close", "volume"])
            df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms", utc=True)
            df.set_index("timestamp", inplace=True)
            return df

        # Simulation: generate synthetic OHLCV for testing
        return self._generate_synthetic_ohlcv(symbol, limit, timeframe)

    def _generate_synthetic_ohlcv(
        self, symbol: str, limit: int, timeframe: str
    ) -> pd.DataFrame:
        """Generate realistic synthetic price data for simulation/testing."""
        import numpy as np

        seed = sum(ord(c) for c in symbol)
        rng = np.random.default_rng(seed)

        freq_map = {"1m": "1min", "5m": "5min", "15m": "15min", "1h": "1h", "4h": "4h", "1d": "1D"}
        freq = freq_map.get(timeframe, "1h")
        end = pd.Timestamp.utcnow()
        idx = pd.date_range(end=end, periods=limit, freq=freq)

        base_prices = {"BTC/USDT": 65_000, "ETH/USDT": 3_500, "BNB/USDT": 600,
                       "SOL/USDT": 180, "XRP/USDT": 0.65}
        start_price = base_prices.get(symbol, 100.0)

        # GBM simulation
        dt = 1.0
        mu = 0.0002
        sigma = 0.015
        returns = rng.normal(mu * dt, sigma * np.sqrt(dt), limit)
        prices = start_price * np.cumprod(1 + returns)

        open_ = prices
        close_ = prices * (1 + rng.normal(0, 0.003, limit))
        high_ = np.maximum(open_, close_) * (1 + rng.uniform(0, 0.005, limit))
        low_ = np.minimum(open_, close_) * (1 - rng.uniform(0, 0.005, limit))
        volume = rng.uniform(500, 5000, limit) * (start_price / 100)

        return pd.DataFrame({
            "open": open_, "high": high_, "low": low_,
            "close": close_, "volume": volume,
        }, index=idx)

    def fetch_ticker(self, symbol: str) -> Dict:
        """Fetch latest ticker."""
        if self._exchange:
            return self._exchange.fetch_ticker(symbol)
        # Synthetic ticker
        df = self._generate_synthetic_ohlcv(symbol, 2, "1m")
        price = df["close"].iloc[-1]
        return {"last": price, "bid": price * 0.9999, "ask": price * 1.0001}

    def create_order(
        self,
        symbol: str,
        order_type: str,
        side: str,
        amount: float,
        price: Optional[float] = None,
    ) -> dict:
        """Place order (or simulate it in paper mode)."""
        order = {
            "id": f"paper_{int(time.time() * 1000)}",
            "symbol": symbol,
            "type": order_type,
            "side": side,
            "amount": amount,
            "price": price,
            "status": "closed",
            "filled": amount,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "paper": self.paper_trading,
        }
        if self.paper_trading:
            self._paper_orders.append(order)
            logger.info("[PAPER] %s %s %.6f %s @ %s", side.upper(), order_type, amount, symbol, price)
            return order

        if self._exchange:
            if order_type == "market":
                return self._exchange.create_market_order(symbol, side, amount)
            return self._exchange.create_limit_order(symbol, side, amount, price)

        return order

    def get_balance(self) -> Dict[str, float]:
        """Fetch account balances."""
        if self.paper_trading:
            return self._paper_balance
        if self._exchange:
            raw = self._exchange.fetch_balance()
            return {k: v["free"] for k, v in raw["total"].items() if v["free"] > 0}
        return {}

    def fetch_all_ohlcv(
        self, symbols: List[str], timeframe: str = "1h", limit: int = 500
    ) -> Dict[str, pd.DataFrame]:
        """Fetch OHLCV for multiple symbols."""
        result = {}
        for symbol in symbols:
            try:
                result[symbol] = self.fetch_ohlcv(symbol, timeframe, limit)
            except Exception as e:
                logger.error("Failed to fetch %s: %s", symbol, e)
        return result
