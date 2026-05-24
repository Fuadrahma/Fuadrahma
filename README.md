# Powerful Trading Bot — Multi-Strategy Algorithmic Trading System

A production-grade algorithmic trading bot with 5 trading strategies, ensemble signal fusion,
Kelly Criterion position sizing, walk-forward backtesting, and real-time risk management.

---

## Features

### Strategies (all active simultaneously via Ensemble)
| Strategy | Signals | Extras |
|---|---|---|
| **RSI + Divergence** | Oversold/overbought crossovers | Bullish/bearish divergence detection |
| **MACD** | Signal-line & zero-line crossovers | Histogram momentum, ADX filter |
| **Bollinger Bands** | Mean reversion + squeeze breakout | Keltner Channel squeeze detector |
| **EMA Crossover** | Fast/Slow EMA crossovers | Multi-timeframe context (EMA 50/200) |
| **VWAP** | Price vs. VWAP crossovers | OBV confirmation, MFI filter |

### Risk Management
- **Kelly Criterion** position sizing (half-Kelly for safety)
- Per-trade stop-loss & take-profit with **trailing stops**
- **Max drawdown** guard (halts trading automatically)
- **Daily loss limit** guard
- Maximum concurrent positions cap
- Position reversal on conflicting signals

### Technical Indicators (pure NumPy/Pandas — no TA-Lib needed)
EMA, SMA, WMA, MACD, VWAP, Supertrend, RSI, Stochastic, CCI,
Williams %R, ROC, Bollinger Bands, ATR, Keltner Channels, ADX, OBV, MFI, CMF

### Backtesting Engine
- Walk-forward simulation with realistic slippage & commission
- Metrics: Sharpe, Sortino, Calmar ratios, max drawdown, profit factor, win rate
- Multi-symbol batch backtesting
- JSON output for further analysis

### Data
- Live data via **ccxt** (Binance, Bybit, OKX, Kraken, etc.)
- **Yahoo Finance** fallback for stocks and crypto ETFs
- Realistic **synthetic data** generator for offline testing
- Local **Parquet cache** to minimize API calls

---

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run a backtest on BTC/USDT (uses synthetic data if no API key set)
python -m trading_bot.main backtest --symbol BTC/USDT --bars 1000

# 3. Backtest all configured symbols
python -m trading_bot.main backtest --all-symbols --bars 500

# 4. Run the paper trading bot
python -m trading_bot.main trade --paper

# 5. Check status dashboard
python -m trading_bot.main status
```

---

## Configuration

Edit `config.yaml` or set environment variables:

| Variable | Description |
|---|---|
| `EXCHANGE_API_KEY` | Your exchange API key |
| `EXCHANGE_API_SECRET` | Your exchange API secret |
| `TELEGRAM_TOKEN` | Telegram bot token for alerts |
| `TELEGRAM_CHAT_ID` | Telegram chat ID |
| `PAPER_TRADING` | Set to `0` to enable live trading |

> **IMPORTANT**: Set `paper_trading: true` (the default) until you are confident in the strategy.
> Live trading carries real financial risk. Past backtest performance does not guarantee future results.

---

## Architecture

```
trading_bot/
├── config.py            # Configuration dataclasses + YAML loader
├── bot.py               # Main trading loop
├── main.py              # CLI entry point
├── dashboard.py         # Rich terminal dashboard
├── data/
│   └── fetcher.py       # ccxt / yfinance / synthetic data
├── strategies/
│   ├── base.py          # BaseStrategy + TradeSignal
│   ├── rsi_strategy.py
│   ├── macd_strategy.py
│   ├── bollinger_strategy.py
│   ├── ema_crossover_strategy.py
│   ├── vwap_strategy.py
│   └── ensemble.py      # Signal fusion
├── risk/
│   └── manager.py       # Position sizing + risk controls
├── execution/
│   └── executor.py      # Paper / live order execution
├── backtesting/
│   └── engine.py        # Walk-forward backtesting
├── notifications/
│   └── notifier.py      # Console + Telegram alerts
└── utils/
    ├── indicators.py    # 20+ technical indicators
    └── logger.py        # Rotating file + console logger
```

---

## Risk Disclaimer

This software is for **educational and research purposes only**.
Cryptocurrency and stock trading involves substantial risk of loss.
**Do not trade with money you cannot afford to lose.**
The authors accept no responsibility for trading losses incurred using this software.
