# 🤖 Ultimate Crypto Trading Bot

A production-grade, multi-strategy cryptocurrency trading bot with a real-time web dashboard, ML signal filtering, and comprehensive risk management.

---

## Features

| Category | Details |
|---|---|
| **Strategies** | RSI, MACD, Bollinger Bands, EMA Crossover, **Hybrid (weighted voting)** |
| **Risk Management** | Position sizing, Stop-Loss, Take-Profit, Trailing Stop, Max Drawdown protection |
| **ML Filter** | Scikit-learn ensemble (RF + GBM + LR) filters low-quality signals |
| **Backtesting** | Full event-driven backtester with Sharpe, Sortino, Calmar, Profit Factor, etc. |
| **Exchange** | ccxt (Binance, Bybit, etc.) + built-in **paper trading mode** |
| **Dashboard** | FastAPI + Chart.js real-time web UI |
| **Notifications** | Telegram alerts for trades, signals, errors, and portfolio summaries |

---

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Get signals for a symbol (demo mode, no API keys needed)
python main.py signal BTC/USDT

# Run backtests
python main.py backtest --symbols BTC/USDT ETH/USDT --strategies hybrid rsi macd

# Launch web dashboard (http://localhost:8080)
python main.py demo

# Start live paper trading
python main.py bot
```

---

## Architecture

```
trading_bot/
├── config/          # Central configuration (env-overridable)
├── strategies/      # RSI · MACD · Bollinger · EMA Crossover · Hybrid
│   └── indicators.py  # Pure NumPy/Pandas technical indicator library
├── risk_management/ # Position sizing · SL/TP · Trailing stop · Drawdown guard
├── backtesting/     # Event-driven backtester with full performance metrics
├── exchange/        # ccxt connector + synthetic data for paper trading
├── ml/              # Ensemble price-direction predictor (sklearn)
├── notifications/   # Telegram bot alerts
└── dashboard/       # FastAPI + Chart.js single-page app
```

---

## Configuration

All settings can be overridden via environment variables:

| Variable | Default | Description |
|---|---|---|
| `EXCHANGE` | `binance` | Exchange name (ccxt) |
| `API_KEY` / `API_SECRET` | — | Exchange credentials |
| `PAPER_TRADING` | `true` | Enable paper trading |
| `TESTNET` | `true` | Use exchange testnet |
| `STRATEGY` | `hybrid` | Strategy to use |
| `TIMEFRAME` | `1h` | OHLCV candle timeframe |
| `MAX_OPEN_TRADES` | `5` | Max simultaneous positions |
| `STAKE_AMOUNT` | `100` | USDT per trade |
| `STOP_LOSS_PCT` | `0.03` | Default stop-loss (3%) |
| `TAKE_PROFIT_PCT` | `0.06` | Default take-profit (6%) |
| `MAX_RISK_PER_TRADE` | `0.02` | Max portfolio risk per trade (2%) |
| `TELEGRAM_TOKEN` | — | Telegram bot token |
| `TELEGRAM_CHAT_ID` | — | Telegram chat/channel ID |
| `ENABLE_TELEGRAM` | `false` | Enable Telegram notifications |

---

## Strategies

### Hybrid Strategy (recommended)
Combines all four strategies using a **weighted voting system**:
- RSI (25%) · MACD (30%) · Bollinger Bands (20%) · EMA Crossover (25%)
- Uses ATR-based dynamic stop-loss and take-profit
- Only enters if weighted score exceeds a confidence threshold

### RSI Strategy
Mean-reversion: buys on oversold → overbought crossover, sells on overbought → oversold crossover. Includes extreme oversold/overbought detection for higher-confidence signals.

### MACD Strategy
Momentum: signals on MACD/signal line crossover with histogram acceleration confirmation. Trend-aligned (EMA 21/55).

### Bollinger Bands Strategy
Dual mode: mean-reversion (touch band + RSI divergence) + **squeeze breakout** detection.

### EMA Crossover Strategy
Golden/Death cross (EMA 9/21) with long-term trend filter (EMA 200) and volume confirmation.

---

## Risk Management

The `RiskManager` enforces:
1. **Position sizing** — risks at most `MAX_RISK_PER_TRADE` of balance per trade
2. **Signal validation** — min confidence, R/R ≥ 1.5, max open trades, drawdown gate
3. **Trailing stop** — tracks price peak and adjusts stop dynamically
4. **Max drawdown kill switch** — halts new entries if drawdown exceeds limit

---

## Dashboard

<img src="trading_bot/data/dashboard_preview.png" alt="Dashboard" width="800" />

Available API endpoints:

| Endpoint | Description |
|---|---|
| `GET /` | Dashboard UI |
| `GET /api/status` | Live bot status + portfolio |
| `GET /api/backtest/{symbol}?strategy=hybrid` | Run backtest |
| `GET /api/signals/{symbol}?strategy=hybrid` | Get trading signal |
| `GET /api/strategies` | List available strategies |

---

## Testing

```bash
python -m pytest tests/ -v
```

29 tests covering indicators, all strategies, risk management, position lifecycle, and backtesting engine.

---

> ⚠️ **Disclaimer**: This software is for educational purposes only. Trading cryptocurrencies involves substantial risk. Never invest money you cannot afford to lose.
