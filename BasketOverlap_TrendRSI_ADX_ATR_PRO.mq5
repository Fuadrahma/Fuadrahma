//+------------------------------------------------------------------+
//|              BasketOverlap_TrendRSI_ADX_ATR_PRO.mq5             |
//|        Trend-filtered safe basket EA with RSI/ADX/ATR logic      |
//+------------------------------------------------------------------+
#property strict
#property version   "6.00"

#include <Trade/Trade.mqh>

CTrade trade;

//--------------------------------------------------
// INPUTS
//--------------------------------------------------
input group "--- RISK SETTINGS ---"
input double InpLotSize                = 0.01;     // Fixed lot size
input int    InpMaxPositions           = 3;        // Maximum positions per symbol/magic
input double InpBasketTargetProfit     = 1.50;     // Basket close target in account currency
input double InpMaxBasketFloatingLoss  = 6.00;     // Emergency floating loss close in account currency
input double InpMaxDailyLoss           = 5.00;     // Stop trading for the day after this closed loss
input ulong  InpMagicNumber            = 777111;   // EA magic number

input group "--- TREND & ENTRY SETTINGS ---"
input int    InpFastEMA_Period         = 50;       // Pullback EMA
input int    InpSlowEMA_Period         = 200;      // Main trend EMA
input int    InpRSI_Period             = 14;       // RSI period
input double InpRSI_BuyLevel           = 50.0;     // Buy confirmation level
input double InpRSI_SellLevel          = 50.0;     // Sell confirmation level
input int    InpADX_Period             = 14;       // ADX period
input double InpMinADX                 = 20.0;     // Minimum trend strength
input int    InpATR_Period             = 14;       // ATR period
input double InpMaxPullbackATR         = 0.75;     // Max distance from EMA50 in ATR units

input group "--- SAFETY FILTERS ---"
input double InpMaxSpreadPoints        = 30;       // Maximum spread in points
input bool   InpUseATRStopLoss         = true;     // Use ATR stop loss
input double InpATRStopMultiplier      = 1.5;      // SL = ATR * multiplier
input bool   InpUseATRTakeProfit       = false;    // Use ATR take profit
input double InpATRTakeMultiplier      = 2.0;      // TP = ATR * multiplier
input int    InpDeviationPoints        = 20;       // Allowed slippage/deviation

input group "--- TRADE SETTINGS ---"
input bool   InpOneTradePerBar         = true;     // One successful entry per candle
input bool   InpOneBasketDirection     = true;     // Do not mix buy and sell baskets

//--------------------------------------------------
// GLOBAL VARIABLES
//--------------------------------------------------
int rsiHandle     = INVALID_HANDLE;
int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int adxHandle     = INVALID_HANDLE;
int atrHandle     = INVALID_HANDLE;

double rsiBuffer[];
double fastEmaBuffer[];
double slowEmaBuffer[];
double adxBuffer[];
double atrBuffer[];

