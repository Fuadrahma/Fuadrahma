//+------------------------------------------------------------------+
//| PinBarEA.mq5                                                     |
//| إكسبيرت تداول ذيول الشموع - فريم الدقيقة                        |
//| Pin Bar Trading System with Arabic Dashboard                     |
//+------------------------------------------------------------------+
#property copyright   "Pin Bar EA"
#property version     "1.00"
#property description "نظام تداول ذيول الشموع (Pin Bar) مع فلاتر ATR و EMA و Volume"
#property description "يعمل على فريم الدقيقة (M1) مع لوحة معلومات عربية احترافية"

#include <Trade\Trade.mqh>
#include <PinBarDashboard.mqh>

//+------------------------------------------------------------------+
//| المدخلات الخارجية - الفلاتر                                       |
//+------------------------------------------------------------------+
input group "══════ إعدادات هندسة الشمعة ══════"
input double InpMinBarATR       = 1.2;    // الحد الأدنى لحجم الشمعة / ATR
input double InpMaxBodyRatio    = 0.25;   // الحد الأقصى لنسبة الجسم (25%)
input double InpMinTailRatio    = 0.65;   // الحد الأدنى لنسبة الذيل (65%)

input group "══════ إعدادات الفلاتر ══════"
input int    InpTrendEMA        = 50;     // فترة المتوسط المتحرك (EMA)
input int    InpVolumePeriod    = 20;     // فترة متوسط حجم التداول
input double InpVolumeMulti     = 1.3;    // مضاعف الحجم (130%)
input int    InpATRPeriod       = 14;     // فترة مؤشر ATR

input group "══════ إدارة المخاطر ══════"
input double InpLotSize         = 0.01;   // حجم العقد
input double InpRiskReward      = 2.0;    // نسبة العائد للمخاطرة (1:X)
input int    InpSLBuffer        = 2;      // نقاط إضافية لوقف الخسارة
input int    InpMaxSpread       = 30;     // الحد الأقصى للسبريد (نقاط)
input int    InpMagicNumber     = 202501; // الرقم السحري للصفقات
input int    InpMaxOpenTrades   = 3;      // الحد الأقصى للصفقات المفتوحة

input group "══════ التنبيهات ══════"
input bool   InpAlertSound      = true;   // تنبيه صوتي
input bool   InpAlertPush       = true;   // إشعار الهاتف
input bool   InpAlertPopup      = true;   // نافذة تنبيه

input group "══════ لوحة المعلومات ══════"
input bool   InpShowDashboard   = true;   // إظهار اللوحة
input int    InpDashboardX      = 20;     // موضع اللوحة - أفقي
input int    InpDashboardY      = 30;     // موضع اللوحة - عمودي

//+------------------------------------------------------------------+
//| متغيرات عامة                                                      |
//+------------------------------------------------------------------+
CTrade            trade;
CPinBarDashboard  dashboard;

int               h_ema;
int               h_atr;

double            buf_ema[];
double            buf_atr[];

int               g_total_buy;
int               g_total_sell;
int               g_wins;
int               g_losses;
double            g_total_profit;
datetime          g_last_signal_time;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   h_ema = iMA(_Symbol, PERIOD_M1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(h_ema == INVALID_HANDLE)
     {
      Print("خطأ في إنشاء مؤشر EMA: ", GetLastError());
      return INIT_FAILED;
     }

   h_atr = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   if(h_atr == INVALID_HANDLE)
     {
      Print("خطأ في إنشاء مؤشر ATR: ", GetLastError());
      return INIT_FAILED;
     }

   ArraySetAsSeries(buf_ema, true);
   ArraySetAsSeries(buf_atr, true);

   g_total_buy = 0;
   g_total_sell = 0;
   g_wins = 0;
   g_losses = 0;
   g_total_profit = 0.0;
   g_last_signal_time = 0;

   if(InpShowDashboard)
      dashboard.Init(InpDashboardX, InpDashboardY);

   Print("══════════════════════════════════════════");
   Print("  نظام ذيول الشموع - تم التشغيل بنجاح");
   Print("  الرمز: ", _Symbol, " | الإطار: M1");
   Print("══════════════════════════════════════════");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(h_ema != INVALID_HANDLE)
      IndicatorRelease(h_ema);
   if(h_atr != INVALID_HANDLE)
      IndicatorRelease(h_atr);

   dashboard.Destroy();

   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "PB_ARROW_") == 0)
         ObjectDelete(0, name);
     }

   Print("نظام ذيول الشموع - تم الإيقاف");
  }

