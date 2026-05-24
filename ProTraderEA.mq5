//+------------------------------------------------------------------+
//|                                                  ProTraderEA.mq5 |
//|                          Copyright 2024-2026, Fuad Trading Systems |
//|                     https://github.com/Fuadrahma/Fuadrahma        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2026, Fuad Trading Systems"
#property link      "https://github.com/Fuadrahma/Fuadrahma"
#property version   "3.00"
#property description "ProTrader EA - Advanced Multi-Strategy Trading Bot"
#property description "Combines Trend Following, Mean Reversion, Breakout & Smart Money"
#property description "Built-in risk management, multi-timeframe analysis, and auto-optimization"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Strategy Selection                                                |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY
  {
   STRATEGY_TREND      = 0,  // Trend Following (MA + MACD + ADX)
   STRATEGY_REVERSAL   = 1,  // Mean Reversion (RSI + Bollinger)
   STRATEGY_BREAKOUT   = 2,  // Breakout (Donchian + Volume)
   STRATEGY_SMART      = 3,  // Smart Money (Order Blocks + FVG)
   STRATEGY_COMBINED   = 4,  // Combined (All strategies vote)
  };

enum ENUM_RISK_MODE
  {
   RISK_FIXED_LOT      = 0,  // Fixed Lot Size
   RISK_PERCENT        = 1,  // Risk % of Balance
   RISK_KELLY          = 2,  // Kelly Criterion
   RISK_MARTINGALE     = 3,  // Anti-Martingale
  };

enum ENUM_EXIT_MODE
  {
   EXIT_SL_TP          = 0,  // Stop Loss / Take Profit
   EXIT_TRAILING       = 1,  // Trailing Stop
   EXIT_ATR_BASED      = 2,  // ATR-Based Dynamic
   EXIT_CHANDELIER     = 3,  // Chandelier Exit
   EXIT_COMBINED       = 4,  // Combined Exit Logic
  };

enum ENUM_SESSION
  {
   SESSION_ALL         = 0,  // Trade All Sessions
   SESSION_LONDON      = 1,  // London Session Only
   SESSION_NEWYORK     = 2,  // New York Session Only
   SESSION_OVERLAP     = 3,  // London-NY Overlap
   SESSION_ASIAN       = 4,  // Asian Session Only
  };

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

input group "=== Strategy Settings ==="
input ENUM_STRATEGY   InpStrategy       = STRATEGY_COMBINED;  // Trading Strategy
input ENUM_TIMEFRAMES InpTimeframe      = PERIOD_H1;          // Main Timeframe
input ENUM_TIMEFRAMES InpHTF            = PERIOD_H4;          // Higher Timeframe Filter
input bool            InpUseHTFFilter   = true;               // Use Higher TF Trend Filter
input int             InpMinConfluence  = 3;                  // Min Confluence Score (Combined)

input group "=== Trend Strategy ==="
input int             InpFastMA         = 9;                  // Fast MA Period
input int             InpSlowMA         = 21;                 // Slow MA Period
input int             InpTrendMA        = 50;                 // Trend MA Period
input int             InpMACDFast       = 12;                 // MACD Fast
input int             InpMACDSlow       = 26;                 // MACD Slow
input int             InpMACDSignal     = 9;                  // MACD Signal
input int             InpADXPeriod      = 14;                 // ADX Period
input double          InpADXThreshold   = 25.0;               // ADX Min Threshold

input group "=== Reversal Strategy ==="
input int             InpRSIPeriod      = 14;                 // RSI Period
input double          InpRSIOverbought  = 70.0;               // RSI Overbought
input double          InpRSIOversold    = 30.0;               // RSI Oversold
input int             InpBBPeriod       = 20;                 // Bollinger Period
input double          InpBBDeviation    = 2.0;                // Bollinger Deviation
input int             InpStochK         = 14;                 // Stochastic %K
input int             InpStochD         = 3;                  // Stochastic %D
input int             InpStochSlowing   = 3;                  // Stochastic Slowing

input group "=== Breakout Strategy ==="
input int             InpDonchianPeriod = 20;                 // Donchian Channel Period
input int             InpVolumePeriod   = 20;                 // Volume MA Period
input double          InpVolumeMulti    = 1.5;                // Volume Spike Multiplier
input int             InpBreakoutBars   = 3;                  // Confirm Breakout Bars

input group "=== Smart Money Strategy ==="
input int             InpOBLookback     = 50;                 // Order Block Lookback
input double          InpFVGMinSize     = 0.5;                // FVG Min Size (ATR multiple)
input int             InpStructureBars  = 20;                 // Market Structure Bars

input group "=== Risk Management ==="
input ENUM_RISK_MODE  InpRiskMode       = RISK_PERCENT;       // Risk Mode
input double          InpRiskPercent    = 1.0;                // Risk % per Trade
input double          InpFixedLot       = 0.1;                // Fixed Lot Size
input double          InpMaxLot         = 5.0;                // Maximum Lot Size
input double          InpMaxDrawdown    = 10.0;               // Max Drawdown % (pause trading)
input int             InpMaxTrades      = 3;                  // Max Concurrent Trades
input double          InpMaxDailyLoss   = 3.0;                // Max Daily Loss %
input double          InpMaxDailyProfit = 5.0;                // Max Daily Profit % (lock-in)
input bool            InpUseDailyLimits = true;               // Enable Daily Limits

input group "=== Exit Management ==="
input ENUM_EXIT_MODE  InpExitMode       = EXIT_COMBINED;      // Exit Strategy
input double          InpSLMultiplier   = 1.5;                // SL ATR Multiplier
input double          InpTPMultiplier   = 3.0;                // TP ATR Multiplier
input double          InpRiskReward     = 2.0;                // Min Risk:Reward Ratio
input double          InpTrailStart     = 1.0;                // Trail Start (ATR multiple)
input double          InpTrailStep      = 0.5;                // Trail Step (ATR multiple)
input int             InpBreakevenPips  = 20;                 // Breakeven at Pips Profit
input bool            InpUsePartialTP   = true;               // Use Partial Take Profit
input double          InpPartialPercent = 50.0;               // Partial Close %

input group "=== Session Filter ==="
input ENUM_SESSION    InpSession        = SESSION_ALL;        // Trading Session
input int             InpLondonStart    = 8;                  // London Start Hour (Server)
input int             InpLondonEnd      = 16;                 // London End Hour (Server)
input int             InpNYStart        = 13;                 // New York Start Hour (Server)
input int             InpNYEnd          = 21;                 // New York End Hour (Server)
input int             InpAsianStart     = 0;                  // Asian Start Hour (Server)
input int             InpAsianEnd       = 8;                  // Asian End Hour (Server)