datetime lastTradeBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   rsiHandle = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
   fastEmaHandle = iMA(_Symbol, _Period, InpFastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(_Symbol, _Period, InpSlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, InpADX_Period);
   atrHandle = iATR(_Symbol, _Period, InpATR_Period);

   if(rsiHandle == INVALID_HANDLE ||
      fastEmaHandle == INVALID_HANDLE ||
      slowEmaHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create one or more indicator handles.");
      return INIT_FAILED;
   }

   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(fastEmaBuffer, true);
   ArraySetAsSeries(slowEmaBuffer, true);
   ArraySetAsSeries(adxBuffer, true);
   ArraySetAsSeries(atrBuffer, true);

   Print("Trend RSI ADX ATR basket EA initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   const double dailyPL = CalculateDailyProfitLoss();
   if(dailyPL <= -InpMaxDailyLoss)
   {
      Comment("DAILY LOSS LIMIT HIT\nTrading paused until next server day.");
      return;
   }

   const double spread = GetSpreadPoints();
   if(spread > InpMaxSpreadPoints)
   {
      Comment("Spread too high: ", DoubleToString(spread, 1), " pts");
      return;
   }

   if(!RefreshIndicators())
      return;

   const double basketProfit = CalculateBasketProfit();
   if(ManageBasketRisk(basketProfit))
      return;

   const int currentPositions = CountPositions();
   Comment(
      "TREND RSI ADX ATR EA\n",
      "Positions: ", currentPositions, " / ", InpMaxPositions, "\n",
      "Basket P/L: ", DoubleToString(basketProfit, 2), "\n",
      "Daily P/L: ", DoubleToString(dailyPL, 2), "\n",
      "Spread: ", DoubleToString(spread, 1), " pts\n",
      "ADX: ", DoubleToString(adxBuffer[1], 1)
   );

   if(currentPositions >= InpMaxPositions)
      return;

   const datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(InpOneTradePerBar && currentBarTime == lastTradeBarTime)
      return;

   const bool buySignal = IsBuySignal();
   const bool sellSignal = IsSellSignal();

   if(buySignal && (!InpOneBasketDirection || !HasPositionType(POSITION_TYPE_SELL)))
   {
      if(OpenBuy())
         lastTradeBarTime = currentBarTime;
      return;
   }

   if(sellSignal && (!InpOneBasketDirection || !HasPositionType(POSITION_TYPE_BUY)))
   {
      if(OpenSell())
         lastTradeBarTime = currentBarTime;
   }
}

//+------------------------------------------------------------------+
//| Validate EA inputs                                               |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(InpLotSize <= 0 ||
      InpMaxPositions <= 0 ||
      InpFastEMA_Period <= 1 ||
      InpSlowEMA_Period <= InpFastEMA_Period ||
      InpRSI_Period <= 1 ||
      InpADX_Period <= 1 ||
      InpATR_Period <= 1 ||
      InpATRStopMultiplier <= 0 ||
      InpATRTakeMultiplier <= 0 ||
      InpMaxPullbackATR <= 0)
   {
      Print("Invalid input settings.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Refresh indicators                                               |
//+------------------------------------------------------------------+
bool RefreshIndicators()
{
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3)
      return false;
   if(CopyBuffer(fastEmaHandle, 0, 0, 3, fastEmaBuffer) < 3)
      return false;
   if(CopyBuffer(slowEmaHandle, 0, 0, 3, slowEmaBuffer) < 3)
      return false;
   if(CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) < 3)
      return false;
   if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) < 3)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Buy setup                                                        |
//+------------------------------------------------------------------+
bool IsBuySignal()
{
   const double close1 = iClose(_Symbol, _Period, 1);
   const bool trendUp = close1 > slowEmaBuffer[1] &&
                        fastEmaBuffer[1] > slowEmaBuffer[1];
   const bool pullbackNearEma = MathAbs(close1 - fastEmaBuffer[1]) <=
                                (atrBuffer[1] * InpMaxPullbackATR);
   const bool rsiMomentum = rsiBuffer[1] > InpRSI_BuyLevel &&
                            rsiBuffer[2] <= InpRSI_BuyLevel;
   const bool strongTrend = adxBuffer[1] >= InpMinADX;

   return trendUp && pullbackNearEma && rsiMomentum && strongTrend;
}

//+------------------------------------------------------------------+
//| Sell setup                                                       |
//+------------------------------------------------------------------+
bool IsSellSignal()
{
   const double close1 = iClose(_Symbol, _Period, 1);
   const bool trendDown = close1 < slowEmaBuffer[1] &&
                          fastEmaBuffer[1] < slowEmaBuffer[1];
   const bool pullbackNearEma = MathAbs(close1 - fastEmaBuffer[1]) <=
                                (atrBuffer[1] * InpMaxPullbackATR);
   const bool rsiMomentum = rsiBuffer[1] < InpRSI_SellLevel &&
                            rsiBuffer[2] >= InpRSI_SellLevel;
   const bool strongTrend = adxBuffer[1] >= InpMinADX;

   return trendDown && pullbackNearEma && rsiMomentum && strongTrend;
}

//+------------------------------------------------------------------+
//| Open buy                                                         |
//+------------------------------------------------------------------+
bool OpenBuy()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0;
   double tp = 0;

   BuildStops(ORDER_TYPE_BUY, ask, sl, tp);

   if(!CheckFreeMargin(ORDER_TYPE_BUY, ask))
      return false;

   const bool result = trade.Buy(NormalizeVolume(InpLotSize), _Symbol, ask, sl, tp, "TrendRSI Buy");
   if(!result)
      Print("BUY failed: ", trade.ResultRetcodeDescription());

   return result;
}

//+------------------------------------------------------------------+
//| Open sell                                                        |
//+------------------------------------------------------------------+
bool OpenSell()
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0;
   double tp = 0;

   BuildStops(ORDER_TYPE_SELL, bid, sl, tp);

   if(!CheckFreeMargin(ORDER_TYPE_SELL, bid))
      return false;

   const bool result = trade.Sell(NormalizeVolume(InpLotSize), _Symbol, bid, sl, tp, "TrendRSI Sell");
   if(!result)
      Print("SELL failed: ", trade.ResultRetcodeDescription());

   return result;
}

