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
