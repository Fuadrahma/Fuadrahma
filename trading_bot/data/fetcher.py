"""
Market data fetcher — supports ccxt exchanges and Yahoo Finance fallback.
Caches OHLCV data locally to avoid redundant API calls.
"""

import os
import time
import hashlib
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Optional, Dict
from pathlib import Path

from trading_bot.utils.logger import get_logger

logger = get_logger("data.fetcher")


class MarketDataFetcher:
    def __init__(self, exchange_cfg=None, data_dir: str = "data/market",
                 use_cache: bool = True):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.use_cache = use_cache
        self.exchange = None
        self._cache: Dict[str, pd.DataFrame] = {}

        if exchange_cfg:
            self._init_exchange(exchange_cfg)

    def _init_exchange(self, cfg):
        try:
            import ccxt
            exchange_cls = getattr(ccxt, cfg.name, None)
            if exchange_cls is None:
                logger.warning(f"Exchange '{cfg.name}' not found in ccxt, using demo data.")
                return
            params = {}
            if cfg.api_key:
                params["apiKey"] = cfg.api_key
            if cfg.api_secret:
                params["secret"] = cfg.api_secret
            if cfg.testnet:
                params["options"] = {"defaultType": "future"}
            self.exchange = exchange_cls(params)
            if cfg.testnet and hasattr(self.exchange, "set_sandbox_mode"):
                self.exchange.set_sandbox_mode(True)
            logger.info(f"Initialized exchange: {cfg.name} (testnet={cfg.testnet})")
        except ImportError:
            logger.warning("ccxt not installed — using synthetic/cached data only.")
        except Exception as e:
            logger.warning(f"Exchange init failed: {e} — using synthetic/cached data only.")

    def _cache_path(self, symbol: str, timeframe: str) -> Path:
        key = f"{symbol.replace('/', '_')}_{timeframe}.parquet"
        return self.data_dir / key

    def fetch_ohlcv(self, symbol: str, timeframe: str = "1h",
                    limit: int = 500) -> pd.DataFrame:
        cache_key = f"{symbol}_{timeframe}"
        cached_path = self._cache_path(symbol, timeframe)

        # Return in-memory cache if fresh (< 60 s old)
        if cache_key in self._cache:
            return self._cache[cache_key]

        # Try to load from disk cache
        if self.use_cache and cached_path.exists():
            mtime = cached_path.stat().st_mtime
            age_seconds = time.time() - mtime
            if age_seconds < 3600:  # 1-hour freshness
                df = pd.read_parquet(cached_path)
                self._cache[cache_key] = df
                logger.debug(f"Loaded {symbol}/{timeframe} from disk cache ({len(df)} bars).")
                return df

        # Fetch from exchange
        df = self._fetch_from_exchange(symbol, timeframe, limit)
        if df is None or df.empty:
            df = self._fetch_from_yfinance(symbol, timeframe, limit)
        if df is None or df.empty:
            logger.warning(f"No real data for {symbol}. Generating synthetic data.")
            df = self._generate_synthetic(symbol, timeframe, limit)

        df = self._clean(df)
        self._cache[cache_key] = df
        if self.use_cache:
            df.to_parquet(cached_path)
        return df

    def _fetch_from_exchange(self, symbol: str, timeframe: str,
                              limit: int) -> Optional[pd.DataFrame]:
        if self.exchange is None:
            return None
        try:
            raw = self.exchange.fetch_ohlcv(symbol, timeframe, limit=limit)
            df = pd.DataFrame(raw, columns=["timestamp", "open", "high", "low", "close", "volume"])
            df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms", utc=True)
            df.set_index("timestamp", inplace=True)
            logger.info(f"Fetched {len(df)} bars for {symbol}/{timeframe} from {self.exchange.id}.")
            return df
        except Exception as e:
            logger.warning(f"Exchange fetch failed for {symbol}: {e}")
            return None

    def _fetch_from_yfinance(self, symbol: str, timeframe: str,
                              limit: int) -> Optional[pd.DataFrame]:
        try:
            import yfinance as yf
            tf_map = {
                "1m": "1m", "5m": "5m", "15m": "15m", "30m": "30m",
                "1h": "1h", "4h": "4h", "1d": "1d", "1w": "1wk",
            }
            yf_symbol = symbol.replace("/", "-")
            period_days = max(limit // 24, 30) if "h" in timeframe else limit
            period_str = f"{period_days}d"
            ticker = yf.Ticker(yf_symbol)
            df = ticker.history(period=period_str, interval=tf_map.get(timeframe, "1h"))
            if df.empty:
                return None
            df.index = pd.to_datetime(df.index, utc=True)
            df.columns = [c.lower() for c in df.columns]
            df = df[["open", "high", "low", "close", "volume"]]
            logger.info(f"Fetched {len(df)} bars for {symbol}/{timeframe} from Yahoo Finance.")
            return df
        except Exception as e:
            logger.warning(f"yfinance fetch failed for {symbol}: {e}")
            return None

    def _generate_synthetic(self, symbol: str, timeframe: str, limit: int) -> pd.DataFrame:
        """Generate realistic synthetic OHLCV data for testing."""
        seed = int(hashlib.md5(symbol.encode()).hexdigest(), 16) % (2 ** 32)
        rng = np.random.default_rng(seed)

        tf_minutes = {"1m": 1, "5m": 5, "15m": 15, "30m": 30,
                      "1h": 60, "4h": 240, "1d": 1440}.get(timeframe, 60)

        end = datetime.utcnow()
        start = end - timedelta(minutes=tf_minutes * limit)
        index = pd.date_range(start=start, periods=limit, freq=f"{tf_minutes}min", tz="UTC")

        price_map = {
            "BTC": 45000, "ETH": 2800, "BNB": 380, "SOL": 120,
            "XRP": 0.65, "ADA": 0.55, "DOGE": 0.10,
        }
        base_symbol = symbol.split("/")[0]
        base_price = price_map.get(base_symbol, 100.0)

        # Geometric Brownian Motion
        mu = 0.0001
        sigma = 0.012
        dt = tf_minutes / (60 * 24 * 365)
        returns = rng.normal(mu * dt, sigma * np.sqrt(dt), limit)
        close = base_price * np.exp(np.cumsum(returns))

        spread = close * rng.uniform(0.0005, 0.002, limit)
        high = close + spread * rng.uniform(0.5, 1.5, limit)
        low = close - spread * rng.uniform(0.5, 1.5, limit)
        open_ = close * (1 + rng.normal(0, 0.003, limit))

        base_vol = base_price * 100
        volume = base_vol * rng.lognormal(0, 0.8, limit)

        return pd.DataFrame({
            "open": open_, "high": high, "low": low, "close": close, "volume": volume
        }, index=index)

    def _clean(self, df: pd.DataFrame) -> pd.DataFrame:
        df = df.sort_index().dropna()
        df = df[~df.index.duplicated(keep="last")]
        for col in ["open", "high", "low", "close", "volume"]:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")
        df["high"] = df[["open", "high", "low", "close"]].max(axis=1)
        df["low"] = df[["open", "high", "low", "close"]].min(axis=1)
        df = df.dropna()
        return df

    def get_current_price(self, symbol: str) -> float:
        df = self.fetch_ohlcv(symbol, "1m", limit=5)
        return float(df["close"].iloc[-1]) if not df.empty else 0.0
