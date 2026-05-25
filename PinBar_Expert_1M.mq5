//+------------------------------------------------------------------+
//|                     PinBar_Expert_1M.mq5                        |
//|     روبوت/مؤشر تداول ذيول الشموع (Pin Bar) - فريم 1 دقيقة      |
//|                     MetaTrader 5  -  MT5                        |
//|                                                                  |
//|  الوظيفة: رصد وفلترة شموع Pin Bar على فريم الدقيقة (M1)       |
//|  الفلاتر: ATR - Volume - EMA Trend - Candle Geometry            |
//|  المخرجات: أسهم بيع/شراء + تنبيهات + لوحة تحكم عربية          |
//+------------------------------------------------------------------+
#property copyright   "PinBar Expert Advisor - MT5"
#property link        ""
#property version     "2.00"
#property description "روبوت تداول احترافي لشموع Pin Bar على فريم M1"
#property description "مع لوحة تحكم عربية متكاملة"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//====================================================================
//  INPUT PARAMETERS  |  المدخلات الخارجية
//====================================================================

input group "=== اعدادات هندسة الشمعة ==="
input double  InpMinBarSizeATR   = 1.2;   // الحد الأدنى لحجم الشمعة × ATR
input double  InpMaxBodyRatio    = 0.25;  // الحد الأقصى لنسبة الجسم (25%)
input double  InpMinTailRatio    = 0.65;  // الحد الأدنى لنسبة الذيل (65%)

input group "=== اعدادات الفلاتر ==="
input int     InpEMAPeriod       = 50;    // فترة EMA للاتجاه
input int     InpVolumePeriod    = 20;    // فترة متوسط حجم التداول
input double  InpVolumeMulti     = 1.3;   // مضاعف الحجم (130%)

input group "=== ادارة المخاطر ==="
input double  InpLotSize         = 0.01;  // حجم الصفقة (Lot Size)
input double  InpRiskReward      = 2.0;   // نسبة المخاطرة للعائد (1 : 2)
input double  InpSLBuffer        = 2.0;   // هامش وقف الخسارة (نقاط Pips)
input int     InpMaxTrades       = 3;     // الحد الأقصى للصفقات المفتوحة
input bool    InpAutoTrade       = true;  // تفعيل التداول الآلي

input group "=== التنبيهات ==="
input bool    InpAlert           = true;  // تنبيه صوتي على المنصة
input bool    InpPushNotif       = true;  // اشعار الهاتف (Push Notification)
input bool    InpEmailAlert      = false; // اشعار البريد الالكتروني

input group "=== الاعدادات البصرية ==="
input color   InpBuyColor        = clrLime;       // لون اشارة الشراء
input color   InpSellColor       = clrRed;        // لون اشارة البيع
input int     InpArrowSize       = 2;             // حجم الاسهم على الرسم
input color   InpDashBG          = C'10,14,28';   // لون خلفية لوحة التحكم
input color   InpDashAccent      = C'0,132,255';  // لون التمييز في اللوحة

//====================================================================
//  GLOBAL VARIABLES  |  المتغيرات العامة
//====================================================================
CTrade    Trade;
int       EmaHandle   = INVALID_HANDLE;
int       AtrHandle   = INVALID_HANDLE;

datetime  LastBarTime  = 0;
int       TotalSignals = 0;
int       BuySignals   = 0;
int       SellSignals  = 0;
int       TotalTrades  = 0;

string    LastSigType  = "---";
string    LastSigTime  = "--:--";
color     LastSigColor = clrSilver;

//--- Dashboard layout constants
const int DX = 15, DY = 20, DW = 300, DH = 400;

//--- Object naming & EA identity
const string OBJ_PREFIX   = "PB_";
const int    MAGIC_NUMBER = 112358;

