# Pin Bar Trading EA - نظام تداول ذيول الشموع

Expert Advisor for MetaTrader 5 that detects and trades Pin Bar reversal patterns on the M1 timeframe, with multi-layer filtering and a professional Arabic dashboard.

## Features

- **Pin Bar Detection**: Identifies bullish and bearish pin bars based on configurable body/tail ratios
- **ATR Volatility Filter**: Filters out dead/noise candles using ATR threshold
- **EMA Trend Filter**: Only trades in the direction of the EMA trend
- **Volume Filter**: Requires above-average volume for signal confirmation
- **Automatic Trade Execution**: Opens market orders with calculated SL/TP (configurable R:R)
- **Arabic Dashboard**: Real-time on-chart panel showing filters, stats, and signal history
- **Multi-Alert System**: Sound, popup, and push notification alerts

## Installation

1. Copy `MQL5/Experts/PinBarEA.mq5` to your MT5 `Experts` folder
2. Compile in MetaEditor (F7)
3. Attach the EA to any M1 chart

**One file only - no extra dependencies needed.**

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Min_Bar_Size_ATR_Multiplier | 1.2 | Minimum candle size relative to ATR |
| Max_Body_Ratio | 0.25 | Maximum body-to-range ratio (25%) |
| Min_Tail_Ratio | 0.65 | Minimum reversal tail ratio (65%) |
| Trend_Filter_EMA | 50 | EMA period for trend direction |
| Volume_Filter_Period | 20 | Volume moving average period |
| Volume_Multiplier | 1.3 | Required volume above average (130%) |
| Lot_Size | 0.01 | Trade lot size |
| Risk_Reward | 2.0 | Risk-to-reward ratio (1:2) |
| SL_Buffer | 2 | Extra pips for stop loss placement |

## Signal Logic

**Buy Signal**: Small body + long lower tail + price above EMA + high volume + ATR filter pass

**Sell Signal**: Small body + long upper tail + price below EMA + high volume + ATR filter pass

---

## v1.2 — What's new

> **Not compiled or backtested.** The code was written without MetaEditor available. Compile it (F7) and run it in the Strategy Tester ("Every tick based on real ticks", 6+ months) and on a demo account before using any real money.

**Execution safety**
- Respects `SYMBOL_TRADE_STOPS_LEVEL` / `FREEZE_LEVEL` (widens the SL if `InpAdjustStops`).
- SL buffer is `max(InpSLBufferPips, InpSLBufferATR × ATR)`; pip size is derived from the symbol's digits (no more fixed `point × 10`).
- Lot is normalized to the broker's step/min/max, with a free-margin check.
- Retries on requote / price changed / timeout (`InpMaxRetries`).

**Risk management**
- Position size by % of balance (`InpUseRiskPercent`, `InpRiskPercent`), skipping trades whose minimum lot would exceed 2× the allowed risk.
- Spread must be ≤ `InpMaxSpreadRisk` × risk (default 15%).
- Daily loss limit, consecutive-loss pause, and a persistent max-drawdown halt (set `InpResetHalt` once to clear it).
- Cool-down between same-direction trades (`InpMinBarsBetween`).
- Break-even at `InpBE_R` × risk and an optional ATR trailing stop.

**Signal quality (all OFF by default, so default entries match v1.1)**
- Higher-timeframe EMA confirmation (`InpUseHTF`).
- Level requirement: swing low/high or previous-day low/high (`InpUseLevel`).
- Session filter in server time (`InpUseSession`) and high-impact news filter via the built-in MT5 calendar (`InpUseNews`; not available in the tester).
- Adaptive tail/body thresholds (`InpAdaptive`).

**Performance and monitoring**
- Stats are computed once from history and updated incrementally in `OnTradeTransaction` (buy/sell counters no longer reset on restart).
- Dashboard updates in place instead of deleting and recreating every object each second.
- Trades logged to `Common\Files\PinBarEA_trades.csv` (OPEN/CLOSE rows) for analysis.
- Optional Telegram alerts: allow `https://api.telegram.org` under Tools → Options → Expert Advisors → Allow WebRequest, then set `InpTelegramToken` and `InpTelegramChat`.