input group "=== News Filter ==="
input bool            InpAvoidNews      = true;               // Avoid Trading Around News
input int             InpNewsMinutes    = 30;                 // Minutes Before/After News

input group "=== Spread & Slippage ==="
input int             InpMaxSpread      = 30;                 // Max Spread (points)
input int             InpSlippage       = 10;                 // Max Slippage (points)

input group "=== Display & Alerts ==="
input bool            InpShowDashboard  = true;               // Show Dashboard on Chart
input bool            InpSendAlerts     = true;               // Send Alert Notifications
input bool            InpPushNotify     = false;              // Push Notifications
input int             InpMagicNumber    = 202699;             // Magic Number

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade         trade;
CPositionInfo  position;
COrderInfo     order;
CSymbolInfo    symbolInfo;
CAccountInfo   accountInfo;

int            handleFastMA, handleSlowMA, handleTrendMA;
int            handleMACD, handleADX, handleRSI;
int            handleBB, handleStoch;
int            handleATR, handleATR_HTF;
int            handleVolume;

double         fastMA[], slowMA[], trendMA[];
double         macdMain[], macdSignal[], macdHist[];
double         adxMain[], adxPlus[], adxMinus[];
double         rsiValues[];
double         bbUpper[], bbMiddle[], bbLower[];
double         stochK[], stochD[];
double         atrValues[], atrHTF[];
double         volumeMA[];

double         dailyStartBalance;
double         dailyPnL;
datetime       lastBarTime;
datetime       currentDay;
int            totalTrades;
int            winTrades;
int            lossTrades;
double         totalProfit;
double         maxBalance;
double         currentDrawdown;

struct SOrderBlock
  {
   double         high;
   double         low;
   double         open;
   double         close;
   datetime       time;
   bool           isBullish;
   bool           isValid;
  };

struct SFairValueGap
  {
   double         high;
   double         low;
   datetime       time;
   bool           isBullish;
   bool           isValid;
  };

SOrderBlock    orderBlocks[];
SFairValueGap  fairValueGaps[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(!symbolInfo.Name(_Symbol))
     {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
     }

   handleFastMA  = iMA(_Symbol, InpTimeframe, InpFastMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlowMA  = iMA(_Symbol, InpTimeframe, InpSlowMA, 0, MODE_EMA, PRICE_CLOSE);
   handleTrendMA = iMA(_Symbol, InpTimeframe, InpTrendMA, 0, MODE_SMA, PRICE_CLOSE);
   handleMACD    = iMACD(_Symbol, InpTimeframe, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   handleADX     = iADX(_Symbol, InpTimeframe, InpADXPeriod);
   handleRSI     = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   handleBB      = iBands(_Symbol, InpTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   handleStoch   = iStochastic(_Symbol, InpTimeframe, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   handleATR     = iATR(_Symbol, InpTimeframe, 14);
   handleATR_HTF = iATR(_Symbol, InpHTF, 14);
   handleVolume  = iMA(_Symbol, InpTimeframe, InpVolumePeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE ||
      handleTrendMA == INVALID_HANDLE || handleMACD == INVALID_HANDLE ||
      handleADX == INVALID_HANDLE || handleRSI == INVALID_HANDLE ||
      handleBB == INVALID_HANDLE || handleStoch == INVALID_HANDLE ||
      handleATR == INVALID_HANDLE || handleATR_HTF == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
     }

   dailyStartBalance = accountInfo.Balance();
   maxBalance = dailyStartBalance;
   currentDay = iTime(_Symbol, PERIOD_D1, 0);
   lastBarTime = 0;
   totalTrades = 0;
   winTrades = 0;
   lossTrades = 0;
   totalProfit = 0;

   if(InpShowDashboard)
      CreateDashboard();

   Print("ProTrader EA v3.0 initialized on ", _Symbol,
         " | Strategy: ", EnumToString(InpStrategy),
         " | Risk: ", EnumToString(InpRiskMode));

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleFastMA);
   IndicatorRelease(handleSlowMA);
   IndicatorRelease(handleTrendMA);
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleBB);
   IndicatorRelease(handleStoch);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleATR_HTF);
   IndicatorRelease(handleVolume);

   ObjectsDeleteAll(0, "PT_");
   Print("ProTrader EA deinitialized. Total trades: ", totalTrades,
         " | Win rate: ", (totalTrades > 0 ? NormalizeDouble((double)winTrades / totalTrades * 100, 1) : 0.0), "%");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime currentBarTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentBarTime == lastBarTime)
     {
      ManageOpenPositions();
      if(InpShowDashboard)
         UpdateDashboard();
      return;
     }
   lastBarTime = currentBarTime;

   CheckNewDay();

   if(!LoadIndicatorData())
      return;

   if(!IsTradeAllowed())
      return;

   if(!CheckSpread())
      return;

   if(!IsSessionActive())
      return;

   if(IsDrawdownExceeded())
      return;

   if(InpUseDailyLimits && IsDailyLimitReached())
      return;

   int signal = GetTradeSignal();

   if(signal != 0 && CountOpenPositions() < InpMaxTrades)
     {
      ExecuteTrade(signal);
     }

   ManageOpenPositions();

   if(InpShowDashboard)
      UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| Trade transaction handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
        {
         CDealInfo deal;
         if(deal.SelectByIndex(HistoryDealsTotal() - 1))
           {
            if(deal.Magic() == InpMagicNumber && deal.Entry() == DEAL_ENTRY_OUT)
              {
               double profit = deal.Profit() + deal.Swap() + deal.Commission();
               totalProfit += profit;
               totalTrades++;
               if(profit > 0)
                  winTrades++;
               else
                  lossTrades++;
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Load all indicator buffers                                       |
//+------------------------------------------------------------------+
bool LoadIndicatorData()
  {
   int count = 100;
   if(CopyBuffer(handleFastMA, 0, 0, count, fastMA) < count)    return false;
   if(CopyBuffer(handleSlowMA, 0, 0, count, slowMA) < count)    return false;
   if(CopyBuffer(handleTrendMA, 0, 0, count, trendMA) < count)  return false;
   if(CopyBuffer(handleMACD, 0, 0, count, macdMain) < count)    return false;
   if(CopyBuffer(handleMACD, 1, 0, count, macdSignal) < count)  return false;
   if(CopyBuffer(handleADX, 0, 0, count, adxMain) < count)      return false;
   if(CopyBuffer(handleADX, 1, 0, count, adxPlus) < count)      return false;
   if(CopyBuffer(handleADX, 2, 0, count, adxMinus) < count)     return false;
   if(CopyBuffer(handleRSI, 0, 0, count, rsiValues) < count)    return false;
   if(CopyBuffer(handleBB, 0, 0, count, bbMiddle) < count)      return false;
   if(CopyBuffer(handleBB, 1, 0, count, bbUpper) < count)       return false;
   if(CopyBuffer(handleBB, 2, 0, count, bbLower) < count)       return false;
   if(CopyBuffer(handleStoch, 0, 0, count, stochK) < count)     return false;
   if(CopyBuffer(handleStoch, 1, 0, count, stochD) < count)     return false;
   if(CopyBuffer(handleATR, 0, 0, count, atrValues) < count)    return false;
   if(CopyBuffer(handleATR_HTF, 0, 0, count, atrHTF) < count)   return false;

   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(trendMA, true);
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(macdHist, true);
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlus, true);
   ArraySetAsSeries(adxMinus, true);
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbMiddle, true);
   ArraySetAsSeries(bbLower, true);
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   ArraySetAsSeries(atrValues, true);
   ArraySetAsSeries(atrHTF, true);

   return true;
  }

//+------------------------------------------------------------------+
//| Get trade signal based on selected strategy                      |
//+------------------------------------------------------------------+
int GetTradeSignal()
  {
   switch(InpStrategy)
     {
      case STRATEGY_TREND:
         return GetTrendSignal();
      case STRATEGY_REVERSAL:
         return GetReversalSignal();
      case STRATEGY_BREAKOUT:
         return GetBreakoutSignal();
      case STRATEGY_SMART:
         return GetSmartMoneySignal();
      case STRATEGY_COMBINED:
         return GetCombinedSignal();
      default:
         return 0;
     }
  }

//+------------------------------------------------------------------+
//| Trend Following Strategy                                         |
//| MA crossover + MACD confirmation + ADX strength filter           |
//+------------------------------------------------------------------+
int GetTrendSignal()
  {
   bool maCrossBuy  = fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2];
   bool maCrossSell = fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2];

   bool aboveTrendMA = iClose(_Symbol, InpTimeframe, 1) > trendMA[1];
   bool belowTrendMA = iClose(_Symbol, InpTimeframe, 1) < trendMA[1];

   bool macdBullish = macdMain[1] > macdSignal[1] && macdMain[1] > 0;
   bool macdBearish = macdMain[1] < macdSignal[1] && macdMain[1] < 0;

   bool strongTrend = adxMain[1] >= InpADXThreshold;
   bool bullishDI   = adxPlus[1] > adxMinus[1];
   bool bearishDI   = adxMinus[1] > adxPlus[1];

   if(maCrossBuy && aboveTrendMA && macdBullish && strongTrend && bullishDI)
     {
      if(!InpUseHTFFilter || IsHTFBullish())
         return 1;
     }

   if(maCrossSell && belowTrendMA && macdBearish && strongTrend && bearishDI)
     {
      if(!InpUseHTFFilter || IsHTFBearish())
         return -1;
     }

   return 0;
  }

