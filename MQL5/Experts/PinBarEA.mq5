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

//+------------------------------------------------------------------+
//|                    ألوان اللوحة والتصميم                          |
//+------------------------------------------------------------------+
#define DASH_BG_COLOR        C'18,22,36'
#define DASH_BORDER_COLOR    C'40,50,80'
#define DASH_HEADER_BG       C'25,32,58'
#define DASH_ACCENT_BLUE     C'59,130,246'
#define DASH_ACCENT_GREEN    C'34,197,94'
#define DASH_ACCENT_RED      C'239,68,68'
#define DASH_TEXT_PRIMARY    C'226,232,240'
#define DASH_TEXT_SECONDARY  C'148,163,184'
#define DASH_TEXT_MUTED      C'100,116,139'
#define DASH_DIVIDER_COLOR   C'45,55,85'
#define DASH_ROW_ALT         C'22,28,45'
#define DASH_BADGE_BUY_BG    C'20,60,30'
#define DASH_BADGE_SELL_BG   C'60,20,20'

#define DASH_PREFIX          "PB_DASH_"
#define DASH_FONT            "Segoe UI"
#define DASH_FONT_BOLD       "Segoe UI Semibold"
#define DASH_FONT_ARABIC     "Segoe UI"

//+------------------------------------------------------------------+
//|                    هيكل بيانات الإشارة                             |
//+------------------------------------------------------------------+
struct SignalRecord
  {
   datetime          time;
   string            type;
   double            entry;
   double            sl;
   double            tp;
   double            atr;
   double            volume_ratio;
   bool              active;
  };

//+------------------------------------------------------------------+
//|                كلاس لوحة المعلومات العربية                        |
//+------------------------------------------------------------------+
class CPinBarDashboard
  {
private:
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;
   bool              m_visible;
   bool              m_minimized;
   int               m_total_buy;
   int               m_total_sell;
   int               m_total_signals;
   double            m_win_rate;
   double            m_total_profit;
   SignalRecord      m_last_signals[10];
   int               m_signal_count;
   string            m_ea_status;
   color             m_status_color;

   void              CreatePanel();
   void              CreateRect(string name, int x, int y, int w, int h,
                                color bg, color border, int border_width);
   void              CreateLbl(string name, string text, int x, int y,
                               int font_size, color clr, string font,
                               ENUM_ANCHOR_POINT anchor);
   void              CreateDivider(string name, int x1, int y1, int x2, int y2, color clr);
   void              DrawHeader();
   void              DrawStatusSection();
   void              DrawFiltersSection(double ema_val, double atr_val,
                                        double vol_avg, double current_price);
   void              DrawStatsSection();
   void              DrawSignalHistory();
   void              DrawFooter();
   void              DeleteAllObjects();
   string            ObjName(string suffix);

public:
                     CPinBarDashboard();
                    ~CPinBarDashboard();
   void              Init(int x, int y);
   void              Update(double ema_val, double atr_val, double vol_avg,
                            double current_price, string status, color status_clr);
   void              AddSignal(SignalRecord &signal);
   void              UpdateStats(int buys, int sells, double win_rate, double profit);
   void              Toggle();
   void              Show();
   void              Hide();
   void              Destroy();
   bool              IsVisible() { return m_visible; }
   bool              OnClick(int x, int y);
  };

//+------------------------------------------------------------------+
CPinBarDashboard::CPinBarDashboard()
  {
   m_x = 20;
   m_y = 30;
   m_width = 340;
   m_height = 620;
   m_visible = true;
   m_minimized = false;
   m_total_buy = 0;
   m_total_sell = 0;
   m_total_signals = 0;
   m_win_rate = 0;
   m_total_profit = 0;
   m_signal_count = 0;
   m_ea_status = "جاهز";
   m_status_color = DASH_ACCENT_BLUE;
   for(int i = 0; i < 10; i++)
     {
      m_last_signals[i].time = 0;
      m_last_signals[i].type = "";
      m_last_signals[i].entry = 0;
      m_last_signals[i].sl = 0;
      m_last_signals[i].tp = 0;
      m_last_signals[i].atr = 0;
      m_last_signals[i].volume_ratio = 0;
      m_last_signals[i].active = false;
     }
  }

//+------------------------------------------------------------------+
CPinBarDashboard::~CPinBarDashboard()
  {
   Destroy();
  }