//+------------------------------------------------------------------+
//| حساب متوسط الحجم يدوياً من tick volumes                           |
//+------------------------------------------------------------------+
double CalcVolumeAverage(int period)
  {
   double volumes[];
   ArraySetAsSeries(volumes, true);
   int copied = CopyTickVolume(_Symbol, PERIOD_M1, 0, period + 2, volumes);
   if(copied < period + 2)
      return 0;

   double sum = 0;
   for(int i = 1; i <= period; i++)
      sum += volumes[i];

   return sum / period;
  }

//+------------------------------------------------------------------+
//| الحصول على حجم الشمعة رقم 1                                      |
//+------------------------------------------------------------------+
double GetBarVolume(int shift)
  {
   long vol[];
   ArraySetAsSeries(vol, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, shift + 2, vol) < shift + 2)
      return 0;
   return (double)vol[shift];
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);

   UpdateDashboard();

   if(current_bar_time == last_bar_time)
      return;
   last_bar_time = current_bar_time;

   UpdateTradeStats();

   if(CopyBuffer(h_ema, 0, 0, 3, buf_ema) < 3)
      return;
   if(CopyBuffer(h_atr, 0, 0, 3, buf_atr) < 3)
      return;

   double vol_avg = CalcVolumeAverage(InpVolumePeriod);
   if(vol_avg <= 0)
      return;

   double vol1 = GetBarVolume(1);

   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);

   double total_range = high1 - low1;
   if(total_range <= 0)
      return;

   double body_size  = MathAbs(close1 - open1);
   double upper_tail = high1 - MathMax(open1, close1);
   double lower_tail = MathMin(open1, close1) - low1;

   double body_ratio  = body_size / total_range;
   double upper_ratio = upper_tail / total_range;
   double lower_ratio = lower_tail / total_range;

   bool size_ok   = total_range >= (buf_atr[1] * InpMinBarATR);
   bool body_ok   = body_ratio <= InpMaxBodyRatio;
   bool volume_ok = vol1 > (vol_avg * InpVolumeMulti);

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool spread_ok = (spread <= InpMaxSpread);

   bool is_bullish_pin = body_ok &&
                         (lower_ratio >= InpMinTailRatio) &&
                         size_ok &&
                         volume_ok &&
                         (close1 > buf_ema[1]);

   bool is_bearish_pin = body_ok &&
                         (upper_ratio >= InpMinTailRatio) &&
                         size_ok &&
                         volume_ok &&
                         (close1 < buf_ema[1]);

   if(is_bullish_pin && spread_ok && CanOpenTrade())
      ExecuteBuy(high1, low1, close1, buf_atr[1], vol1 / vol_avg);

   if(is_bearish_pin && spread_ok && CanOpenTrade())
      ExecuteSell(high1, low1, close1, buf_atr[1], vol1 / vol_avg);
  }

//+------------------------------------------------------------------+
//| تنفيذ صفقة الشراء                                                 |
//+------------------------------------------------------------------+
void ExecuteBuy(double high1, double low1, double close1, double atr, double vol_ratio)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = NormalizeDouble(low1 - InpSLBuffer * point * 10, digits);
   double risk = ask - sl;
   if(risk <= 0)
      return;

   double tp = NormalizeDouble(ask + risk * InpRiskReward, digits);

   if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "PinBar BUY"))
     {
      g_total_buy++;

      DrawArrow(iTime(_Symbol, PERIOD_M1, 1), low1, true);

      SignalRecord sig;
      sig.time = iTime(_Symbol, PERIOD_M1, 1);
      sig.type = "شراء";
      sig.entry = ask;
      sig.sl = sl;
      sig.tp = tp;
      sig.atr = atr;
      sig.volume_ratio = vol_ratio;
      sig.active = true;
      dashboard.AddSignal(sig);

      SendAlerts("شراء", ask, sl, tp);

      Print("══ صفقة شراء ══ السعر: ", DoubleToString(ask, digits),
            " | SL: ", DoubleToString(sl, digits),
            " | TP: ", DoubleToString(tp, digits),
            " | ATR: ", DoubleToString(atr, digits),
            " | Vol\x00D7: ", DoubleToString(vol_ratio, 1));
     }
   else
      Print("خطأ في فتح صفقة الشراء: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| تنفيذ صفقة البيع                                                   |
//+------------------------------------------------------------------+
void ExecuteSell(double high1, double low1, double close1, double atr, double vol_ratio)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = NormalizeDouble(high1 + InpSLBuffer * point * 10, digits);
   double risk = sl - bid;
   if(risk <= 0)
      return;

   double tp = NormalizeDouble(bid - risk * InpRiskReward, digits);

   if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "PinBar SELL"))
     {
      g_total_sell++;

      DrawArrow(iTime(_Symbol, PERIOD_M1, 1), high1, false);

      SignalRecord sig;
      sig.time = iTime(_Symbol, PERIOD_M1, 1);
      sig.type = "بيع";
      sig.entry = bid;
      sig.sl = sl;
      sig.tp = tp;
      sig.atr = atr;
      sig.volume_ratio = vol_ratio;
      sig.active = true;
      dashboard.AddSignal(sig);

      SendAlerts("بيع", bid, sl, tp);

      Print("══ صفقة بيع ══ السعر: ", DoubleToString(bid, digits),
            " | SL: ", DoubleToString(sl, digits),
            " | TP: ", DoubleToString(tp, digits),
            " | ATR: ", DoubleToString(atr, digits),
            " | Vol\x00D7: ", DoubleToString(vol_ratio, 1));
     }
   else
      Print("خطأ في فتح صفقة البيع: ", GetLastError());
  }