//+------------------------------------------------------------------+
//| Mean Reversion Strategy                                          |
//| RSI extremes + Bollinger Band touch + Stochastic confirmation    |
//+------------------------------------------------------------------+
int GetReversalSignal()
  {
   double close1 = iClose(_Symbol, InpTimeframe, 1);
   double close2 = iClose(_Symbol, InpTimeframe, 2);

   bool rsiBuyZone  = rsiValues[1] < InpRSIOversold && rsiValues[2] < InpRSIOversold;
   bool rsiSellZone = rsiValues[1] > InpRSIOverbought && rsiValues[2] > InpRSIOverbought;
   bool rsiBuyTurn  = rsiValues[1] > rsiValues[2];
   bool rsiSellTurn = rsiValues[1] < rsiValues[2];

   bool touchedLowerBB = close2 <= bbLower[2];
   bool touchedUpperBB = close2 >= bbUpper[2];
   bool reboundFromLower = close1 > bbLower[1];
   bool reboundFromUpper = close1 < bbUpper[1];

   bool stochBuy  = stochK[1] < 20 && stochK[1] > stochD[1] && stochK[2] <= stochD[2];
   bool stochSell = stochK[1] > 80 && stochK[1] < stochD[1] && stochK[2] >= stochD[2];

   if((rsiBuyZone && rsiBuyTurn) && (touchedLowerBB && reboundFromLower) && stochBuy)
     {
      if(!InpUseHTFFilter || !IsHTFBearish())
         return 1;
     }

   if((rsiSellZone && rsiSellTurn) && (touchedUpperBB && reboundFromUpper) && stochSell)
     {
      if(!InpUseHTFFilter || !IsHTFBullish())
         return -1;
     }

   return 0;
  }

//+------------------------------------------------------------------+
//| Breakout Strategy                                                |
//| Donchian Channel breakout + Volume confirmation                  |
//+------------------------------------------------------------------+
int GetBreakoutSignal()
  {
   double highestHigh = 0, lowestLow = DBL_MAX;
   for(int i = 1; i <= InpDonchianPeriod; i++)
     {
      double h = iHigh(_Symbol, InpTimeframe, i);
      double l = iLow(_Symbol, InpTimeframe, i);
      if(h > highestHigh)
         highestHigh = h;
      if(l < lowestLow)
         lowestLow = l;
     }

   double close1 = iClose(_Symbol, InpTimeframe, 1);

   bool breakoutUp   = close1 > highestHigh;
   bool breakoutDown = close1 < lowestLow;

   bool volumeSpike = IsVolumeSpike();

   bool confirmedUp = true;
   bool confirmedDown = true;
   for(int i = 1; i <= InpBreakoutBars; i++)
     {
      if(iClose(_Symbol, InpTimeframe, i) <= highestHigh)
         confirmedUp = false;
      if(iClose(_Symbol, InpTimeframe, i) >= lowestLow)
         confirmedDown = false;
     }

   if(breakoutUp && volumeSpike && confirmedUp)
     {
      if(!InpUseHTFFilter || IsHTFBullish())
         return 1;
     }

   if(breakoutDown && volumeSpike && confirmedDown)
     {
      if(!InpUseHTFFilter || IsHTFBearish())
         return -1;
     }

   return 0;
  }

