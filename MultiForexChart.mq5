//+------------------------------------------------------------------+
//|                                              MultiForexChart.mq5 |
//|                        10 Forex Pairs on One Chart - MT5         |
//|                     Normalized % Change Overlay Indicator         |
//+------------------------------------------------------------------+
#property copyright   "MultiForexChart"
#property link        ""
#property version     "1.00"
#property description "Displays 10 forex pairs on a single chart using normalized percentage change"
#property indicator_chart_window
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   10

#property indicator_label1  "EURUSD"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "GBPUSD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "USDJPY"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "USDCHF"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGold
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "AUDUSD"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

#property indicator_label6  "NZDUSD"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrOrange
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

#property indicator_label7  "USDCAD"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCyan
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

#property indicator_label8  "EURJPY"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrWhite
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

#property indicator_label9  "GBPJPY"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrYellow
#property indicator_style9  STYLE_SOLID
#property indicator_width9  2

#property indicator_label10 "EURGBP"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrViolet
#property indicator_style10 STYLE_SOLID
#property indicator_width10 2

//--- input parameters
input string Pair1  = "EURUSD";   // Pair 1
input string Pair2  = "GBPUSD";   // Pair 2
input string Pair3  = "USDJPY";   // Pair 3
input string Pair4  = "USDCHF";   // Pair 4
input string Pair5  = "AUDUSD";   // Pair 5
input string Pair6  = "NZDUSD";   // Pair 6
input string Pair7  = "USDCAD";   // Pair 7
input string Pair8  = "EURJPY";   // Pair 8
input string Pair9  = "GBPJPY";   // Pair 9
input string Pair10 = "EURGBP";   // Pair 10
input int    BaseBars = 100;      // Number of bars for base price (0 = first bar)

//--- indicator buffers
double Buffer1[];
double Buffer2[];
double Buffer3[];
double Buffer4[];
double Buffer5[];
double Buffer6[];
double Buffer7[];
double Buffer8[];
double Buffer9[];
double Buffer10[];

string pairs[10];
double basePrice[10];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, Buffer1, INDICATOR_DATA);
   SetIndexBuffer(1, Buffer2, INDICATOR_DATA);
   SetIndexBuffer(2, Buffer3, INDICATOR_DATA);
   SetIndexBuffer(3, Buffer4, INDICATOR_DATA);
   SetIndexBuffer(4, Buffer5, INDICATOR_DATA);
   SetIndexBuffer(5, Buffer6, INDICATOR_DATA);
   SetIndexBuffer(6, Buffer7, INDICATOR_DATA);
   SetIndexBuffer(7, Buffer8, INDICATOR_DATA);
   SetIndexBuffer(8, Buffer9, INDICATOR_DATA);
   SetIndexBuffer(9, Buffer10, INDICATOR_DATA);

   pairs[0] = Pair1;
   pairs[1] = Pair2;
   pairs[2] = Pair3;
   pairs[3] = Pair4;
   pairs[4] = Pair5;
   pairs[5] = Pair6;
   pairs[6] = Pair7;
   pairs[7] = Pair8;
   pairs[8] = Pair9;
   pairs[9] = Pair10;

   for(int i = 0; i < 10; i++)
      basePrice[i] = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, "Multi Forex (10 Pairs % Change)");
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   for(int i = 0; i < 10; i++)
     {
      PlotIndexSetString(i, PLOT_LABEL, pairs[i]);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Get close price for a symbol at a given bar                       |
//+------------------------------------------------------------------+
double GetClosePrice(string symbol, int shift)
  {
   double close[];
   if(CopyClose(symbol, Period(), shift, 1, close) == 1)
      return close[0];
   return 0;
  }

//+------------------------------------------------------------------+
//| Set buffer value by index                                         |
//+------------------------------------------------------------------+
void SetBufferValue(int bufferIndex, int bar, double value)
  {
   switch(bufferIndex)
     {
      case 0: Buffer1[bar]  = value; break;
      case 1: Buffer2[bar]  = value; break;
      case 2: Buffer3[bar]  = value; break;
      case 3: Buffer4[bar]  = value; break;
      case 4: Buffer5[bar]  = value; break;
      case 5: Buffer6[bar]  = value; break;
      case 6: Buffer7[bar]  = value; break;
      case 7: Buffer8[bar]  = value; break;
      case 8: Buffer9[bar]  = value; break;
      case 9: Buffer10[bar] = value; break;
     }
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int start;

   if(prev_calculated == 0)
     {
      start = 0;
      int baseBar = (BaseBars > 0 && BaseBars < rates_total) ? rates_total - BaseBars : 0;

      for(int i = 0; i < 10; i++)
        {
         basePrice[i] = GetClosePrice(pairs[i], rates_total - 1 - baseBar);
         if(basePrice[i] == 0)
           {
            Print("Warning: Could not get base price for ", pairs[i],
                  ". Make sure the symbol exists in Market Watch.");
           }
        }
     }
   else
     {
      start = prev_calculated - 1;
     }

   for(int bar = start; bar < rates_total; bar++)
     {
      int shift = rates_total - 1 - bar;

      for(int i = 0; i < 10; i++)
        {
         if(basePrice[i] == 0)
           {
            SetBufferValue(i, bar, EMPTY_VALUE);
            continue;
           }

         double currentClose = GetClosePrice(pairs[i], shift);
         if(currentClose == 0)
           {
            SetBufferValue(i, bar, EMPTY_VALUE);
            continue;
           }

         double pctChange = ((currentClose - basePrice[i]) / basePrice[i]) * 100.0;
         SetBufferValue(i, bar, pctChange);
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }
//+------------------------------------------------------------------+
