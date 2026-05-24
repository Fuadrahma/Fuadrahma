"""
Automated tests for the trading bot.
Tests: indicators, strategies, risk manager, backtesting engine, data fetcher.
"""

import math
import sys
import os
import pytest
import numpy as np
import pandas as pd
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ── Fixture: synthetic OHLCV DataFrame ──────────────────────────────────────

def make_ohlcv(n=300, seed=42, price=45000.0, vol_frac=0.01) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    end = datetime.utcnow()
    idx = pd.date_range(end=end, periods=n, freq="1h", tz="UTC")
    returns = rng.normal(0.0001, 0.012, n)
    close = price * np.exp(np.cumsum(returns))
    spread = close * rng.uniform(0.001, 0.003, n)
    high = close + spread * rng.uniform(0.5, 1.5, n)
    low = close - spread * rng.uniform(0.5, 1.5, n)
    open_ = close * (1 + rng.normal(0, 0.003, n))
    volume = price * 100 * rng.lognormal(0, 0.8, n)
    return pd.DataFrame(
        {"open": open_, "high": high, "low": low, "close": close, "volume": volume},
        index=idx,
    )


DF = make_ohlcv(300)


# ═══════════════════════════════════════════════════════════════════════════
# Indicators
# ═══════════════════════════════════════════════════════════════════════════

class TestIndicators:
    def test_rsi_range(self):
        from trading_bot.utils.indicators import rsi
        vals = rsi(DF["close"], 14).dropna()
        assert ((vals >= 0) & (vals <= 100)).all(), "RSI out of [0,100] range"

    def test_macd_structure(self):
        from trading_bot.utils.indicators import macd
        df = macd(DF["close"])
        assert set(df.columns) == {"macd", "signal", "histogram"}
        assert len(df) == len(DF)

    def test_bollinger_bands_spread(self):
        from trading_bot.utils.indicators import bollinger_bands
        bb = bollinger_bands(DF["close"])
        valid = bb.dropna()
        assert (valid["upper"] >= valid["middle"]).all()
        assert (valid["middle"] >= valid["lower"]).all()

    def test_atr_positive(self):
        from trading_bot.utils.indicators import atr
        vals = atr(DF["high"], DF["low"], DF["close"], 14).dropna()
        assert (vals >= 0).all(), "ATR must be non-negative"

    def test_ema_convergence(self):
        from trading_bot.utils.indicators import ema
        series = pd.Series([100.0] * 50)
        result = ema(series, 10)
        # A constant series should produce a constant EMA
        assert abs(result.iloc[-1] - 100.0) < 1e-6

    def test_adx_structure(self):
        from trading_bot.utils.indicators import adx
        df = adx(DF["high"], DF["low"], DF["close"], 14)
        assert "adx" in df.columns
        assert "plus_di" in df.columns
        assert "minus_di" in df.columns

    def test_vwap_single_value(self):
        from trading_bot.utils.indicators import vwap
        vals = vwap(DF["high"], DF["low"], DF["close"], DF["volume"])
        assert len(vals) == len(DF)
        assert not vals.isna().all()

    def test_stochastic_range(self):
        from trading_bot.utils.indicators import stochastic
        df = stochastic(DF["high"], DF["low"], DF["close"])
        valid_k = df["k"].dropna()
        assert ((valid_k >= 0) & (valid_k <= 100)).all()

    def test_obv_monotone_when_always_up(self):
        from trading_bot.utils.indicators import obv
        n = 20
        close = pd.Series([100.0 + i for i in range(n)])
        volume = pd.Series([1000.0] * n)
        vals = obv(close, volume)
        # OBV should increase (all days close up)
        assert vals.iloc[-1] > vals.iloc[1]

    def test_mfi_range(self):
        from trading_bot.utils.indicators import mfi
        vals = mfi(DF["high"], DF["low"], DF["close"], DF["volume"], 14).dropna()
        assert ((vals >= 0) & (vals <= 100)).all()


# ═══════════════════════════════════════════════════════════════════════════
# Strategies
# ═══════════════════════════════════════════════════════════════════════════