//====================================================================
//  INIT
//====================================================================
int OnInit()
{
   EmaHandle = iMA(_Symbol, PERIOD_M1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   AtrHandle = iATR(_Symbol, PERIOD_M1, 14);

   if(EmaHandle == INVALID_HANDLE || AtrHandle == INVALID_HANDLE)
   {
      Alert("PinBar EA  |  فشل تهيئة المؤشرات! تحقق من الرمز أو الاتصال.");
      return INIT_FAILED;
   }

   Trade.SetExpertMagicNumber(MAGIC_NUMBER);
   Trade.SetDeviationInPoints(20);
   Trade.SetTypeFilling(ORDER_FILLING_IOC);

   ObjectsDeleteAll(0, OBJ_PREFIX);
   BuildDashboard();
   EventSetTimer(2);

   PrintFormat(
      "PinBar EA  نشط  |  %s  |  EMA=%d  |  ATR×%.1f  |  Vol×%.1f",
      _Symbol, InpEMAPeriod, InpMinBarSizeATR, InpVolumeMulti
   );
   return INIT_SUCCEEDED;
}

//====================================================================
//  DEINIT
//====================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(EmaHandle);
   IndicatorRelease(AtrHandle);
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
}

//====================================================================
//  TIMER  |  تحديث اللوحة كل ثانيتين
//====================================================================
void OnTimer()
{
   UpdateDashboard();
}

//====================================================================
//  MAIN TICK  |  التيك الرئيسي
//====================================================================
void OnTick()
{
   //--- تشغيل فقط عند بدء شمعة M1 جديدة
   datetime curBar = iTime(_Symbol, PERIOD_M1, 0);
   if(curBar == LastBarTime) return;
   LastBarTime = curBar;

   //--- بيانات الشمعة المغلقة [1]
   double H   = iHigh (_Symbol, PERIOD_M1, 1);
   double L   = iLow  (_Symbol, PERIOD_M1, 1);
   double O   = iOpen (_Symbol, PERIOD_M1, 1);
   double C   = iClose(_Symbol, PERIOD_M1, 1);
   datetime T = iTime (_Symbol, PERIOD_M1, 1);
   long  Vol  = iVolume(_Symbol, PERIOD_M1, 1);

   //--- حساب ابعاد الشمعة
   double range    = H - L;                     // إجمالي طول الشمعة
   double body     = MathAbs(C - O);            // حجم الجسم
   double upTail   = H - MathMax(O, C);         // الذيل العلوي
   double downTail = MathMin(O, C) - L;         // الذيل السفلي

   if(range < _Point * 2) return;

   //--- قراءة قيم المؤشرات
   double emaBuf[1], atrBuf[1];
   if(CopyBuffer(EmaHandle, 0, 1, 1, emaBuf) < 1) return;
   if(CopyBuffer(AtrHandle, 0, 1, 1, atrBuf) < 1) return;

   double emaVal = emaBuf[0];
   double atrVal = atrBuf[0];

   //--- حساب متوسط الحجم يدوياً
   double volAvg = CalcVolumeMA(InpVolumePeriod);
   if(volAvg <= 0) return;

   //--- الفلاتر المشتركة
   bool fATR  = (range >= atrVal * InpMinBarSizeATR);           // فلتر التقلب
   bool fVol  = ((double)Vol > volAvg * InpVolumeMulti);        // فلتر السيولة
   bool fBody = (body  <= range * InpMaxBodyRatio);              // فلتر الجسم

   //=================================================================
   //  اشارة الشراء  |  BUY  -  Bullish Pin Bar (ذيل سفلي طويل)
   //=================================================================
   bool fDownTail = (downTail >= range * InpMinTailRatio);
   bool fTrendUp  = (C > emaVal);

   if(fBody && fDownTail && fATR && fVol && fTrendUp)
   {
      TotalSignals++;
      BuySignals++;
      LastSigType  = "شراء  [BUY]";
      LastSigTime  = TimeToString(TimeCurrent(), TIME_MINUTES);
      LastSigColor = InpBuyColor;

      DrawArrow(T, L, true);
      FireAlert("BUY", C, atrVal, L, H);

      if(InpAutoTrade && CountPositions() < InpMaxTrades)
         ExecuteBuy(L);
   }

   //=================================================================
   //  اشارة البيع  |  SELL  -  Bearish Pin Bar (ذيل علوي طويل)
   //=================================================================
   bool fUpTail   = (upTail >= range * InpMinTailRatio);
   bool fTrendDn  = (C < emaVal);

   if(fBody && fUpTail && fATR && fVol && fTrendDn)
   {
      TotalSignals++;
      SellSignals++;
      LastSigType  = "بيع  [SELL]";
      LastSigTime  = TimeToString(TimeCurrent(), TIME_MINUTES);
      LastSigColor = InpSellColor;

      DrawArrow(T, H, false);
      FireAlert("SELL", C, atrVal, L, H);

      if(InpAutoTrade && CountPositions() < InpMaxTrades)
         ExecuteSell(H);
   }

   UpdateDashboard();
}