//+------------------------------------------------------------------+
//| Build ATR stops                                                  |
//+------------------------------------------------------------------+
void BuildStops(const ENUM_ORDER_TYPE type, const double entryPrice, double &sl, double &tp)
{
   const double minStopDistance = GetMinimumStopDistance();
   const double atrDistance = MathMax(atrBuffer[1], minStopDistance);

   if(type == ORDER_TYPE_BUY)
   {
      if(InpUseATRStopLoss)
         sl = NormalizeDouble(entryPrice - (atrDistance * InpATRStopMultiplier), _Digits);
      if(InpUseATRTakeProfit)
         tp = NormalizeDouble(entryPrice + (atrDistance * InpATRTakeMultiplier), _Digits);
   }
   else
   {
      if(InpUseATRStopLoss)
         sl = NormalizeDouble(entryPrice + (atrDistance * InpATRStopMultiplier), _Digits);
      if(InpUseATRTakeProfit)
         tp = NormalizeDouble(entryPrice - (atrDistance * InpATRTakeMultiplier), _Digits);
   }
}

//+------------------------------------------------------------------+
//| Basket risk management                                           |
//+------------------------------------------------------------------+
bool ManageBasketRisk(const double basketProfit)
{
   if(basketProfit >= InpBasketTargetProfit)
   {
      Print("Basket target hit: ", DoubleToString(basketProfit, 2));
      CloseAllPositions();
      return true;
   }

   if(basketProfit <= -InpMaxBasketFloatingLoss)
   {
      Print("Basket floating loss limit hit: ", DoubleToString(basketProfit, 2));
      CloseAllPositions();
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calculate current basket profit                                  |
//+------------------------------------------------------------------+
double CalculateBasketProfit()
{
   double totalProfit = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!IsManagedPosition(ticket))
         continue;

      totalProfit += PositionGetDouble(POSITION_PROFIT);
      totalProfit += PositionGetDouble(POSITION_SWAP);
   }

   return totalProfit;
}

//+------------------------------------------------------------------+
//| Close all managed positions                                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!IsManagedPosition(ticket))
         continue;

      if(trade.PositionClose(ticket))
         Print("Closed ticket: ", ticket);
      else
         Print("Failed to close ticket ", ticket, ": ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Count managed positions                                          |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(IsManagedPosition(ticket))
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Check managed position type                                      |
//+------------------------------------------------------------------+
bool HasPositionType(const ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!IsManagedPosition(ticket))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Is this position managed by this EA                              |
//+------------------------------------------------------------------+
bool IsManagedPosition(const ulong ticket)
{
   if(ticket == 0)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;
   if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
      return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Daily profit/loss from closed deals                              |
//+------------------------------------------------------------------+
double CalculateDailyProfitLoss()
{
   double profit = 0;
   const datetime startDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(!HistorySelect(startDay, TimeCurrent()))
      return 0;

   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)InpMagicNumber)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
      profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }

   return profit;
}

//+------------------------------------------------------------------+
//| Margin check                                                     |
//+------------------------------------------------------------------+
bool CheckFreeMargin(const ENUM_ORDER_TYPE type, const double price)
{
   double margin = 0;
   const double volume = NormalizeVolume(InpLotSize);

   if(!OrderCalcMargin(type, _Symbol, volume, price, margin))
   {
      Print("Margin calculation failed.");
      return false;
   }

   if(AccountInfoDouble(ACCOUNT_FREEMARGIN) < margin)
   {
      Print("Not enough free margin. Required: ", DoubleToString(margin, 2));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double NormalizeVolume(const double volume)
{
   const double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double normalized = MathMax(minVolume, MathMin(volume, maxVolume));
   if(step > 0)
      normalized = MathFloor(normalized / step) * step;

   return NormalizeDouble(normalized, 2);
}

//+------------------------------------------------------------------+
//| Minimum broker stop distance                                     |
//+------------------------------------------------------------------+
double GetMinimumStopDistance()
{
   const int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const int minLevel = MathMax(stopsLevel, freezeLevel);

   return minLevel * _Point;
}

//+------------------------------------------------------------------+
//| Current spread in points                                         |
//+------------------------------------------------------------------+
double GetSpreadPoints()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   return (ask - bid) / _Point;
}

//+------------------------------------------------------------------+