class TestStrategies:
    def _config(self):
        from trading_bot.config import load_config
        return load_config.__wrapped__() if hasattr(load_config, "__wrapped__") else None

    def _signal(self, strategy_cls, df=None):
        from trading_bot.config import BotConfig
        cfg = BotConfig()
        strategy = strategy_cls(cfg)
        return strategy.generate_signal(df or DF, "TEST/USDT")

    def test_rsi_returns_trade_signal(self):
        from trading_bot.strategies.rsi_strategy import RSIStrategy
        from trading_bot.strategies.base import TradeSignal
        sig = self._signal(RSIStrategy)
        assert isinstance(sig, TradeSignal)
        assert 0.0 <= sig.confidence <= 1.0
        assert sig.price > 0

    def test_macd_returns_trade_signal(self):
        from trading_bot.strategies.macd_strategy import MACDStrategy
        from trading_bot.strategies.base import TradeSignal
        sig = self._signal(MACDStrategy)
        assert isinstance(sig, TradeSignal)

    def test_bollinger_returns_trade_signal(self):
        from trading_bot.strategies.bollinger_strategy import BollingerStrategy
        from trading_bot.strategies.base import TradeSignal
        sig = self._signal(BollingerStrategy)
        assert isinstance(sig, TradeSignal)

    def test_ema_crossover_returns_trade_signal(self):
        from trading_bot.strategies.ema_crossover_strategy import EMACrossoverStrategy
        from trading_bot.strategies.base import TradeSignal
        sig = self._signal(EMACrossoverStrategy)
        assert isinstance(sig, TradeSignal)

    def test_vwap_returns_trade_signal(self):
        from trading_bot.strategies.vwap_strategy import VWAPStrategy
        from trading_bot.strategies.base import TradeSignal
        sig = self._signal(VWAPStrategy)
        assert isinstance(sig, TradeSignal)

    def test_confidence_in_range(self):
        from trading_bot.strategies.rsi_strategy import RSIStrategy
        from trading_bot.strategies.macd_strategy import MACDStrategy
        from trading_bot.strategies.bollinger_strategy import BollingerStrategy
        from trading_bot.config import BotConfig
        cfg = BotConfig()
        for cls in [RSIStrategy, MACDStrategy, BollingerStrategy]:
            sig = cls(cfg).generate_signal(DF, "X")
            assert 0.0 <= sig.confidence <= 1.0, f"{cls.__name__} confidence out of range"


# ═══════════════════════════════════════════════════════════════════════════
# Ensemble
# ═══════════════════════════════════════════════════════════════════════════

class TestEnsemble:
    def _ensemble(self, method="weighted_vote", min_conf=0.3):
        from trading_bot.strategies.rsi_strategy import RSIStrategy
        from trading_bot.strategies.macd_strategy import MACDStrategy
        from trading_bot.strategies.bollinger_strategy import BollingerStrategy
        from trading_bot.strategies.ema_crossover_strategy import EMACrossoverStrategy
        from trading_bot.strategies.vwap_strategy import VWAPStrategy
        from trading_bot.strategies.ensemble import EnsembleStrategy
        from trading_bot.config import BotConfig
        cfg = BotConfig()
        strats = [RSIStrategy(cfg), MACDStrategy(cfg), BollingerStrategy(cfg),
                  EMACrossoverStrategy(cfg), VWAPStrategy(cfg)]
        return EnsembleStrategy(strats, method=method, min_confidence=min_conf)

    def test_weighted_vote_returns_signal(self):
        from trading_bot.strategies.base import TradeSignal
        ens = self._ensemble("weighted_vote")
        sig = ens.generate_signal(DF, "BTC/USDT")
        assert isinstance(sig, TradeSignal)

    def test_majority_returns_signal(self):
        from trading_bot.strategies.base import TradeSignal
        ens = self._ensemble("majority")
        sig = ens.generate_signal(DF, "BTC/USDT")
        assert isinstance(sig, TradeSignal)

    def test_unanimous_returns_signal(self):
        from trading_bot.strategies.base import TradeSignal
        ens = self._ensemble("unanimous")
        sig = ens.generate_signal(DF, "BTC/USDT")
        assert isinstance(sig, TradeSignal)

    def test_confidence_weighted_returns_signal(self):
        from trading_bot.strategies.base import TradeSignal
        ens = self._ensemble("confidence_weighted")
        sig = ens.generate_signal(DF, "BTC/USDT")
        assert isinstance(sig, TradeSignal)

    def test_ensemble_confidence_range(self):
        ens = self._ensemble("weighted_vote")
        for i in range(10):
            df = make_ohlcv(300, seed=i * 7)
            sig = ens.generate_signal(df, "X")
            assert 0.0 <= sig.confidence <= 1.0