//+------------------------------------------------------------------+
//| Smart Money Concepts Strategy                                    |
//| Order Blocks + Fair Value Gaps + Market Structure                 |
//+------------------------------------------------------------------+
int GetSmartMoneySignal()
  {
   FindOrderBlocks();
   FindFairValueGaps();

   int structureBias = GetMarketStructure();
   double close1 = iClose(_Symbol, InpTimeframe, 1);

   for(int i = ArraySize(orderBlocks) - 1; i >= 0; i--)
     {
      if(!orderBlocks[i].isValid)
         continue;

      if(orderBlocks[i].isBullish && structureBias > 0)
        {
         if(close1 >= orderBlocks[i].low && close1 <= orderBlocks[i].high)
           {
            for(int j = ArraySize(fairValueGaps) - 1; j >= 0; j--)
              {
               if(fairValueGaps[j].isBullish && fairValueGaps[j].isValid)
                 {
                  if(close1 >= fairValueGaps[j].low && close1 <= fairValueGaps[j].high)
                     return 1;
                 }
              }
            if(rsiValues[1] < 40)
               return 1;
           }
        }

      if(!orderBlocks[i].isBullish && structureBias < 0)
        {
         if(close1 >= orderBlocks[i].low && close1 <= orderBlocks[i].high)
           {
            for(int j = ArraySize(fairValueGaps) - 1; j >= 0; j--)
              {
               if(!fairValueGaps[j].isBullish && fairValueGaps[j].isValid)
                 {
                  if(close1 >= fairValueGaps[j].low && close1 <= fairValueGaps[j].high)
                     return -1;
                 }
              }
            if(rsiValues[1] > 60)
               return -1;
           }
        }
     }

   return 0;
  }

