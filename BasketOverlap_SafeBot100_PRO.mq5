//+------------------------------------------------------------------+
//|                 BasketOverlap_SafeBot100_PRO.mq5                |
//|                        Safe Basket RSI Bot                       |
//+------------------------------------------------------------------+
#property strict
#property version   "5.00"

#include <Trade/Trade.mqh>

CTrade trade;

//--------------------------------------------------
// INPUTS
//--------------------------------------------------
input group "--- RISK SETTINGS ---"

input double InpLotSize              = 0.01;
input int    InpMaxPositions         = 3;
input double InpBasketTargetProfit   = 1.50;
input double InpMaxDailyLoss         = 5.00;
input ulong  InpMagicNumber          = 777111;

input group "--- RSI SETTINGS ---"

input int    InpRSI_Period           = 14;
input double InpRSI_Overbought       = 70.0;
input double InpRSI_Oversold         = 30.0;

input group "--- SAFETY FILTERS ---"

input double InpMaxSpreadPoints      = 30;
input bool   InpUseStopLoss          = true;
input int    InpStopLossPoints       = 300;
input bool   InpUseTakeProfit        = false;
input int    InpTakeProfitPoints     = 500;

input group "--- TRADE SETTINGS ---"

input bool   InpOneTradePerBar       = true;

//--------------------------------------------------
// GLOBAL VARIABLES
//--------------------------------------------------

int      rsiHandle;
double   rsiBuffer[];

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   rsiHandle = iRSI(_Symbol,_Period,InpRSI_Period,PRICE_CLOSE);

   if(rsiHandle == INVALID_HANDLE)
   {
      Print("[ERROR] Failed To Create RSI");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(rsiBuffer,true);

   Print("[OK] SafeBot Initialized");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Daily Protection
   double dailyPL = CalculateDailyProfitLoss();

   if(dailyPL <= -InpMaxDailyLoss)
   {
      Comment("[ERROR] DAILY LOSS LIMIT HIT");
      return;
   }

   //--- Spread Protection
   double spread = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol,SYMBOL_BID))
                    / _Point;

   if(spread > InpMaxSpreadPoints)
   {
      Comment("[WARN] Spread Too High");
      return;
   }

   //--- Read RSI
   if(CopyBuffer(rsiHandle,0,0,3,rsiBuffer) < 3)
      return;

   //--- Basket Management
   CheckBasketProfit();

   //--- Position Count
   int currentPositions = CountPositions();

   //--- Comment
   Comment(
      "SAFE BOT RUNNING\n",
      "Positions: ",currentPositions," / ",InpMaxPositions,"\n",
      "Daily P/L: ",DoubleToString(dailyPL,2)," $\n",
      "Spread: ",DoubleToString(spread,1)," pts"
   );

   //--- Max Positions Protection
   if(currentPositions >= InpMaxPositions)
      return;

   //--- One Trade Per Candle
   if(InpOneTradePerBar)
   {
      datetime currentBar = iTime(_Symbol,_Period,0);

      if(currentBar == lastBarTime)
         return;

      lastBarTime = currentBar;
   }

   //--- Buy Signal
   if(rsiBuffer[1] > InpRSI_Oversold &&
      rsiBuffer[2] <= InpRSI_Oversold)
   {
      OpenBuy();
   }

   //--- Sell Signal
   if(rsiBuffer[1] < InpRSI_Overbought &&
      rsiBuffer[2] >= InpRSI_Overbought)
   {
      OpenSell();
   }
}

//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   double sl = 0;
   double tp = 0;

   if(InpUseStopLoss)
      sl = ask - (InpStopLossPoints * _Point);

   if(InpUseTakeProfit)
      tp = ask + (InpTakeProfitPoints * _Point);

   if(!CheckFreeMargin(ORDER_TYPE_BUY))
      return;

   bool result = trade.Buy(
      InpLotSize,
      _Symbol,
      ask,
      sl,
      tp,
      "SafeBot BUY"
   );

   if(result)
      Print("[OK] BUY OPENED");
   else
      Print("[ERROR] BUY FAILED: ",trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Open SELL                                                        |
//+------------------------------------------------------------------+
void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double sl = 0;
   double tp = 0;

   if(InpUseStopLoss)
      sl = bid + (InpStopLossPoints * _Point);

   if(InpUseTakeProfit)
      tp = bid - (InpTakeProfitPoints * _Point);

   if(!CheckFreeMargin(ORDER_TYPE_SELL))
      return;

   bool result = trade.Sell(
      InpLotSize,
      _Symbol,
      bid,
      sl,
      tp,
      "SafeBot SELL"
   );

   if(result)
      Print("[OK] SELL OPENED");
   else
      Print("[ERROR] SELL FAILED: ",trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Basket Profit Close                                              |
//+------------------------------------------------------------------+
void CheckBasketProfit()
{
   double totalProfit = 0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      totalProfit += PositionGetDouble(POSITION_PROFIT);
      totalProfit += PositionGetDouble(POSITION_SWAP);
      totalProfit += PositionGetDouble(POSITION_COMMISSION);
   }

   if(totalProfit >= InpBasketTargetProfit)
   {
      Print("[OK] Basket Target Hit: ",totalProfit);

      CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      bool result = trade.PositionClose(ticket);

      if(result)
         Print("[OK] Closed Ticket: ",ticket);
      else
         Print("[ERROR] Failed Close: ",ticket,
               " ",trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Count Positions                                                  |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket <= 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Daily Profit/Loss                                                |
//+------------------------------------------------------------------+
double CalculateDailyProfitLoss()
{
   double profit = 0;

   datetime startDay =
      StringToTime(TimeToString(TimeCurrent(),TIME_DATE));

   if(!HistorySelect(startDay,TimeCurrent()))
      return 0;

   int deals = HistoryDealsTotal();

   for(int i=0; i<deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket <= 0)
         continue;

      if(HistoryDealGetInteger(ticket,DEAL_MAGIC)
         != (long)InpMagicNumber)
         continue;

      profit += HistoryDealGetDouble(ticket,DEAL_PROFIT);
      profit += HistoryDealGetDouble(ticket,DEAL_SWAP);
      profit += HistoryDealGetDouble(ticket,DEAL_COMMISSION);
   }

   return profit;
}

//+------------------------------------------------------------------+
//| Margin Check                                                     |
//+------------------------------------------------------------------+
bool CheckFreeMargin(ENUM_ORDER_TYPE type)
{
   double price = 0;

   if(type == ORDER_TYPE_BUY)
      price = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   else
      price = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double margin = 0;

   if(!OrderCalcMargin(
      type,
      _Symbol,
      InpLotSize,
      price,
      margin))
   {
      Print("[ERROR] Margin Calculation Failed");
      return false;
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);

   if(freeMargin < margin)
   {
      Print("[ERROR] Not Enough Free Margin");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