//+------------------------------------------------------------------+
string CPinBarDashboard::ObjName(string suffix)
  {
   return DASH_PREFIX + suffix;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Init(int x, int y)
  {
   m_x = x;
   m_y = y;
   CreatePanel();
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::CreateRect(string name, int x, int y, int w, int h,
                                   color bg, color border, int border_width)
  {
   string obj_name = ObjName(name);
   ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::CreateLbl(string name, string text, int x, int y,
                                  int font_size, color clr, string font,
                                  ENUM_ANCHOR_POINT anchor)
  {
   string obj_name = ObjName(name);
   ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetString(0, obj_name, OBJPROP_FONT, font);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::CreateDivider(string name, int x1, int y1, int x2, int y2, color clr)
  {
   string obj_name = ObjName(name);
   ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, x2 - x1);
   ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_COLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::CreatePanel()
  {
   DeleteAllObjects();
   if(m_minimized)
     {
      CreateRect("main_bg", m_x, m_y, m_width, 42, DASH_BG_COLOR, DASH_BORDER_COLOR, 2);
      CreateRect("header_bg", m_x, m_y, m_width, 42, DASH_HEADER_BG, DASH_ACCENT_BLUE, 2);
      CreateLbl("title", "نظام ذيول الشموع", m_x + m_width / 2, m_y + 12,
                11, DASH_TEXT_PRIMARY, DASH_FONT_BOLD, ANCHOR_UPPER);
      CreateLbl("toggle_btn", "+", m_x + m_width - 25, m_y + 10,
                14, DASH_TEXT_PRIMARY, DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);
      return;
     }
   CreateRect("main_bg", m_x, m_y, m_width, m_height, DASH_BG_COLOR, DASH_BORDER_COLOR, 2);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawHeader()
  {
   int hx = m_x;
   int hy = m_y;
   CreateRect("header_bg", hx, hy, m_width, 50, DASH_HEADER_BG, DASH_ACCENT_BLUE, 2);
   CreateLbl("title", "نظام ذيول الشموع", hx + m_width / 2, hy + 8,
             13, clrWhite, DASH_FONT_BOLD, ANCHOR_UPPER);
   CreateLbl("subtitle", "Pin Bar Trading System - M1", hx + m_width / 2, hy + 28,
             8, DASH_TEXT_MUTED, DASH_FONT, ANCHOR_UPPER);
   CreateLbl("toggle_btn", "\x2013", hx + m_width - 25, hy + 12,
             14, DASH_TEXT_PRIMARY, DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawStatusSection()
  {
   int sy = m_y + 58;
   CreateRect("status_bg", m_x + 10, sy, m_width - 20, 36,
              DASH_ROW_ALT, DASH_DIVIDER_COLOR, 1);
   CreateLbl("status_dot", "\x25CF", m_x + 22, sy + 10, 10,
             m_status_color, DASH_FONT, ANCHOR_LEFT_UPPER);
   CreateLbl("status_label", ":الحالة", m_x + m_width - 22, sy + 10,
             10, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);
   CreateLbl("status_val", m_ea_status, m_x + m_width - 70, sy + 10,
             10, m_status_color, DASH_FONT_BOLD, ANCHOR_RIGHT_UPPER);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawFiltersSection(double ema_val, double atr_val,
                                           double vol_avg, double current_price)
  {
   int fy = m_y + 102;
   CreateLbl("filters_title", "الفلاتر والمؤشرات", m_x + m_width - 18, fy,
             10, DASH_ACCENT_BLUE, DASH_FONT_BOLD, ANCHOR_RIGHT_UPPER);
   CreateDivider("filters_line", m_x + 15, fy + 18, m_x + m_width - 15, fy + 18,
                 DASH_DIVIDER_COLOR);

   int row_h = 26;
   int ry = fy + 25;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   string labels[4];
   labels[0] = "السعر الحالي";
   labels[1] = "(EMA) المتوسط المتحرك";
   labels[2] = "(ATR) مؤشر التقلب";
   labels[3] = "متوسط الحجم";

   string values[4];
   values[0] = DoubleToString(current_price, digits);
   values[1] = DoubleToString(ema_val, digits);
   values[2] = DoubleToString(atr_val, digits);
   values[3] = DoubleToString(vol_avg, 0);

   color val_colors[4];
   val_colors[0] = (current_price > ema_val) ? DASH_ACCENT_GREEN : DASH_ACCENT_RED;
   val_colors[1] = (current_price > ema_val) ? DASH_ACCENT_GREEN : DASH_ACCENT_RED;
   val_colors[2] = DASH_TEXT_PRIMARY;
   val_colors[3] = DASH_TEXT_PRIMARY;

   for(int i = 0; i < 4; i++)
     {
      color bg = (i % 2 == 0) ? DASH_ROW_ALT : DASH_BG_COLOR;
      CreateRect("frow_" + IntegerToString(i), m_x + 10, ry, m_width - 20, row_h,
                 bg, bg, 0);
      CreateLbl("flbl_" + IntegerToString(i), labels[i], m_x + m_width - 20, ry + 5,
                9, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);
      CreateLbl("fval_" + IntegerToString(i), values[i], m_x + 20, ry + 5,
                9, val_colors[i], DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);
      ry += row_h;
     }

   string trend_text;
   color  trend_clr;
   color  trend_bg;
   if(current_price > ema_val)
     {
      trend_text = "صاعد \x25B2";
      trend_clr  = DASH_ACCENT_GREEN;
      trend_bg   = DASH_BADGE_BUY_BG;
     }
   else
     {
      trend_text = "هابط \x25BC";
      trend_clr  = DASH_ACCENT_RED;
      trend_bg   = DASH_BADGE_SELL_BG;
     }
   CreateRect("trend_badge", m_x + 15, ry + 2, 80, 22, trend_bg, trend_clr, 1);
   CreateLbl("trend_text", trend_text, m_x + 55, ry + 5,
             9, trend_clr, DASH_FONT_BOLD, ANCHOR_UPPER);
   CreateLbl("trend_label", "الاتجاه", m_x + m_width - 20, ry + 5,
             9, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawStatsSection()
  {
   int sy = m_y + 290;
   CreateLbl("stats_title", "إحصائيات الأداء", m_x + m_width - 18, sy,
             10, DASH_ACCENT_BLUE, DASH_FONT_BOLD, ANCHOR_RIGHT_UPPER);
   CreateDivider("stats_line", m_x + 15, sy + 18, m_x + m_width - 15, sy + 18,
                 DASH_DIVIDER_COLOR);

   int box_w = (m_width - 40) / 2;
   int bx1 = m_x + 10;
   int bx2 = m_x + 10 + box_w + 10;
   int by = sy + 26;

   CreateRect("stat_buy_bg", bx1, by, box_w, 55, DASH_BADGE_BUY_BG, DASH_ACCENT_GREEN, 1);
   CreateLbl("stat_buy_num", IntegerToString(m_total_buy), bx1 + box_w / 2, by + 6,
             18, DASH_ACCENT_GREEN, DASH_FONT_BOLD, ANCHOR_UPPER);
   CreateLbl("stat_buy_lbl", "صفقات شراء", bx1 + box_w / 2, by + 32,
             8, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_UPPER);

   CreateRect("stat_sell_bg", bx2, by, box_w, 55, DASH_BADGE_SELL_BG, DASH_ACCENT_RED, 1);
   CreateLbl("stat_sell_num", IntegerToString(m_total_sell), bx2 + box_w / 2, by + 6,
             18, DASH_ACCENT_RED, DASH_FONT_BOLD, ANCHOR_UPPER);
   CreateLbl("stat_sell_lbl", "صفقات بيع", bx2 + box_w / 2, by + 32,
             8, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_UPPER);

   int ry = by + 65;
   CreateRect("stat_wr_bg", m_x + 10, ry, m_width - 20, 30,
              DASH_ROW_ALT, DASH_DIVIDER_COLOR, 1);
   CreateLbl("stat_wr_lbl", "نسبة النجاح", m_x + m_width - 20, ry + 7,
             9, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);
   color wr_clr = (m_win_rate >= 50) ? DASH_ACCENT_GREEN : DASH_ACCENT_RED;
   CreateLbl("stat_wr_val", DoubleToString(m_win_rate, 1) + "%", m_x + 20, ry + 7,
             10, wr_clr, DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);

   ry += 32;
   CreateRect("stat_pnl_bg", m_x + 10, ry, m_width - 20, 30,
              DASH_BG_COLOR, DASH_DIVIDER_COLOR, 1);
   CreateLbl("stat_pnl_lbl", "إجمالي الأرباح", m_x + m_width - 20, ry + 7,
             9, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);
   color pnl_clr = (m_total_profit >= 0) ? DASH_ACCENT_GREEN : DASH_ACCENT_RED;
   string pnl_prefix = (m_total_profit >= 0) ? "+" : "";
   CreateLbl("stat_pnl_val", pnl_prefix + DoubleToString(m_total_profit, 2),
             m_x + 20, ry + 7,
             10, pnl_clr, DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawSignalHistory()
  {
   int sy = m_y + 455;
   CreateLbl("hist_title", "آخر الإشارات", m_x + m_width - 18, sy,
             10, DASH_ACCENT_BLUE, DASH_FONT_BOLD, ANCHOR_RIGHT_UPPER);
   CreateDivider("hist_line", m_x + 15, sy + 18, m_x + m_width - 15, sy + 18,
                 DASH_DIVIDER_COLOR);

   int ry = sy + 24;
   int row_h = 22;
   int count = MathMin(m_signal_count, 5);

   if(count == 0)
     {
      CreateLbl("hist_empty", "...لا توجد إشارات بعد", m_x + m_width / 2, ry + 10,
                9, DASH_TEXT_MUTED, DASH_FONT_ARABIC, ANCHOR_UPPER);
      return;
     }

   for(int i = 0; i < count; i++)
     {
      int idx = m_signal_count - 1 - i;
      if(idx < 0)
         break;
      int arr_idx = idx % 10;
      color bg = (i % 2 == 0) ? DASH_ROW_ALT : DASH_BG_COLOR;
      CreateRect("hrow_" + IntegerToString(i), m_x + 10, ry, m_width - 20, row_h,
                 bg, bg, 0);

      bool is_buy = (m_last_signals[arr_idx].type == "شراء");
      color sig_clr = is_buy ? DASH_ACCENT_GREEN : DASH_ACCENT_RED;
      string sig_icon = is_buy ? "\x25B2" : "\x25BC";

      CreateLbl("hsig_" + IntegerToString(i),
                sig_icon + " " + m_last_signals[arr_idx].type,
                m_x + m_width - 20, ry + 3,
                8, sig_clr, DASH_FONT_BOLD, ANCHOR_RIGHT_UPPER);

      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      CreateLbl("hprc_" + IntegerToString(i),
                DoubleToString(m_last_signals[arr_idx].entry, dg),
                m_x + m_width / 2, ry + 3,
                8, DASH_TEXT_PRIMARY, DASH_FONT, ANCHOR_UPPER);

      CreateLbl("htim_" + IntegerToString(i),
                TimeToString(m_last_signals[arr_idx].time, TIME_MINUTES),
                m_x + 20, ry + 3,
                8, DASH_TEXT_MUTED, DASH_FONT, ANCHOR_LEFT_UPPER);
      ry += row_h;
     }
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DrawFooter()
  {
   int fy = m_y + m_height - 25;
   CreateDivider("footer_line", m_x + 15, fy, m_x + m_width - 15, fy, DASH_DIVIDER_COLOR);
   CreateLbl("footer_text", "Pin Bar EA v1.0 | " + _Symbol + " | " +
             TimeToString(TimeCurrent(), TIME_MINUTES),
             m_x + m_width / 2, fy + 5,
             7, DASH_TEXT_MUTED, DASH_FONT, ANCHOR_UPPER);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Update(double ema_val, double atr_val, double vol_avg,
                               double current_price, string status, color status_clr)
  {
   if(!m_visible)
      return;
   m_ea_status = status;
   m_status_color = status_clr;
   DeleteAllObjects();
   CreatePanel();
   if(!m_minimized)
     {
      DrawHeader();
      DrawStatusSection();
      DrawFiltersSection(ema_val, atr_val, vol_avg, current_price);
      DrawStatsSection();
      DrawSignalHistory();
      DrawFooter();
     }
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::AddSignal(SignalRecord &signal)
  {
   int idx = m_signal_count % 10;
   m_last_signals[idx] = signal;
   m_signal_count++;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::UpdateStats(int buys, int sells, double win_rate, double profit)
  {
   m_total_buy = buys;
   m_total_sell = sells;
   m_total_signals = buys + sells;
   m_win_rate = win_rate;
   m_total_profit = profit;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Toggle()       { m_minimized = !m_minimized; }
void CPinBarDashboard::Show()         { m_visible = true; }
void CPinBarDashboard::Hide()         { m_visible = false; DeleteAllObjects(); ChartRedraw(0); }
void CPinBarDashboard::Destroy()      { DeleteAllObjects(); }

//+------------------------------------------------------------------+
bool CPinBarDashboard::OnClick(int x, int y)
  {
   int btn_x = m_x + m_width - 30;
   int btn_y = m_y + 8;
   if(x >= btn_x && x <= btn_x + 25 && y >= btn_y && y <= btn_y + 25)
     {
      Toggle();
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::DeleteAllObjects()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, DASH_PREFIX) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//|              المدخلات الخارجية - الفلاتر                          |
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
//|                     متغيرات عامة                                  |
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
//| حساب متوسط الحجم يدوياً                                          |
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
//| الحصول على حجم شمعة معينة                                        |
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
                         size_ok && volume_ok &&
                         (close1 > buf_ema[1]);

   bool is_bearish_pin = body_ok &&
                         (upper_ratio >= InpMinTailRatio) &&
                         size_ok && volume_ok &&
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
            " | TP: ", DoubleToString(tp, digits));
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
            " | TP: ", DoubleToString(tp, digits));
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