# ═══════════════════════════════════════════════════════════════════════════
# Risk Manager
# ═══════════════════════════════════════════════════════════════════════════

class TestRiskManager:
    def _manager(self, capital=10_000.0):
        from trading_bot.risk.manager import RiskManager
        from trading_bot.config import BotConfig
        return RiskManager(BotConfig(), initial_capital=capital)

    def _buy_signal(self, price=100.0):
        from trading_bot.strategies.base import TradeSignal, Signal
        return TradeSignal(
            signal=Signal.BUY, symbol="TEST/USDT", strategy="test",
            confidence=0.70, price=price,
            stop_loss=price * 0.98, take_profit=price * 1.04,
        )

    def test_can_trade_initially(self):
        rm = self._manager()
        ok, msg = rm.can_trade()
        assert ok, f"Should be tradeable initially: {msg}"

    def test_open_and_close_position(self):
        rm = self._manager()
        sig = self._buy_signal(100.0)
        pos = rm.open_position(sig)
        assert pos is not None
        assert "TEST/USDT" in rm.open_positions

        trade = rm.close_position("TEST/USDT", 104.0, "take_profit")
        assert trade is not None
        assert trade["pnl"] > 0
        assert "TEST/USDT" not in rm.open_positions

    def test_stop_loss_triggers(self):
        rm = self._manager()
        sig = self._buy_signal(100.0)
        rm.open_position(sig)
        rm.update_positions({"TEST/USDT": 97.0})  # below SL of 98
        assert "TEST/USDT" not in rm.open_positions

    def test_max_positions_limit(self):
        from trading_bot.strategies.base import TradeSignal, Signal
        rm = self._manager()
        for i in range(10):  # try to open 10 positions
            sig = TradeSignal(Signal.BUY, f"SYM{i}/USDT", "test",
                              0.70, 100.0, 98.0, 104.0)
            rm.open_position(sig)
        assert len(rm.open_positions) <= 5  # config max is 5

    def test_position_size_positive(self):
        rm = self._manager()
        sig = self._buy_signal(50000.0)
        size = rm.position_size(sig)
        assert size > 0

    def test_drawdown_guard(self):
        rm = self._manager(10_000)
        rm.capital = 8_000  # simulate 20% drawdown
        rm.peak_capital = 10_000
        ok, reason = rm.can_trade()
        assert not ok
        assert "drawdown" in reason.lower()

    def test_daily_loss_limit(self):
        rm = self._manager(10_000)
        rm.daily_start_capital = 10_000
        rm.capital = 9_400  # 6% daily loss (limit is 5%)
        ok, reason = rm.can_trade()
        assert not ok
        assert "daily" in reason.lower()

    def test_trailing_stop_updates(self):
        rm = self._manager()
        sig = self._buy_signal(100.0)
        pos = rm.open_position(sig)
        initial_sl = pos.stop_loss
        pos.update_trailing_stop(110.0)  # price rose
        assert pos.stop_loss > initial_sl  # trailing stop should rise

    def test_stats_structure(self):
        rm = self._manager()
        sig = self._buy_signal(100.0)
        rm.open_position(sig)
        rm.close_position("TEST/USDT", 104.0, "tp")
        stats = rm.stats()
        assert "total_trades" in stats
        assert "win_rate" in stats
        assert "capital" in stats


# ═══════════════════════════════════════════════════════════════════════════
# Data Fetcher
# ═══════════════════════════════════════════════════════════════════════════