//====================================================================
//  TRADE EXECUTION  |  تنفيذ الصفقات
//====================================================================

void ExecuteBuy(double prevLow)
{
   double pip   = PipValue();
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl    = NormalizeDouble(prevLow - InpSLBuffer * pip, _Digits);
   double dist  = MathMax(ask - sl, MinStopDist());
   sl           = NormalizeDouble(ask - dist, _Digits);
   double tp    = NormalizeDouble(ask + dist * InpRiskReward, _Digits);

   if(dist <= 0 || sl <= 0 || tp <= 0) return;

   if(Trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "PB_BUY"))
   {
      TotalTrades++;
      PrintFormat("BUY  |  Ask=%.5f  SL=%.5f  TP=%.5f  Lot=%.2f",
                  ask, sl, tp, InpLotSize);
   }
}

void ExecuteSell(double prevHigh)
{
   double pip   = PipValue();
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl    = NormalizeDouble(prevHigh + InpSLBuffer * pip, _Digits);
   double dist  = MathMax(sl - bid, MinStopDist());
   sl           = NormalizeDouble(bid + dist, _Digits);
   double tp    = NormalizeDouble(bid - dist * InpRiskReward, _Digits);

   if(dist <= 0 || sl <= 0 || tp <= 0) return;

   if(Trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "PB_SELL"))
   {
      TotalTrades++;
      PrintFormat("SELL  |  Bid=%.5f  SL=%.5f  TP=%.5f  Lot=%.2f",
                  bid, sl, tp, InpLotSize);
   }
}

//====================================================================
//  UTILITIES  |  دوال مساعدة
//====================================================================

//--- حساب متوسط حجم التداول يدوياً
double CalcVolumeMA(int period)
{
   long v[];
   int copied = (int)CopyTickVolume(_Symbol, PERIOD_M1, 1, period, v);
   if(copied < period) return 0;
   double sum = 0;
   for(int i = 0; i < period; i++) sum += (double)v[i];
   return sum / period;
}

//--- عدد الصفقات المفتوحة الخاصة بهذا الروبوت
int CountPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
         n++;
   }
   return n;
}

//--- إجمالي الربح/الخسارة الحالية
double GetPnL()
{
   double p = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
         p += PositionGetDouble(POSITION_PROFIT);
   }
   return p;
}

//--- حجم النقطة (Pip) بحسب عدد الارقام العشرية
double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 5 || digits == 3) ? 10.0 * _Point : _Point;
}

//--- الحد الأدنى لمسافة وقف الخسارة
double MinStopDist()
{
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return (stopsLevel + 5) * _Point;
}

//--- رسم السهم على الرسم البياني
void DrawArrow(datetime t, double price, bool isBuy)
{
   string name   = OBJ_PREFIX + "ARR" + IntegerToString((int)t);
   double offset = 12.0 * _Point;
   double pos    = isBuy ? price - offset : price + offset;

   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_ARROW, 0, t, pos);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,   isBuy ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR,       isBuy ? InpBuyColor : InpSellColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,       InpArrowSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,      true);
   ChartRedraw(0);
}

//--- ارسال التنبيهات
void FireAlert(string dir, double price, double atr, double low1, double high1)
{
   string pip  = PipValue() > _Point ? "pips" : "points";
   string side = (dir == "BUY") ? "اشارة شراء" : "اشارة بيع";
   string msg  = StringFormat(
      "PinBar [%s]  |  %s\n"
      "الرمز: %s     السعر: %.5f\n"
      "ATR: %.5f    الوقت: %s",
      dir, side,
      _Symbol, price,
      atr,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES)
   );

   if(InpAlert)      Alert(msg);
   if(InpPushNotif)  SendNotification(msg);
   if(InpEmailAlert) SendMail("PinBar " + dir + "  |  " + _Symbol, msg);
   Print(msg);
}