//+------------------------------------------------------------------+
//| Combined Strategy - Confluence Scoring                           |
//+------------------------------------------------------------------+
int GetCombinedSignal()
  {
   int bullScore = 0;
   int bearScore = 0;

   // 1) MA alignment
   if(fastMA[1] > slowMA[1] && iClose(_Symbol, InpTimeframe, 1) > trendMA[1])
      bullScore++;
   if(fastMA[1] < slowMA[1] && iClose(_Symbol, InpTimeframe, 1) < trendMA[1])
      bearScore++;

   // 2) MACD
   if(macdMain[1] > macdSignal[1] && macdMain[1] > 0)
      bullScore++;
   if(macdMain[1] < macdSignal[1] && macdMain[1] < 0)
      bearScore++;

   // 3) ADX trend strength
   if(adxMain[1] >= InpADXThreshold && adxPlus[1] > adxMinus[1])
      bullScore++;
   if(adxMain[1] >= InpADXThreshold && adxMinus[1] > adxPlus[1])
      bearScore++;

   // 4) RSI
   if(rsiValues[1] > 50 && rsiValues[1] < InpRSIOverbought)
      bullScore++;
   if(rsiValues[1] < 50 && rsiValues[1] > InpRSIOversold)
      bearScore++;

   // 5) Bollinger Band position
   double close1 = iClose(_Symbol, InpTimeframe, 1);
   if(close1 > bbMiddle[1] && close1 < bbUpper[1])
      bullScore++;
   if(close1 < bbMiddle[1] && close1 > bbLower[1])
      bearScore++;

   // 6) Higher timeframe
   if(InpUseHTFFilter)
     {
      if(IsHTFBullish())
         bullScore++;
      if(IsHTFBearish())
         bearScore++;
     }

   // 7) Market structure
   int structure = GetMarketStructure();
   if(structure > 0) bullScore++;
   if(structure < 0) bearScore++;

   if(bullScore >= InpMinConfluence && bullScore > bearScore)
      return 1;
   if(bearScore >= InpMinConfluence && bearScore > bullScore)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//| Execute trade with full risk management                          |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
  {
   symbolInfo.RefreshRates();

   double atr = atrValues[1];
   if(atr <= 0)
      return;

   double point = symbolInfo.Point();
   int digits   = symbolInfo.Digits();
   double ask   = symbolInfo.Ask();
   double bid   = symbolInfo.Bid();

   double sl = 0, tp = 0, entryPrice = 0;
   double slDistance = atr * InpSLMultiplier;
   double tpDistance = atr * InpTPMultiplier;

   if(tpDistance / slDistance < InpRiskReward)
      tpDistance = slDistance * InpRiskReward;

   if(signal > 0)
     {
      entryPrice = ask;
      sl = NormalizeDouble(entryPrice - slDistance, digits);
      tp = NormalizeDouble(entryPrice + tpDistance, digits);
     }
   else if(signal < 0)
     {
      entryPrice = bid;
      sl = NormalizeDouble(entryPrice + slDistance, digits);
      tp = NormalizeDouble(entryPrice - tpDistance, digits);
     }

   double lotSize = CalculateLotSize(slDistance);
   if(lotSize <= 0)
      return;

   string comment = StringFormat("PT_%s_%d", EnumToString(InpStrategy), InpMagicNumber);

   bool result = false;
   if(signal > 0)
      result = trade.Buy(lotSize, _Symbol, ask, sl, tp, comment);
   else if(signal < 0)
      result = trade.Sell(lotSize, _Symbol, bid, sl, tp, comment);

   if(result)
     {
      string direction = signal > 0 ? "BUY" : "SELL";
      Print(StringFormat("Trade opened: %s %.2f lots at %.5f | SL: %.5f | TP: %.5f | ATR: %.5f",
                         direction, lotSize, entryPrice, sl, tp, atr));

      if(InpSendAlerts)
         Alert(StringFormat("ProTrader EA: %s %s %.2f lots", direction, _Symbol, lotSize));

      if(InpPushNotify)
         SendNotification(StringFormat("ProTrader EA: %s %s %.2f lots at %.5f",
                                       direction, _Symbol, lotSize, entryPrice));
     }
   else
     {
      Print("Trade failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on risk mode                            |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
  {
   double lotSize = InpFixedLot;
   double balance = accountInfo.Balance();
   double tickValue = symbolInfo.TickValue();
   double tickSize  = symbolInfo.TickSize();
   double minLot    = symbolInfo.LotsMin();
   double maxLot    = MathMin(symbolInfo.LotsMax(), InpMaxLot);
   double lotStep   = symbolInfo.LotsStep();

   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0)
      return minLot;

   switch(InpRiskMode)
     {
      case RISK_PERCENT:
        {
         double riskMoney = balance * InpRiskPercent / 100.0;
         double slPoints  = slDistance / tickSize;
         lotSize = riskMoney / (slPoints * tickValue);
         break;
        }
      case RISK_KELLY:
        {
         double winRate = totalTrades > 20 ? (double)winTrades / totalTrades : 0.5;
         double avgWin  = totalTrades > 20 && winTrades > 0 ? totalProfit / winTrades : 1.0;
         double avgLoss = totalTrades > 20 && lossTrades > 0 ? MathAbs(totalProfit) / lossTrades : 1.0;
         double kellyPercent = winRate - (1.0 - winRate) / (avgWin / avgLoss);
         kellyPercent = MathMax(0.01, MathMin(kellyPercent * 0.5, 0.05));
         double riskMoney = balance * kellyPercent;
         double slPoints  = slDistance / tickSize;
         lotSize = riskMoney / (slPoints * tickValue);
         break;
        }
      case RISK_MARTINGALE:
        {
         double riskMoney = balance * InpRiskPercent / 100.0;
         double slPoints  = slDistance / tickSize;
         lotSize = riskMoney / (slPoints * tickValue);

         if(totalTrades > 0)
           {
            CDealInfo deal;
            if(HistorySelect(0, TimeCurrent()))
              {
               for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
                 {
                  if(deal.SelectByIndex(i) && deal.Magic() == InpMagicNumber && deal.Entry() == DEAL_ENTRY_OUT)
                    {
                     if(deal.Profit() > 0)
                        lotSize *= 1.5;
                     else
                        lotSize *= 0.75;
                     break;
                    }
                 }
              }
           }
         break;
        }
      case RISK_FIXED_LOT:
      default:
         lotSize = InpFixedLot;
         break;
     }

   lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = NormalizeDouble(lotSize, 2);

   return lotSize;
  }

//+------------------------------------------------------------------+
//| Manage open positions - trailing, breakeven, partial TP          |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber)
         continue;
      if(position.Symbol() != _Symbol)
         continue;

      double atr = atrValues[1];
      if(atr <= 0)
         continue;

      switch(InpExitMode)
        {
         case EXIT_TRAILING:
            ApplyTrailingStop(atr);
            break;
         case EXIT_ATR_BASED:
            ApplyATRDynamicExit(atr);
            break;
         case EXIT_CHANDELIER:
            ApplyChandelierExit(atr);
            break;
         case EXIT_COMBINED:
            ApplyBreakeven();
            ApplyTrailingStop(atr);
            if(InpUsePartialTP)
               ApplyPartialTP(atr);
            break;
         case EXIT_SL_TP:
         default:
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Apply trailing stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(double atr)
  {
   double trailStartDist = atr * InpTrailStart;
   double trailStepDist  = atr * InpTrailStep;
   int    digits = symbolInfo.Digits();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber || position.Symbol() != _Symbol)
         continue;

      double openPrice = position.PriceOpen();
      double currentSL = position.StopLoss();
      double profit    = position.Profit();

      if(position.PositionType() == POSITION_TYPE_BUY)
        {
         double currentPrice = symbolInfo.Bid();
         if(currentPrice - openPrice >= trailStartDist)
           {
            double newSL = NormalizeDouble(currentPrice - trailStepDist, digits);
            if(newSL > currentSL + symbolInfo.Point())
              {
               trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
              }
           }
        }
      else if(position.PositionType() == POSITION_TYPE_SELL)
        {
         double currentPrice = symbolInfo.Ask();
         if(openPrice - currentPrice >= trailStartDist)
           {
            double newSL = NormalizeDouble(currentPrice + trailStepDist, digits);
            if(newSL < currentSL - symbolInfo.Point() || currentSL == 0)
              {
               trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Apply breakeven stop                                             |
//+------------------------------------------------------------------+
void ApplyBreakeven()
  {
   double beDistance = InpBreakevenPips * symbolInfo.Point();
   int    digits    = symbolInfo.Digits();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber || position.Symbol() != _Symbol)
         continue;

      double openPrice = position.PriceOpen();
      double currentSL = position.StopLoss();

      if(position.PositionType() == POSITION_TYPE_BUY)
        {
         double currentPrice = symbolInfo.Bid();
         if(currentPrice - openPrice >= beDistance)
           {
            double newSL = NormalizeDouble(openPrice + symbolInfo.Point(), digits);
            if(newSL > currentSL)
               trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
           }
        }
      else if(position.PositionType() == POSITION_TYPE_SELL)
        {
         double currentPrice = symbolInfo.Ask();
         if(openPrice - currentPrice >= beDistance)
           {
            double newSL = NormalizeDouble(openPrice - symbolInfo.Point(), digits);
            if(newSL < currentSL || currentSL == 0)
               trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Apply ATR-based dynamic exit                                     |
//+------------------------------------------------------------------+
void ApplyATRDynamicExit(double atr)
  {
   int digits = symbolInfo.Digits();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber || position.Symbol() != _Symbol)
         continue;

      if(position.PositionType() == POSITION_TYPE_BUY)
        {
         double newSL = NormalizeDouble(symbolInfo.Bid() - atr * 2.0, digits);
         double newTP = NormalizeDouble(symbolInfo.Ask() + atr * 3.0, digits);
         if(newSL > position.StopLoss())
            trade.PositionModify(position.Ticket(), newSL, newTP);
        }
      else
        {
         double newSL = NormalizeDouble(symbolInfo.Ask() + atr * 2.0, digits);
         double newTP = NormalizeDouble(symbolInfo.Bid() - atr * 3.0, digits);
         if(newSL < position.StopLoss() || position.StopLoss() == 0)
            trade.PositionModify(position.Ticket(), newSL, newTP);
        }
     }
  }

//+------------------------------------------------------------------+
//| Apply Chandelier Exit                                            |
//+------------------------------------------------------------------+
void ApplyChandelierExit(double atr)
  {
   int digits = symbolInfo.Digits();
   int lookback = 22;

   double highestHigh = 0, lowestLow = DBL_MAX;
   for(int j = 1; j <= lookback; j++)
     {
      double h = iHigh(_Symbol, InpTimeframe, j);
      double l = iLow(_Symbol, InpTimeframe, j);
      if(h > highestHigh) highestHigh = h;
      if(l < lowestLow)   lowestLow = l;
     }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber || position.Symbol() != _Symbol)
         continue;

      if(position.PositionType() == POSITION_TYPE_BUY)
        {
         double chandSL = NormalizeDouble(highestHigh - atr * 3.0, digits);
         if(chandSL > position.StopLoss())
            trade.PositionModify(position.Ticket(), chandSL, position.TakeProfit());
        }
      else
        {
         double chandSL = NormalizeDouble(lowestLow + atr * 3.0, digits);
         if(chandSL < position.StopLoss() || position.StopLoss() == 0)
            trade.PositionModify(position.Ticket(), chandSL, position.TakeProfit());
        }
     }
  }

//+------------------------------------------------------------------+
//| Partial take profit                                              |
//+------------------------------------------------------------------+
void ApplyPartialTP(double atr)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!position.SelectByIndex(i))
         continue;
      if(position.Magic() != InpMagicNumber || position.Symbol() != _Symbol)
         continue;

      double openPrice = position.PriceOpen();
      double volume    = position.Volume();

      double partialDist = atr * InpTPMultiplier * 0.5;

      if(volume <= symbolInfo.LotsMin())
         continue;

      if(position.PositionType() == POSITION_TYPE_BUY)
        {
         if(symbolInfo.Bid() - openPrice >= partialDist)
           {
            double closeVol = NormalizeDouble(volume * InpPartialPercent / 100.0, 2);
            closeVol = MathMax(closeVol, symbolInfo.LotsMin());
            closeVol = MathMin(closeVol, volume - symbolInfo.LotsMin());
            if(closeVol > 0)
               trade.PositionClosePartial(position.Ticket(), closeVol);
           }
        }
      else if(position.PositionType() == POSITION_TYPE_SELL)
        {
         if(openPrice - symbolInfo.Ask() >= partialDist)
           {
            double closeVol = NormalizeDouble(volume * InpPartialPercent / 100.0, 2);
            closeVol = MathMax(closeVol, symbolInfo.LotsMin());
            closeVol = MathMin(closeVol, volume - symbolInfo.LotsMin());
            if(closeVol > 0)
               trade.PositionClosePartial(position.Ticket(), closeVol);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Higher Timeframe Trend Analysis                                  |
//+------------------------------------------------------------------+
bool IsHTFBullish()
  {
   int htfFastMA = iMA(_Symbol, InpHTF, InpFastMA, 0, MODE_EMA, PRICE_CLOSE);
   int htfSlowMA = iMA(_Symbol, InpHTF, InpSlowMA, 0, MODE_EMA, PRICE_CLOSE);

   double htfFast[3], htfSlow[3];
   if(CopyBuffer(htfFastMA, 0, 0, 3, htfFast) < 3) return false;
   if(CopyBuffer(htfSlowMA, 0, 0, 3, htfSlow) < 3) return false;
   ArraySetAsSeries(htfFast, true);
   ArraySetAsSeries(htfSlow, true);

   IndicatorRelease(htfFastMA);
   IndicatorRelease(htfSlowMA);

   return htfFast[1] > htfSlow[1];
  }

bool IsHTFBearish()
  {
   int htfFastMA = iMA(_Symbol, InpHTF, InpFastMA, 0, MODE_EMA, PRICE_CLOSE);
   int htfSlowMA = iMA(_Symbol, InpHTF, InpSlowMA, 0, MODE_EMA, PRICE_CLOSE);

   double htfFast[3], htfSlow[3];
   if(CopyBuffer(htfFastMA, 0, 0, 3, htfFast) < 3) return false;
   if(CopyBuffer(htfSlowMA, 0, 0, 3, htfSlow) < 3) return false;
   ArraySetAsSeries(htfFast, true);
   ArraySetAsSeries(htfSlow, true);

   IndicatorRelease(htfFastMA);
   IndicatorRelease(htfSlowMA);

   return htfFast[1] < htfSlow[1];
  }

//+------------------------------------------------------------------+
//| Volume spike detection                                           |
//+------------------------------------------------------------------+
bool IsVolumeSpike()
  {
   long currentVol = iVolume(_Symbol, InpTimeframe, 1);

   double sumVol = 0;
   for(int i = 2; i <= InpVolumePeriod + 1; i++)
      sumVol += (double)iVolume(_Symbol, InpTimeframe, i);
   double avgVol = sumVol / InpVolumePeriod;

   return (double)currentVol > avgVol * InpVolumeMulti;
  }

//+------------------------------------------------------------------+
//| Find Order Blocks (Smart Money)                                  |
//+------------------------------------------------------------------+
void FindOrderBlocks()
  {
   ArrayResize(orderBlocks, 0);

   for(int i = 3; i < InpOBLookback; i++)
     {
      double open_i  = iOpen(_Symbol, InpTimeframe, i);
      double close_i = iClose(_Symbol, InpTimeframe, i);
      double high_i  = iHigh(_Symbol, InpTimeframe, i);
      double low_i   = iLow(_Symbol, InpTimeframe, i);

      bool bearishCandle = close_i < open_i;
      bool bullishCandle = close_i > open_i;

      // Bullish OB: last bearish candle before a strong move up
      if(bearishCandle)
        {
         bool strongMoveUp = true;
         for(int j = i - 1; j >= i - 2 && j >= 1; j--)
           {
            if(iClose(_Symbol, InpTimeframe, j) <= iClose(_Symbol, InpTimeframe, j + 1))
              {
               strongMoveUp = false;
               break;
              }
           }
         if(strongMoveUp && iClose(_Symbol, InpTimeframe, i - 2) > high_i)
           {
            SOrderBlock ob;
            ob.high = high_i;
            ob.low  = low_i;
            ob.open = open_i;
            ob.close = close_i;
            ob.time = iTime(_Symbol, InpTimeframe, i);
            ob.isBullish = true;
            ob.isValid = true;
            int size = ArraySize(orderBlocks);
            ArrayResize(orderBlocks, size + 1);
            orderBlocks[size] = ob;
           }
        }

      // Bearish OB: last bullish candle before a strong move down
      if(bullishCandle)
        {
         bool strongMoveDown = true;
         for(int j = i - 1; j >= i - 2 && j >= 1; j--)
           {
            if(iClose(_Symbol, InpTimeframe, j) >= iClose(_Symbol, InpTimeframe, j + 1))
              {
               strongMoveDown = false;
               break;
              }
           }
         if(strongMoveDown && iClose(_Symbol, InpTimeframe, i - 2) < low_i)
           {
            SOrderBlock ob;
            ob.high = high_i;
            ob.low  = low_i;
            ob.open = open_i;
            ob.close = close_i;
            ob.time = iTime(_Symbol, InpTimeframe, i);
            ob.isBullish = false;
            ob.isValid = true;
            int size = ArraySize(orderBlocks);
            ArrayResize(orderBlocks, size + 1);
            orderBlocks[size] = ob;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Find Fair Value Gaps (Smart Money)                               |
//+------------------------------------------------------------------+
void FindFairValueGaps()
  {
   ArrayResize(fairValueGaps, 0);
   double atr = atrValues[1];
   double minGap = atr * InpFVGMinSize;

   for(int i = 2; i < InpOBLookback; i++)
     {
      double high_prev = iHigh(_Symbol, InpTimeframe, i + 1);
      double low_next  = iLow(_Symbol, InpTimeframe, i - 1);
      double high_next = iHigh(_Symbol, InpTimeframe, i - 1);
      double low_prev  = iLow(_Symbol, InpTimeframe, i + 1);

      // Bullish FVG
      if(low_next > high_prev && (low_next - high_prev) >= minGap)
        {
         SFairValueGap fvg;
         fvg.high = low_next;
         fvg.low  = high_prev;
         fvg.time = iTime(_Symbol, InpTimeframe, i);
         fvg.isBullish = true;
         fvg.isValid = true;
         int size = ArraySize(fairValueGaps);
         ArrayResize(fairValueGaps, size + 1);
         fairValueGaps[size] = fvg;
        }

      // Bearish FVG
      if(high_next < low_prev && (low_prev - high_next) >= minGap)
        {
         SFairValueGap fvg;
         fvg.high = low_prev;
         fvg.low  = high_next;
         fvg.time = iTime(_Symbol, InpTimeframe, i);
         fvg.isBullish = false;
         fvg.isValid = true;
         int size = ArraySize(fairValueGaps);
         ArrayResize(fairValueGaps, size + 1);
         fairValueGaps[size] = fvg;
        }
     }
  }

//+------------------------------------------------------------------+
//| Market Structure Analysis (Higher Highs / Lower Lows)           |
//+------------------------------------------------------------------+
int GetMarketStructure()
  {
   int hhCount = 0, llCount = 0;
   double prevHigh = 0, prevLow = DBL_MAX;

   for(int i = InpStructureBars; i >= 2; i--)
     {
      double high_i = iHigh(_Symbol, InpTimeframe, i);
      double low_i  = iLow(_Symbol, InpTimeframe, i);

      bool isSwingHigh = true;
      bool isSwingLow  = true;

      for(int j = 1; j <= 2; j++)
        {
         if(i + j < InpStructureBars)
           {
            if(iHigh(_Symbol, InpTimeframe, i + j) >= high_i) isSwingHigh = false;
            if(iLow(_Symbol, InpTimeframe, i + j) <= low_i)   isSwingLow = false;
           }
         if(i - j >= 1)
           {
            if(iHigh(_Symbol, InpTimeframe, i - j) >= high_i) isSwingHigh = false;
            if(iLow(_Symbol, InpTimeframe, i - j) <= low_i)   isSwingLow = false;
           }
        }

      if(isSwingHigh)
        {
         if(prevHigh > 0 && high_i > prevHigh) hhCount++;
         prevHigh = high_i;
        }
      if(isSwingLow)
        {
         if(prevLow < DBL_MAX && low_i < prevLow) llCount++;
         prevLow = low_i;
        }
     }

   if(hhCount >= 2 && hhCount > llCount) return 1;   // Bullish structure
   if(llCount >= 2 && llCount > hhCount) return -1;   // Bearish structure
   return 0;
  }

//+------------------------------------------------------------------+
//| Session time filter                                              |
//+------------------------------------------------------------------+
bool IsSessionActive()
  {
   if(InpSession == SESSION_ALL)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   switch(InpSession)
     {
      case SESSION_LONDON:
         return (hour >= InpLondonStart && hour < InpLondonEnd);
      case SESSION_NEWYORK:
         return (hour >= InpNYStart && hour < InpNYEnd);
      case SESSION_OVERLAP:
         return (hour >= InpNYStart && hour < InpLondonEnd);
      case SESSION_ASIAN:
         return (hour >= InpAsianStart && hour < InpAsianEnd);
      default:
         return true;
     }
  }

//+------------------------------------------------------------------+
//| Check spread filter                                              |
//+------------------------------------------------------------------+
bool CheckSpread()
  {
   symbolInfo.RefreshRates();
   int spread = (int)symbolInfo.Spread();
   return spread <= InpMaxSpread;
  }

//+------------------------------------------------------------------+
//| Check drawdown limit                                             |
//+------------------------------------------------------------------+
bool IsDrawdownExceeded()
  {
   double balance = accountInfo.Balance();
   double equity  = accountInfo.Equity();

   if(balance > maxBalance)
      maxBalance = balance;

   currentDrawdown = (maxBalance - equity) / maxBalance * 100.0;

   if(currentDrawdown >= InpMaxDrawdown)
     {
      Print("Trading paused: Drawdown ", DoubleToString(currentDrawdown, 1),
            "% exceeds limit ", DoubleToString(InpMaxDrawdown, 1), "%");
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Check daily P&L limits                                           |
//+------------------------------------------------------------------+
bool IsDailyLimitReached()
  {
   double balance = accountInfo.Balance();
   dailyPnL = (balance - dailyStartBalance) / dailyStartBalance * 100.0;

   if(dailyPnL <= -InpMaxDailyLoss)
     {
      Print("Daily loss limit reached: ", DoubleToString(dailyPnL, 2), "%");
      return true;
     }

   if(dailyPnL >= InpMaxDailyProfit)
     {
      Print("Daily profit target reached: ", DoubleToString(dailyPnL, 2), "%");
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check for new trading day                                        |
//+------------------------------------------------------------------+
void CheckNewDay()
  {
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(today != currentDay)
     {
      currentDay = today;
      dailyStartBalance = accountInfo.Balance();
      dailyPnL = 0;
      Print("New trading day: ", TimeToString(today, TIME_DATE));
     }
  }

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
  {
   return MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
  }

//+------------------------------------------------------------------+
//| Count open positions with our magic number                       |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(position.SelectByIndex(i))
        {
         if(position.Magic() == InpMagicNumber && position.Symbol() == _Symbol)
            count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Dashboard display functions                                      |
//+------------------------------------------------------------------+
void CreateDashboard()
  {
   int x = 10, y = 30, w = 280, h = 360;

   ObjectCreate(0, "PT_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PT_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "PT_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "PT_BG", OBJPROP_XSIZE, w);
   ObjectSetInteger(0, "PT_BG", OBJPROP_YSIZE, h);
   ObjectSetInteger(0, "PT_BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, "PT_BG", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "PT_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, "PT_BG", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "PT_BG", OBJPROP_BACK, false);
   ObjectSetInteger(0, "PT_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   CreateLabel("PT_Title", x + 10, y + 5, "ProTrader EA v3.0", clrGold, 12);
   CreateLabel("PT_Sep1",  x + 10, y + 25, "================================", clrDodgerBlue, 8);

   CreateLabel("PT_Strategy",  x + 10, y + 40,  "Strategy: ---", clrWhite, 9);
   CreateLabel("PT_Symbol",    x + 10, y + 58,  "Symbol: ---", clrWhite, 9);
   CreateLabel("PT_Spread",    x + 10, y + 76,  "Spread: ---", clrWhite, 9);
   CreateLabel("PT_ATR",       x + 10, y + 94,  "ATR: ---", clrWhite, 9);
   CreateLabel("PT_Sep2",      x + 10, y + 112, "================================", clrDodgerBlue, 8);

   CreateLabel("PT_Balance",   x + 10, y + 127, "Balance: ---", clrWhite, 9);
   CreateLabel("PT_Equity",    x + 10, y + 145, "Equity: ---", clrWhite, 9);
   CreateLabel("PT_DailyPnL",  x + 10, y + 163, "Daily P&L: ---", clrWhite, 9);
   CreateLabel("PT_Drawdown",  x + 10, y + 181, "Drawdown: ---", clrWhite, 9);
   CreateLabel("PT_Sep3",      x + 10, y + 199, "================================", clrDodgerBlue, 8);

   CreateLabel("PT_Trades",    x + 10, y + 214, "Total Trades: 0", clrWhite, 9);
   CreateLabel("PT_WinRate",   x + 10, y + 232, "Win Rate: 0%", clrWhite, 9);
   CreateLabel("PT_Profit",    x + 10, y + 250, "Total Profit: $0", clrWhite, 9);
   CreateLabel("PT_OpenPos",   x + 10, y + 268, "Open Positions: 0", clrWhite, 9);
   CreateLabel("PT_Sep4",      x + 10, y + 286, "================================", clrDodgerBlue, 8);

   CreateLabel("PT_Signal",    x + 10, y + 301, "Signal: WAITING", clrYellow, 10);
   CreateLabel("PT_Session",   x + 10, y + 321, "Session: ---", clrWhite, 9);
   CreateLabel("PT_Status",    x + 10, y + 339, "Status: ACTIVE", clrLime, 9);
  }

void CreateLabel(string name, int x, int y, string text, color clr, int fontSize)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  }

void UpdateDashboard()
  {
   if(!InpShowDashboard)
      return;

   symbolInfo.RefreshRates();

   ObjectSetString(0, "PT_Strategy", OBJPROP_TEXT,
                   "Strategy: " + EnumToString(InpStrategy));
   ObjectSetString(0, "PT_Symbol", OBJPROP_TEXT,
                   "Symbol: " + _Symbol + " | TF: " + EnumToString(InpTimeframe));
   ObjectSetString(0, "PT_Spread", OBJPROP_TEXT,
                   StringFormat("Spread: %d pts (max: %d)", (int)symbolInfo.Spread(), InpMaxSpread));

   if(ArraySize(atrValues) > 1)
      ObjectSetString(0, "PT_ATR", OBJPROP_TEXT,
                      StringFormat("ATR(14): %.5f", atrValues[1]));

   double balance = accountInfo.Balance();
   double equity  = accountInfo.Equity();

   ObjectSetString(0, "PT_Balance", OBJPROP_TEXT,
                   StringFormat("Balance: $%.2f", balance));
   ObjectSetString(0, "PT_Equity", OBJPROP_TEXT,
                   StringFormat("Equity:  $%.2f", equity));

   color pnlColor = dailyPnL >= 0 ? clrLime : clrRed;
   ObjectSetString(0, "PT_DailyPnL", OBJPROP_TEXT,
                   StringFormat("Daily P&L: %.2f%%", dailyPnL));
   ObjectSetInteger(0, "PT_DailyPnL", OBJPROP_COLOR, pnlColor);

   color ddColor = currentDrawdown < InpMaxDrawdown * 0.7 ? clrLime :
                   currentDrawdown < InpMaxDrawdown ? clrYellow : clrRed;
   ObjectSetString(0, "PT_Drawdown", OBJPROP_TEXT,
                   StringFormat("Drawdown: %.1f%% / %.1f%%", currentDrawdown, InpMaxDrawdown));
   ObjectSetInteger(0, "PT_Drawdown", OBJPROP_COLOR, ddColor);

   ObjectSetString(0, "PT_Trades", OBJPROP_TEXT,
                   StringFormat("Total Trades: %d", totalTrades));

   double winRate = totalTrades > 0 ? (double)winTrades / totalTrades * 100.0 : 0.0;
   ObjectSetString(0, "PT_WinRate", OBJPROP_TEXT,
                   StringFormat("Win Rate: %.1f%% (%d/%d)", winRate, winTrades, totalTrades));
   ObjectSetInteger(0, "PT_WinRate", OBJPROP_COLOR, winRate >= 50 ? clrLime : clrOrange);

   ObjectSetString(0, "PT_Profit", OBJPROP_TEXT,
                   StringFormat("Total Profit: $%.2f", totalProfit));
   ObjectSetInteger(0, "PT_Profit", OBJPROP_COLOR, totalProfit >= 0 ? clrLime : clrRed);

   int openPos = CountOpenPositions();
   ObjectSetString(0, "PT_OpenPos", OBJPROP_TEXT,
                   StringFormat("Open Positions: %d / %d", openPos, InpMaxTrades));

   ObjectSetString(0, "PT_Session", OBJPROP_TEXT,
                   "Session: " + GetSessionName());

   string statusText = "Status: ACTIVE";
   color statusColor = clrLime;
   if(IsDrawdownExceeded())
     {
      statusText = "Status: PAUSED (DD)";
      statusColor = clrRed;
     }
   else if(InpUseDailyLimits && IsDailyLimitReached())
     {
      statusText = "Status: DAILY LIMIT";
      statusColor = clrYellow;
     }
   else if(!IsSessionActive())
     {
      statusText = "Status: OFF SESSION";
      statusColor = clrGray;
     }
   ObjectSetString(0, "PT_Status", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "PT_Status", OBJPROP_COLOR, statusColor);

   ChartRedraw(0);
  }

string GetSessionName()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   if(hour >= InpLondonStart && hour < InpLondonEnd && hour >= InpNYStart)
      return "London-NY Overlap";
   if(hour >= InpLondonStart && hour < InpLondonEnd)
      return "London";
   if(hour >= InpNYStart && hour < InpNYEnd)
      return "New York";
   if(hour >= InpAsianStart && hour < InpAsianEnd)
      return "Asian";

   return "Off-Hours";
  }
//+------------------------------------------------------------------+