//+------------------------------------------------------------------+
//| رسم السهم على الرسم البياني                                       |
//+------------------------------------------------------------------+
void DrawArrow(datetime time, double price, bool is_buy)
  {
   string name = "PB_ARROW_" + TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   int arrow_code = is_buy ? 233 : 234;
   color arrow_clr = is_buy ? clrLime : clrRed;
   double offset = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;

   if(is_buy)
      price -= offset;
   else
      price += offset;

   ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrow_clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//| إرسال التنبيهات                                                    |
//+------------------------------------------------------------------+
void SendAlerts(string signal_type, double price, double sl, double tp)
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string msg = "Pin Bar " + signal_type + " | " + _Symbol +
                "\nالسعر: " + DoubleToString(price, digits) +
                "\nوقف الخسارة: " + DoubleToString(sl, digits) +
                "\nأخذ الربح: " + DoubleToString(tp, digits);

   if(InpAlertPopup)
      Alert(msg);

   if(InpAlertSound)
      PlaySound("alert.wav");

   if(InpAlertPush)
      SendNotification(msg);
  }

//+------------------------------------------------------------------+
//| التحقق من إمكانية فتح صفقة جديدة                                 |
//+------------------------------------------------------------------+
bool CanOpenTrade()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
     }
   return count < InpMaxOpenTrades;
  }

//+------------------------------------------------------------------+
//| تحديث إحصائيات الصفقات                                            |
//+------------------------------------------------------------------+
void UpdateTradeStats()
  {
   g_wins = 0;
   g_losses = 0;
   g_total_profit = 0;

   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();

   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      g_total_profit += profit;

      if(profit > 0)
         g_wins++;
      else
         g_losses++;
     }
  }

//+------------------------------------------------------------------+
//| تحديث لوحة المعلومات                                              |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!InpShowDashboard)
      return;

   double ema_val = 0;
   double atr_val = 0;

   double tmp_ema[1];
   double tmp_atr[1];
   if(CopyBuffer(h_ema, 0, 1, 1, tmp_ema) >= 1)
      ema_val = tmp_ema[0];
   if(CopyBuffer(h_atr, 0, 1, 1, tmp_atr) >= 1)
      atr_val = tmp_atr[0];

   double vol_avg = CalcVolumeAverage(InpVolumePeriod);
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   string status;
   color  status_clr;

   int open_trades = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         open_trades++;
     }

   if(open_trades > 0)
     {
      status = "نشط - " + IntegerToString(open_trades) + " صفقات";
      status_clr = C'34,197,94';
     }
   else
     {
      status = "يراقب السوق...";
      status_clr = C'59,130,246';
     }

   int total_trades = g_wins + g_losses;
   double win_rate = (total_trades > 0) ? (g_wins * 100.0 / total_trades) : 0;

   dashboard.UpdateStats(g_total_buy, g_total_sell, win_rate, g_total_profit);
   dashboard.Update(ema_val, atr_val, vol_avg, current_price, status, status_clr);
  }

//+------------------------------------------------------------------+
//| معالجة نقرات الرسم البياني                                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CLICK)
     {
      int x = (int)lparam;
      int y = (int)dparam;
      if(dashboard.OnClick(x, y))
         UpdateDashboard();
     }
  }
//+------------------------------------------------------------------+
