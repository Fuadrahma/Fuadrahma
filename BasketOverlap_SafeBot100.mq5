//+------------------------------------------------------------------+
//|                                     BasketOverlap_SafeBot100.mq5 |
//|                                  Copyright 2026, AI Developer    |
//|                                             https://mql5.com     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://mql5.com"
#property version   "4.00"
#property strict

//--- تضمين مكتبة التداول
#include <Trade\Trade.mqh>
CTrade trade;

//--- المدخلات الخارجية (إعدادات التحكم للبوت)
input group "--- RISK & LOT SETTINGS ---"
input double   InpLotSize           = 0.01;   // حجم اللوت الثابت والصارم (0.01)
input int      InpMaxPositions      = 3;      // أقصى عدد صفقات مفتوحة معاً (حماية للهامش)
input double   InpBasketTargetProfit= 1.50;   // الربح المستهدف الصافي لإغلاق السلة بالدولار
input double   InpMaxDailyLoss      = 5.00;   // أقصى خسارة يومية مسموحة بالدولار (5$)
input ulong    InpMagicNumber       = 777111; // معرف صفقات البوت السري

input group "--- STRATEGY SETTINGS (RSI) ---"
input int      InpRSI_Period        = 14;     // فترة مؤشر RSI
input double   InpRSI_Overbought    = 70.0;   // مستوى التشبع الشرائي (للبيع)
input double   InpRSI_Oversold      = 30.0;   // مستوى التشبع البيعي (للشراء)

//--- المتغيرات الفنية الداخلية
int      rsiHandle;
double   rsiValues[];

//+------------------------------------------------------------------+
//| دالة بدء التشغيل                                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   // تعيين الرقم السري للبوت
   trade.SetExpertMagicNumber(InpMagicNumber);

   // تعريف مؤشر RSI
   rsiHandle = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
   {
      Print("فشل في تحميل مؤشر RSI!");
      return(INIT_FAILED);
   }

   // ترتيب المصفوفة زمنياً
   ArraySetAsSeries(rsiValues, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| دالة إلغاء التفعيل                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| دالة التحديث المستمر                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. التحقق من حماية الخسارة اليومية القصوى
   if(CalculateDailyProfitLoss() <= -InpMaxDailyLoss)
   {
      Comment("❌ تم تفعيل حماية الخسارة اليومية! البوت متوقف اليوم.");
      return;
   }

   // 2. تحديث وقراءة قيم مؤشر RSI
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiValues) < 3) return;

   // 3. استدعاء تقنية الأوفرلاب وفحص سلة الصفقات لإغلاقها فور تحقيق الربح الصافي
   CheckBasketOverlap();

   // الحصول على أسعار السوق الحالية
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // حساب عدد صفقات البوت الحالية المفتوحة
   int currentPositions = CountCurrentPositions();

   Comment("🤖 البوت يعمل بأمان...\n",
           "عدد الصفقات المفتوحة حالياً: ", currentPositions, " من أصل ", InpMaxPositions, "\n",
           "النتيجة اليومية المغلقة: ", CalculateDailyProfitLoss(), " $");

   // 4. شروط فتح الصفقات بناءً على الزخم (بشرط عدم تجاوز الحد الأقصى للصفقات)
   if(currentPositions < InpMaxPositions)
   {
      // إشارة شراء وتبريد صاعد (ارتداد الـ RSI صعوداً من مستوى 30)
      if(rsiValues[1] > InpRSI_Oversold && rsiValues[2] <= InpRSI_Oversold)
      {
         trade.Buy(InpLotSize, _Symbol, Ask, 0, 0, "SafeBasket Buy");
      }

      // إشارة بيع وتبريد هابط (ارتداد الـ RSI هبوطاً من مستوى 70)
      if(rsiValues[1] < InpRSI_Overbought && rsiValues[2] >= InpRSI_Overbought)
      {
         trade.Sell(InpLotSize, _Symbol, Bid, 0, 0, "SafeBasket Sell");
      }
   }
}

//+------------------------------------------------------------------+
//| دالة تقنية الأوفرلاب (إغلاق الصفقات الرابحة مقابل الخاسرة)       |
//+------------------------------------------------------------------+
void CheckBasketOverlap()
{
   double totalProfit = 0;
   int totalPositions = PositionsTotal();

   // حساب الصافي الإجمالي لصفقات البوت الحالية (الرابحة والخاسرة معاً)
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }

   // إذا كان صافي الربح الإجمالي للسلة أكبر من الهدف (مثلاً 1.50 دولار)، يتم عمل الأوفرلاب فوراً
   if(totalProfit >= InpBasketTargetProfit)
   {
      for(int i = totalPositions - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket); // إغلاق الصفقات كلها رابح وخاسر معاً
         }
      }
      Print("✅ تم نجاح الأوفرلاب! إغلاق السلة بالكامل بربح صافي: ", totalProfit, " $");
   }
}

//+------------------------------------------------------------------+
//| دالة حساب عدد صفقات البوت المفتوحة حالياً                        |
//+------------------------------------------------------------------+
int CountCurrentPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| دالة حساب الأرباح والخسائر المغلقة اليوم لتفعيل حماية الحساب     |
//+------------------------------------------------------------------+
double CalculateDailyProfitLoss()
{
   double dailyProfit = 0;
   datetime countFrom = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(HistorySelect(countFrom, TimeCurrent()))
   {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            dailyProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
      }
   }
   return dailyProfit;
}