//====================================================================
//  DASHBOARD  |  لوحة التحكم العربية
//====================================================================
void BuildDashboard()
{
   //--- الخلفية الرئيسية
   MkRect(OBJ_PREFIX+"BG",          DX,        DY,         DW,    DH,    InpDashBG);
   MkRect(OBJ_PREFIX+"AccTop",      DX,        DY,         DW,    4,     InpDashAccent);
   MkRect(OBJ_PREFIX+"AccBot",      DX,        DY+DH-4,    DW,    4,     InpDashAccent);
   MkRect(OBJ_PREFIX+"AccLeft",     DX,        DY,         3,     DH,    InpDashAccent);
   MkRect(OBJ_PREFIX+"AccRight",    DX+DW-3,   DY,         3,     DH,    InpDashAccent);

   //--- العنوان
   MkLbl(OBJ_PREFIX+"Title",
         "    Pin Bar Expert  |  ذيول الشموع",
         DX+12, DY+10, clrWhite, 11, "Arial Bold");
   MkLbl(OBJ_PREFIX+"SubTitle",
         "    MetaTrader 5   -   فريم 1 دقيقة  (M1)",
         DX+12, DY+27, InpDashAccent, 8, "Arial");

   MkSep(DY+43);

   //--- معلومات الرمز
   MkLbl(OBJ_PREFIX+"lSym",  "الرمز:",   DX+12,  DY+50, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vSym",  _Symbol,    DX+80,  DY+50, clrWhite,        9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lTF",   "الإطار:", DX+160, DY+50, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vTF",   "M1",       DX+225, DY+50, C'0,220,180',   9, "Arial Bold");

   MkSep(DY+67);

   //--- قسم الحالة
   MkSecH("Status", "الحالة والوضع", DY+73);
   MkLbl(OBJ_PREFIX+"lActv",  "حالة النظام:",    DX+12, DY+90,  C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vActv",  "نشط  ●",           DX+148, DY+90,  C'0,230,100',   9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lMode",  "وضع التشغيل:",   DX+12, DY+106, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vMode",
         InpAutoTrade ? "تداول آلي  ✓" : "اشارات فقط",
         DX+148, DY+106,
         InpAutoTrade ? C'255,210,0' : C'0,200,255', 9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lSprd",  "السبريد الحالي:", DX+12, DY+122, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vSprd",  "...",              DX+148, DY+122, C'255,200,0',   9, "Arial Bold");

   MkSep(DY+139);

   //--- قسم آخر اشارة
   MkSecH("LSig", "آخر اشارة", DY+145);
   MkLbl(OBJ_PREFIX+"lLTyp",  "النوع:",          DX+12, DY+162, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vLTyp",  "---",              DX+148, DY+162, clrSilver,      9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lLTim",  "الوقت:",          DX+12, DY+178, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vLTim",  "--:--",            DX+148, DY+178, clrSilver,      9, "Arial Bold");

   MkSep(DY+195);

   //--- قسم احصائيات الاشارات
   MkSecH("SigStat", "احصائيات الاشارات", DY+201);
   MkLbl(OBJ_PREFIX+"lTotS",  "اجمالي الاشارات:",   DX+12, DY+218, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vTotS",  "0",                    DX+232, DY+218, clrWhite,       9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lBuyS",  "اشارات الشراء [BUY]:", DX+12, DY+234, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vBuyS",  "0",                    DX+232, DY+234, InpBuyColor,    9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lSelS",  "اشارات البيع [SELL]:", DX+12, DY+250, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vSelS",  "0",                    DX+232, DY+250, InpSellColor,   9, "Arial Bold");

   MkSep(DY+267);

   //--- قسم الصفقات
   MkSecH("Trades", "الصفقات", DY+273);
   MkLbl(OBJ_PREFIX+"lOpen",  "صفقات مفتوحة:",    DX+12, DY+290, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vOpen",  "0",                  DX+232, DY+290, C'255,210,0',   9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lTotT",  "اجمالي الصفقات:", DX+12, DY+306, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vTotT",  "0",                  DX+232, DY+306, clrWhite,       9, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lPnL",   "ربح / خسارة الجلسة:", DX+12, DY+322, C'150,165,200', 9, "Arial");
   MkLbl(OBJ_PREFIX+"vPnL",   "0.00",               DX+232, DY+322, clrWhite,       9, "Arial Bold");

   MkSep(DY+340);

   //--- قسم اعدادات الفلاتر
   MkSecH("Filt", "اعدادات الفلاتر النشطة", DY+346);

   //--- Row 1: EMA | ATR
   MkLbl(OBJ_PREFIX+"lfEMA",  "EMA الاتجاه:",     DX+12,  DY+362, C'110,130,165', 8, "Arial");
   MkLbl(OBJ_PREFIX+"vfEMA",  IntegerToString(InpEMAPeriod),
         DX+110, DY+362, C'100,175,255', 8, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lfATR",  "ATR مضاعف:",        DX+155, DY+362, C'110,130,165', 8, "Arial");
   MkLbl(OBJ_PREFIX+"vfATR",  DoubleToString(InpMinBarSizeATR, 1)+"x",
         DX+245, DY+362, C'100,175,255', 8, "Arial Bold");

   //--- Row 2: Volume | Body
   MkLbl(OBJ_PREFIX+"lfVol",  "حجم مضاعف:",       DX+12,  DY+377, C'110,130,165', 8, "Arial");
   MkLbl(OBJ_PREFIX+"vfVol",  DoubleToString(InpVolumeMulti,1)+"x",
         DX+110, DY+377, C'100,175,255', 8, "Arial Bold");
   MkLbl(OBJ_PREFIX+"lfBody", "جسم أقصى:",         DX+155, DY+377, C'110,130,165', 8, "Arial");
   MkLbl(OBJ_PREFIX+"vfBody", DoubleToString(InpMaxBodyRatio*100,0)+"%",
         DX+245, DY+377, C'100,175,255', 8, "Arial Bold");

   //--- Footer timestamp
   MkSep(DY+DH-22);
   MkLbl(OBJ_PREFIX+"lClock", "  --/--/----   --:--:--",
         DX+12, DY+DH-16, C'65,82,110', 7, "Arial");

   ChartRedraw(0);
}

//--- تحديث قيم لوحة التحكم
void UpdateDashboard()
{
   //--- السبريد
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   ObjSetTxt(OBJ_PREFIX+"vSprd", IntegerToString((int)sp) + " pts");

   //--- آخر اشارة
   ObjSetTxt(OBJ_PREFIX+"vLTyp", LastSigType);
   ObjSetClr(OBJ_PREFIX+"vLTyp", LastSigColor);
   ObjSetTxt(OBJ_PREFIX+"vLTim", LastSigTime);

   //--- احصائيات الاشارات
   ObjSetTxt(OBJ_PREFIX+"vTotS", IntegerToString(TotalSignals));
   ObjSetTxt(OBJ_PREFIX+"vBuyS", IntegerToString(BuySignals));
   ObjSetTxt(OBJ_PREFIX+"vSelS", IntegerToString(SellSignals));

   //--- الصفقات
   int openPos = CountPositions();
   ObjSetTxt(OBJ_PREFIX+"vOpen", IntegerToString(openPos));
   ObjSetTxt(OBJ_PREFIX+"vTotT", IntegerToString(TotalTrades));

   double pnl    = GetPnL();
   color  pnlClr = (pnl >= 0) ? C'0,230,100' : C'255,70,70';
   ObjSetTxt(OBJ_PREFIX+"vPnL",  DoubleToString(pnl, 2));
   ObjSetClr(OBJ_PREFIX+"vPnL",  pnlClr);

   //--- الساعة
   ObjSetTxt(OBJ_PREFIX+"lClock",
             "  " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

   ChartRedraw(0);
}

//====================================================================
//  CHART OBJECT MICRO-HELPERS  |  دوال انشاء عناصر الرسم
//====================================================================

void MkRect(string name, int x, int y, int w, int h, color c)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    c);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void MkLbl(string name, string txt, int x, int y, color c, int fs, string font)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString (0, name, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetString (0, name, OBJPROP_FONT,       font);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void MkSep(int y)
{
   string name = OBJ_PREFIX + "Sep" + IntegerToString(y);
   MkRect(name, DX+4, y, DW-8, 1, C'38,52,80');
}

void MkSecH(string id, string txt, int y)
{
   MkLbl(OBJ_PREFIX + "Hdr" + id,
         "  " + txt,
         DX+10, y, C'185,200,230', 9, "Arial Bold");
}

void ObjSetTxt(string name, string txt)
{
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

void ObjSetClr(string name, color c)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
}
