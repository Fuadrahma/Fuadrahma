# Advanced Crypto Trading Bot

Multi-strategy automated cryptocurrency trading bot with backtesting, risk management, and paper/live trading support.

## Features

- **5 Trading Strategies** — EMA Crossover, RSI, MACD, Bollinger Bands, Multi-Indicator Confluence
- **Risk Management** — Position sizing, stop-loss, take-profit, trailing stop, daily loss limits
- **Backtesting Engine** — Walk-forward backtester with commission simulation and equity tracking
- **Paper Trading** — Test strategies in real-time without risking capital
- **Live Trading** — Connect to 100+ exchanges via ccxt (Binance, Bybit, Coinbase, etc.)
- **Strategy Comparison** — Backtest all strategies side-by-side

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# List available strategies
python main.py list

# Run a backtest
python main.py backtest --strategy ema_crossover --days 180

# Compare all strategies
python main.py backtest-all --days 365

# Start paper trading
python main.py trade
```

## Project Structure

```
bot/
  core/
    config.py       # YAML + env config loader
    exchange.py     # ccxt exchange connector
    models.py       # Signal, Position, Trade models
    portfolio.py    # Balance and trade tracking
    risk.py         # Risk management engine
    backtester.py   # Walk-forward backtester
    engine.py       # Real-time trading loop
  strategies/
    base.py         # Abstract strategy interface
    ema_crossover.py
    rsi.py
    macd.py
    bollinger.py
    multi_indicator.py
    registry.py     # Strategy name → class mapping
  utils/
    logger.py       # Logging setup
    data.py         # Sample data generator
tests/              # 36 unit tests
main.py             # CLI entry point
config.yaml         # Default configuration
```

## Strategies

| Strategy | Type | Description |
|---|---|---|
| `ema_crossover` | Trend | Buy/sell on fast/slow EMA crossover |
| `rsi` | Mean Reversion | Buy oversold, sell overbought |
| `macd` | Trend | Buy/sell on MACD histogram crossover |
| `bollinger_bands` | Mean Reversion | Buy at lower band, sell at upper band |
| `multi_indicator` | Confluence | Requires 3/4 indicators to agree |

## Configuration

Edit `config.yaml` to customize:

```yaml
trading:
  mode: paper          # paper | live
  symbol: BTC/USDT
  timeframe: 1h
  strategy: ema_crossover

risk:
  max_position_pct: 0.02   # 2% per trade
  stop_loss_pct: 0.03      # 3% stop loss
  take_profit_pct: 0.06    # 6% take profit (2:1 R:R)
  max_open_trades: 3
  trailing_stop: false
  max_daily_loss_pct: 0.05 # 5% daily loss limit
```

## Live Trading Setup

1. Copy `.env.example` to `.env` and add your exchange API keys
2. Set `trading.mode: live` in `config.yaml`
3. Set `exchange.sandbox: false` when ready for real trading
4. Run `python main.py trade`

## Running Tests

```bash
python -m pytest tests/ -v
```

## Disclaimer

This software is for educational purposes only. Cryptocurrency trading involves substantial risk of loss. Use at your own risk.