class TestDataFetcher:
    def test_synthetic_data_shape(self):
        from trading_bot.data.fetcher import MarketDataFetcher
        fetcher = MarketDataFetcher(data_dir="/tmp/test_data")
        df = fetcher.fetch_ohlcv("BTC/USDT", "1h", 300)
        assert len(df) == 300
        assert set(["open", "high", "low", "close", "volume"]).issubset(df.columns)

    def test_synthetic_data_ohlcv_consistency(self):
        from trading_bot.data.fetcher import MarketDataFetcher
        fetcher = MarketDataFetcher(data_dir="/tmp/test_data")
        df = fetcher.fetch_ohlcv("ETH/USDT", "1h", 100)
        assert (df["high"] >= df["low"]).all()
        assert (df["volume"] > 0).all()

    def test_different_symbols_produce_different_data(self):
        from trading_bot.data.fetcher import MarketDataFetcher
        fetcher = MarketDataFetcher(data_dir="/tmp/test_data", use_cache=False)
        df_btc = fetcher.fetch_ohlcv("BTC/USDT", "1h", 100)
        df_eth = fetcher.fetch_ohlcv("ETH/USDT", "1h", 100)
        # Mean prices should differ (BTC >> ETH by design in synthetic data)
        assert abs(df_btc["close"].mean() - df_eth["close"].mean()) > 1.0


# ═══════════════════════════════════════════════════════════════════════════
# Backtesting Engine
# ═══════════════════════════════════════════════════════════════════════════

class TestBacktestEngine:
    def _build(self):
        from trading_bot.strategies.rsi_strategy import RSIStrategy
        from trading_bot.strategies.macd_strategy import MACDStrategy
        from trading_bot.strategies.ensemble import EnsembleStrategy
        from trading_bot.backtesting.engine import BacktestEngine
        from trading_bot.config import BotConfig
        cfg = BotConfig()
        ens = EnsembleStrategy([RSIStrategy(cfg), MACDStrategy(cfg)],
                               min_confidence=0.40)
        return BacktestEngine(ens, cfg)

    def test_backtest_runs_without_error(self):
        engine = self._build()
        result = engine.run(make_ohlcv(300), "BTC/USDT")
        assert result is not None

    def test_backtest_capital_tracked(self):
        engine = self._build()
        result = engine.run(make_ohlcv(300, seed=10), "BTC/USDT")
        assert result.final_capital > 0
        assert result.initial_capital == 10_000.0

    def test_backtest_equity_curve_length(self):
        engine = self._build()
        result = engine.run(make_ohlcv(300), "BTC/USDT")
        # Equity curve should cover the non-warmup bars
        assert len(result.equity_curve) == 300 - engine.min_bars

    def test_backtest_metrics_finite(self):
        engine = self._build()
        result = engine.run(make_ohlcv(500, seed=99), "TEST/USDT")
        assert math.isfinite(result.sharpe_ratio)
        assert math.isfinite(result.max_drawdown)
        assert 0.0 <= result.max_drawdown <= 1.0

    def test_backtest_result_summary(self):
        engine = self._build()
        result = engine.run(make_ohlcv(300), "BTC/USDT")
        summary = result.summary()
        assert "BACKTEST RESULTS" in summary
        assert "Win Rate" in summary


# ═══════════════════════════════════════════════════════════════════════════
# Executor (paper trading)
# ═══════════════════════════════════════════════════════════════════════════

class TestPaperExecutor:
    def _setup(self):
        from trading_bot.risk.manager import RiskManager
        from trading_bot.execution.executor import TradingExecutor
        from trading_bot.config import BotConfig
        cfg = BotConfig()
        rm = RiskManager(cfg, 10_000)
        return TradingExecutor(rm, cfg), rm

    def test_execute_buy_signal(self):
        from trading_bot.strategies.base import TradeSignal, Signal
        executor, rm = self._setup()
        sig = TradeSignal(Signal.BUY, "BTC/USDT", "test", 0.70, 45000.0, 44100.0, 46800.0)
        order = executor.execute_signal(sig)
        assert order is not None
        assert order.status == "filled"
        assert "BTC/USDT" in rm.open_positions

    def test_execute_hold_signal_returns_none(self):
        from trading_bot.strategies.base import TradeSignal, Signal
        executor, rm = self._setup()
        sig = TradeSignal(Signal.HOLD, "BTC/USDT", "test", 0.0, 45000.0)
        result = executor.execute_signal(sig)
        assert result is None

    def test_execute_duplicate_position_skipped(self):
        from trading_bot.strategies.base import TradeSignal, Signal
        executor, rm = self._setup()
        sig = TradeSignal(Signal.BUY, "BTC/USDT", "test", 0.70, 45000.0, 44100.0, 46800.0)
        executor.execute_signal(sig)
        # Second BUY signal on same symbol should be ignored
        result = executor.execute_signal(sig)
        assert result is None
        assert len(rm.open_positions) == 1
