//+------------------------------------------------------------------+
//| PinBarEA.mq5                                                     |
//| إكسبيرت تداول ذيول الشموع - فريم الدقيقة                        |
//| Pin Bar Trading System with Arabic Dashboard                     |
//+------------------------------------------------------------------+
#property copyright   "Pin Bar EA"
#property version     "1.20"
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
   bool              m_dirty;
   int               m_total_buy;
   int               m_total_sell;
   int               m_total_signals;
   double            m_win_rate;
   double            m_total_profit;
   SignalRecord      m_last_signals[10];
   int               m_signal_count;
   string            m_ea_status;
   color             m_status_color;
   datetime          m_last_update;

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
   bool              NeedsUpdate();
   void              Update(double ema_val, double atr_val, double vol_avg,
                            double current_price, string status, color status_clr);
   void              AddSignal(SignalRecord &signal);
   void              UpdateStats(int buys, int sells, double win_rate, double profit);
   void              Toggle();
   void              Show();
   void              Hide();
   void              Destroy();
   bool              IsVisible()  { return m_visible;    }
   bool              OnClick(int x, int y);
  };

//+------------------------------------------------------------------+
CPinBarDashboard::CPinBarDashboard()
  {
   m_x             = 20;
   m_y             = 30;
   m_width         = 340;
   m_height        = 620;
   m_visible       = true;
   m_minimized     = false;
   m_dirty         = false;
   m_total_buy     = 0;
   m_total_sell    = 0;
   m_total_signals = 0;
   m_win_rate      = 0;
   m_total_profit  = 0;
   m_signal_count  = 0;
   m_ea_status     = "جاهز";
   m_status_color  = DASH_ACCENT_BLUE;
   m_last_update   = 0;
   for(int i = 0; i < 10; i++)
     {
      m_last_signals[i].time         = 0;
      m_last_signals[i].type         = "";
      m_last_signals[i].entry        = 0;
      m_last_signals[i].sl           = 0;
      m_last_signals[i].tp           = 0;
      m_last_signals[i].atr          = 0;
      m_last_signals[i].volume_ratio = 0;
      m_last_signals[i].active       = false;
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
   DeleteAllObjects();
   CreatePanel();
  }

//+------------------------------------------------------------------+
bool CPinBarDashboard::NeedsUpdate()
  {
   datetime now = TimeCurrent();
   if(now - m_last_update < 1)
      return false;
   m_last_update = now;
   return true;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::CreateRect(string name, int x, int y, int w, int h,
                                   color bg, color border, int border_width)
  {
   string obj_name = ObjName(name);
   if(ObjectFind(0, obj_name) < 0)
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
   if(ObjectFind(0, obj_name) < 0)
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
   if(ObjectFind(0, obj_name) < 0)
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

   int row_h  = 26;
   int ry     = fy + 25;
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
   if(current_price > ema_val)
     {
      val_colors[0] = DASH_ACCENT_GREEN;
      val_colors[1] = DASH_ACCENT_GREEN;
     }
   else
     {
      val_colors[0] = DASH_ACCENT_RED;
      val_colors[1] = DASH_ACCENT_RED;
     }
   val_colors[2] = DASH_TEXT_PRIMARY;
   val_colors[3] = DASH_TEXT_PRIMARY;

   for(int i = 0; i < 4; i++)
     {
      color bg;
      if(i % 2 == 0)
         bg = DASH_ROW_ALT;
      else
         bg = DASH_BG_COLOR;

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
   int bx1   = m_x + 10;
   int bx2   = m_x + 10 + box_w + 10;
   int by    = sy + 26;

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

   color wr_clr;
   if(m_win_rate >= 50)
      wr_clr = DASH_ACCENT_GREEN;
   else
      wr_clr = DASH_ACCENT_RED;

   CreateLbl("stat_wr_val", DoubleToString(m_win_rate, 1) + "%", m_x + 20, ry + 7,
             10, wr_clr, DASH_FONT_BOLD, ANCHOR_LEFT_UPPER);

   ry += 32;
   CreateRect("stat_pnl_bg", m_x + 10, ry, m_width - 20, 30,
              DASH_BG_COLOR, DASH_DIVIDER_COLOR, 1);
   CreateLbl("stat_pnl_lbl", "إجمالي الأرباح", m_x + m_width - 20, ry + 7,
             9, DASH_TEXT_SECONDARY, DASH_FONT_ARABIC, ANCHOR_RIGHT_UPPER);

   color pnl_clr;
   if(m_total_profit >= 0)
      pnl_clr = DASH_ACCENT_GREEN;
   else
      pnl_clr = DASH_ACCENT_RED;

   string pnl_prefix = "";
   if(m_total_profit >= 0)
      pnl_prefix = "+";

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

   int ry    = sy + 24;
   int row_h = 22;
   int count = m_signal_count;
   if(count > 5)
      count = 5;

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

      color bg;
      if(i % 2 == 0)
         bg = DASH_ROW_ALT;
      else
         bg = DASH_BG_COLOR;

      CreateRect("hrow_" + IntegerToString(i), m_x + 10, ry, m_width - 20, row_h,
                 bg, bg, 0);

      bool is_buy = (m_last_signals[arr_idx].type == "شراء");

      color sig_clr;
      if(is_buy)
         sig_clr = DASH_ACCENT_GREEN;
      else
         sig_clr = DASH_ACCENT_RED;

      string sig_icon;
      if(is_buy)
         sig_icon = "\x25B2";
      else
         sig_icon = "\x25BC";

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
   CreateLbl("footer_text", "Pin Bar EA v1.2 | " + _Symbol + " | " +
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
   m_ea_status    = status;
   m_status_color = status_clr;
   if(m_dirty)
     {
      DeleteAllObjects();
      m_dirty = false;
     }
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
   m_dirty = true;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::UpdateStats(int buys, int sells, double win_rate, double profit)
  {
   m_total_buy     = buys;
   m_total_sell    = sells;
   m_total_signals = buys + sells;
   m_win_rate      = win_rate;
   m_total_profit  = profit;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Toggle()
  {
   m_minimized = !m_minimized;
   m_dirty     = true;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Show()
  {
   m_visible = true;
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Hide()
  {
   m_visible = false;
   DeleteAllObjects();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void CPinBarDashboard::Destroy()
  {
   DeleteAllObjects();
  }

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
input bool   InpAdaptive        = false;  // عتبات تكيفية حسب حجم الشمعة / ATR

input group "══════ إعدادات الفلاتر ══════"
input int    InpTrendEMA        = 50;     // فترة المتوسط المتحرك (EMA)
input int    InpVolumePeriod    = 20;     // فترة متوسط حجم التداول
input double InpVolumeMulti     = 1.3;    // مضاعف الحجم (130%)
input int    InpATRPeriod       = 14;     // فترة مؤشر ATR
input bool   InpUseHTF          = false;  // تأكيد الاتجاه من فريم أعلى
input ENUM_TIMEFRAMES InpHTF    = PERIOD_M15; // الفريم الأعلى
input int    InpHTFEMA          = 50;     // فترة EMA للفريم الأعلى
input bool   InpUseLevel        = false;  // اشتراط مستوى (قاع/قمة قريبة أو اليوم السابق)
input int    InpLevelLookback   = 30;     // عدد الشموع للبحث عن القاع/القمة
input double InpLevelTolATR     = 0.5;    // سماحية قرب المستوى (× ATR)

input group "══════ فلتر الجلسات والأخبار ══════"
input bool   InpUseSession      = false;  // تفعيل فلتر الجلسة (بتوقيت السيرفر)
input int    InpSessionStartHour= 7;      // بداية الجلسة (ساعة السيرفر)
input int    InpSessionEndHour  = 20;     // نهاية الجلسة (ساعة السيرفر)
input int    InpAvoidEdgeMin    = 15;     // تجنب أول وآخر دقائق الجلسة
input bool   InpUseNews         = false;  // إيقاف حول الأخبار عالية التأثير
input int    InpNewsMinBefore   = 15;     // دقائق قبل الخبر
input int    InpNewsMinAfter    = 15;     // دقائق بعد الخبر

input group "══════ إدارة المخاطر ══════"
input bool   InpUseRiskPercent  = true;   // حجم العقد بنسبة مخاطرة من الرصيد
input double InpRiskPercent     = 0.5;    // نسبة المخاطرة لكل صفقة (%)
input double InpLotSize         = 0.01;   // حجم العقد الثابت (إذا أُلغيت النسبة)
input double InpMaxLot          = 1.0;    // الحد الأقصى لحجم العقد
input double InpRiskReward      = 2.0;    // نسبة العائد للمخاطرة (1:X)
input double InpSLBufferPips    = 2.0;    // هامش وقف الخسارة (Pips)
input double InpSLBufferATR     = 0.15;   // هامش وقف الخسارة (× ATR) - يُؤخذ الأكبر
input bool   InpAdjustStops     = true;   // توسيع الوقف تلقائيًا إلى حد STOPS_LEVEL
input int    InpMaxSpread       = 30;     // الحد الأقصى للسبريد (نقاط)
input double InpMaxSpreadRisk   = 0.15;   // الحد الأقصى للسبريد كنسبة من المخاطرة
input int    InpMagicNumber     = 202501; // الرقم السحري للصفقات
input int    InpMaxOpenTrades   = 3;      // الحد الأقصى للصفقات المفتوحة
input int    InpMinBarsBetween  = 5;      // أقل عدد شموع بين صفقتين بنفس الاتجاه
input int    InpMaxRetries      = 2;      // إعادة المحاولة عند requote / تأخر

input group "══════ حماية الحساب ══════"
input double InpMaxDailyLossPct = 3.0;    // حد الخسارة اليومي (% من رصيد بداية اليوم) - 0 للتعطيل
input double InpMaxDrawdownPct  = 10.0;   // إيقاف دائم عند سحب من أعلى رصيد (%) - 0 للتعطيل
input int    InpMaxConsecLoss   = 3;      // عدد الخسائر المتتالية للإيقاف المؤقت - 0 للتعطيل
input int    InpPauseMinutes    = 60;     // مدة الإيقاف المؤقت (دقائق)
input bool   InpResetHalt       = false;  // إعادة ضبط الإيقاف الدائم وأعلى رصيد (فعّلها مرة واحدة)

input group "══════ إدارة الصفقة المفتوحة ══════"
input bool   InpUseBE           = true;   // نقل الوقف إلى التعادل
input double InpBE_R            = 1.0;    // مستوى التفعيل (× المخاطرة الأصلية)
input double InpBEOffsetPips    = 1.0;    // إزاحة فوق/تحت سعر الدخول (Pips)
input bool   InpUseTrail        = false;  // وقف متحرك بـ ATR
input double InpTrailStartR     = 1.5;    // بداية الوقف المتحرك (× المخاطرة)
input double InpTrailATR        = 1.0;    // مسافة الوقف المتحرك (× ATR)

input group "══════ التنبيهات والتسجيل ══════"
input bool   InpAlertSound      = true;   // تنبيه صوتي
input bool   InpAlertPush       = true;   // إشعار الهاتف
input bool   InpAlertPopup      = true;   // نافذة تنبيه
input bool   InpTelegram        = false;  // تنبيهات Telegram
input string InpTelegramToken   = "";     // Telegram Bot Token
input string InpTelegramChat    = "";     // Telegram Chat ID
input bool   InpLogCsv          = true;   // تسجيل الصفقات في ملف CSV
input string InpCsvName         = "PinBarEA_trades.csv"; // اسم الملف (مجلد Common\Files)

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
int               h_htf;

double            buf_ema[];
double            buf_atr[];
double            buf_htf[];

int               g_total_buy;
int               g_total_sell;
int               g_wins;
int               g_losses;
int               g_consec_losses;
double            g_total_profit;

datetime          g_last_buy_bar;
datetime          g_last_sell_bar;
datetime          g_pause_until;
datetime          g_daily_notified_day;
datetime          g_last_err_notify;
double            g_peak_equity;
double            g_last_atr;
bool              g_halted;
string            g_block_reason;

//+------------------------------------------------------------------+
//| أدوات مساعدة                                                       |
//+------------------------------------------------------------------+
string HaltKey()
  {
   return "PBEA_HALT_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +
          "_" + IntegerToString(InpMagicNumber);
  }

string PeakKey()
  {
   return "PBEA_PEAK_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +
          "_" + IntegerToString(InpMagicNumber);
  }

double PipSize()
  {
   int    d = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double p = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(d == 3 || d == 5)
      return p * 10.0;
   return p;
  }

datetime DayStart()
  {
   return StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
  }

double DealNet(ulong ticket)
  {
   return HistoryDealGetDouble(ticket, DEAL_PROFIT)
        + HistoryDealGetDouble(ticket, DEAL_SWAP)
        + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
  }

//+------------------------------------------------------------------+
//| كشف نوع التعبئة المناسب للبروكر                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING DetectFilling()
  {
   long filling_mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

   if((filling_mode & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;

   if((filling_mode & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
  }

//+------------------------------------------------------------------+
//| Telegram                                                          |
//+------------------------------------------------------------------+
string UrlEncode(string text)
  {
   uchar bytes[];
   int   n = StringToCharArray(text, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   string out = "";
   for(int i = 0; i < n - 1; i++)
     {
      uchar c = bytes[i];
      if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
         (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
         out += CharToString(c);
      else
         out += StringFormat("%%%02X", c);
     }
   return out;
  }

void SendTelegram(string text)
  {
   if(!InpTelegram || InpTelegramToken == "" || InpTelegramChat == "")
      return;
   if(MQLInfoInteger(MQL_TESTER))
      return;

   string url  = "https://api.telegram.org/bot" + InpTelegramToken + "/sendMessage";
   string body = "chat_id=" + InpTelegramChat + "&text=" + UrlEncode(text);
   char   post[];
   char   res[];
   string res_headers;
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   StringToCharArray(body, post, 0, StringLen(body));

   int code = WebRequest("POST", url, headers, 5000, post, res, res_headers);
   if(code == -1)
      Print("فشل إرسال Telegram: ", GetLastError(),
            " - أضف https://api.telegram.org إلى قائمة WebRequest المسموحة");
   else if(code != 200)
      Print("Telegram رد برمز: ", code);
  }

// تنبيه عام (حدود الخسارة والأخطاء)
void Notify(string msg)
  {
   Print(msg);
   SendTelegram(msg);
   if(InpAlertPush)
      SendNotification(msg);
  }

// تنبيه الأخطاء بحد أقصى مرة كل دقيقة لتجنب الإزعاج
void NotifyError(string msg)
  {
   Print(msg);
   if(TimeCurrent() - g_last_err_notify < 60)
      return;
   g_last_err_notify = TimeCurrent();
   SendTelegram(msg);
  }

//+------------------------------------------------------------------+
//| تسجيل CSV                                                         |
//+------------------------------------------------------------------+
void LogCsv(string event, datetime time, string type, ulong pos_id, double price,
            double sl, double tp, double lot, int spread, double risk,
            double atr, double vol_ratio, double profit, string reason)
  {
   if(!InpLogCsv)
      return;

   int h = FileOpen(InpCsvName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI |
                    FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE)
     {
      Print("تعذر فتح ملف CSV: ", GetLastError());
      return;
     }
   if(FileSize(h) == 0)
      FileWriteString(h, "event,time,symbol,type,position_id,price,sl,tp,lot,"
                         "spread_pts,risk_price,atr,vol_ratio,profit,reason,balance\r\n");
   FileSeek(h, 0, SEEK_END);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string line = event + "," +
                 TimeToString(time, TIME_DATE | TIME_SECONDS) + "," +
                 _Symbol + "," + type + "," +
                 IntegerToString((long)pos_id) + "," +
                 DoubleToString(price, digits) + "," +
                 DoubleToString(sl, digits) + "," +
                 DoubleToString(tp, digits) + "," +
                 DoubleToString(lot, 2) + "," +
                 IntegerToString(spread) + "," +
                 DoubleToString(risk, digits) + "," +
                 DoubleToString(atr, digits) + "," +
                 DoubleToString(vol_ratio, 2) + "," +
                 DoubleToString(profit, 2) + "," +
                 reason + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| إحصائيات الصفقات (تراكمية)                                        |
//+------------------------------------------------------------------+
void RegisterClosed(double profit, bool live)
  {
   g_total_profit += profit;
   if(profit > 0)
     {
      g_wins++;
      g_consec_losses = 0;
     }
   else if(profit < 0)
     {
      g_losses++;
      g_consec_losses++;
      if(live && InpMaxConsecLoss > 0 && g_consec_losses >= InpMaxConsecLoss)
        {
         g_pause_until = TimeCurrent() + InpPauseMinutes * 60;
         Notify("Pin Bar EA: " + IntegerToString(g_consec_losses) +
                " خسائر متتالية - إيقاف مؤقت " + IntegerToString(InpPauseMinutes) +
                " دقيقة (" + _Symbol + ")");
         g_consec_losses = 0;
        }
     }
  }

// حساب الإحصائيات مرة واحدة عند التشغيل
void InitStatsFromHistory()
  {
   g_total_buy     = 0;
   g_total_sell    = 0;
   g_wins          = 0;
   g_losses        = 0;
   g_consec_losses = 0;
   g_total_profit  = 0.0;

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
        {
         ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
         if(dt == DEAL_TYPE_BUY)
            g_total_buy++;
         else if(dt == DEAL_TYPE_SELL)
            g_total_sell++;
        }
      else if(entry == DEAL_ENTRY_OUT)
         RegisterClosed(DealNet(ticket), false);
     }
  }

double DailyClosedPnL()
  {
   if(!HistorySelect(DayStart(), TimeCurrent()))
      return 0;
   double sum = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      sum += DealNet(ticket);
     }
   return sum;
  }

double FloatingPnL()
  {
   double sum = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return sum;
  }

//+------------------------------------------------------------------+
//| فحص حدود الحساب - يعيد سبب المنع أو نصًا فارغًا                    |
//+------------------------------------------------------------------+
string CheckAccountLimits()
  {
   if(g_halted)
      return "متوقف: حد السحب الأقصى";

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peak_equity)
     {
      g_peak_equity = eq;
      GlobalVariableSet(PeakKey(), eq);
     }

   if(InpMaxDrawdownPct > 0 && g_peak_equity > 0 &&
      (g_peak_equity - eq) / g_peak_equity * 100.0 >= InpMaxDrawdownPct)
     {
      g_halted = true;
      GlobalVariableSet(HaltKey(), 1);
      Notify("Pin Bar EA: تم الإيقاف الدائم - بلغ السحب " +
             DoubleToString((g_peak_equity - eq) / g_peak_equity * 100.0, 1) +
             "% من أعلى رصيد. فعّل InpResetHalt لإعادة التشغيل.");
      return "متوقف: حد السحب الأقصى";
     }

   if(InpMaxDailyLossPct > 0)
     {
      double closed = DailyClosedPnL();
      double base   = AccountInfoDouble(ACCOUNT_BALANCE) - closed;
      double total  = closed + FloatingPnL();
      if(base > 0 && total <= -base * InpMaxDailyLossPct / 100.0)
        {
         if(g_daily_notified_day != DayStart())
           {
            g_daily_notified_day = DayStart();
            Notify("Pin Bar EA: بلغت الخسارة اليومية الحد المسموح (" +
                   DoubleToString(InpMaxDailyLossPct, 1) + "%) - لا صفقات جديدة اليوم");
           }
         return "متوقف: حد الخسارة اليومي";
        }
     }

   if(TimeCurrent() < g_pause_until)
      return "إيقاف مؤقت بعد خسائر متتالية";

   return "";
  }

//+------------------------------------------------------------------+
//| فلتر الجلسة                                                       |
//+------------------------------------------------------------------+
bool InSession()
  {
   if(!InpUseSession)
      return true;
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int mins = t.hour * 60 + t.min;
   int s    = InpSessionStartHour * 60 + InpAvoidEdgeMin;
   int e    = InpSessionEndHour * 60 - InpAvoidEdgeMin;
   if(s < e)
      return (mins >= s && mins < e);
   return (mins >= s || mins < e);
  }

//+------------------------------------------------------------------+
//| فلتر الأخبار (التقويم الاقتصادي المدمج في MT5)                     |
//+------------------------------------------------------------------+
bool IsNewsTime()
  {
   if(!InpUseNews)
      return false;

   string cur[2];
   cur[0] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   cur[1] = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   datetime now = TimeTradeServer();

   for(int i = 0; i < 2; i++)
     {
      if(cur[i] == "" || (i == 1 && cur[1] == cur[0]))
         continue;

      MqlCalendarValue vals[];
      if(!CalendarValueHistory(vals, now - InpNewsMinAfter * 60,
                               now + InpNewsMinBefore * 60, NULL, cur[i]))
         continue;

      for(int k = 0; k < ArraySize(vals); k++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[k].event_id, ev))
            continue;
         if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
            return true;
        }
     }
   return false;
  }

string GetBlockReason()
  {
   string r = CheckAccountLimits();
   if(r != "")
      return r;
   if(!InSession())
      return "خارج وقت الجلسة";
   if(IsNewsTime())
      return "إيقاف: خبر عالي التأثير";
   return "";
  }

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(Period() != PERIOD_M1)
      Print("تحذير: الإكسبيرت مصمم لفريم الدقيقة (M1). الفريم الحالي مختلف!");

   if(InpRiskReward <= 0 || InpRiskPercent <= 0 || InpLotSize <= 0)
     {
      Print("خطأ: قيم المخاطرة والعائد واللوت يجب أن تكون أكبر من صفر");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(DetectFilling());

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

   h_htf = INVALID_HANDLE;
   if(InpUseHTF)
     {
      h_htf = iMA(_Symbol, InpHTF, InpHTFEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(h_htf == INVALID_HANDLE)
        {
         Print("خطأ في إنشاء مؤشر EMA للفريم الأعلى: ", GetLastError());
         return INIT_FAILED;
        }
     }

   ArraySetAsSeries(buf_ema, true);
   ArraySetAsSeries(buf_atr, true);
   ArraySetAsSeries(buf_htf, true);

   g_last_buy_bar       = 0;
   g_last_sell_bar      = 0;
   g_pause_until        = 0;
   g_daily_notified_day = 0;
   g_last_err_notify    = 0;
   g_last_atr           = 0;
   g_block_reason       = "";

   if(InpResetHalt)
     {
      GlobalVariableDel(HaltKey());
      GlobalVariableDel(PeakKey());
     }
   g_halted = GlobalVariableCheck(HaltKey());
   g_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(GlobalVariableCheck(PeakKey()))
      g_peak_equity = MathMax(g_peak_equity, GlobalVariableGet(PeakKey()));
   GlobalVariableSet(PeakKey(), g_peak_equity);

   InitStatsFromHistory();

   if(InpShowDashboard)
      dashboard.Init(InpDashboardX, InpDashboardY);

   Print("══════════════════════════════════════════");
   Print("  نظام ذيول الشموع v1.2 - تم التشغيل بنجاح");
   Print("  الرمز: ", _Symbol, " | الإطار: M1");
   Print("  نوع التعبئة: ", EnumToString(DetectFilling()));
   if(g_halted)
      Print("  تحذير: الإكسبيرت في حالة إيقاف دائم (حد السحب). فعّل InpResetHalt لإعادة ضبطه.");
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
   if(h_htf != INVALID_HANDLE)
      IndicatorRelease(h_htf);

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
//| حساب متوسط الحجم                                                  |
//+------------------------------------------------------------------+
double CalcVolumeAverage(int period)
  {
   long vol_data[];
   ArraySetAsSeries(vol_data, true);
   int copied = CopyTickVolume(_Symbol, PERIOD_M1, 0, period + 2, vol_data);
   if(copied < period + 2)
      return 0;

   double sum = 0;
   for(int i = 1; i <= period; i++)
      sum += (double)vol_data[i];

   return sum / period;
  }

//+------------------------------------------------------------------+
//| الحصول على حجم شمعة معينة                                        |
//+------------------------------------------------------------------+
double GetBarVolume(int shift)
  {
   long vol_data[];
   ArraySetAsSeries(vol_data, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, shift + 2, vol_data) < shift + 2)
      return 0;
   return (double)vol_data[shift];
  }

//+------------------------------------------------------------------+
//| فلتر المستويات: قاع/قمة قريبة أو قاع/قمة اليوم السابق             |
//+------------------------------------------------------------------+
bool LevelOk(bool is_buy, double high1, double low1, double tol)
  {
   if(!InpUseLevel)
      return true;

   if(is_buy)
     {
      int idx = iLowest(_Symbol, PERIOD_M1, MODE_LOW, InpLevelLookback, 2);
      double swing = (idx >= 0) ? iLow(_Symbol, PERIOD_M1, idx) : 0;
      double pd    = iLow(_Symbol, PERIOD_D1, 1);
      return ((swing > 0 && low1 <= swing + tol) || (pd > 0 && low1 <= pd + tol));
     }

   int idx = iHighest(_Symbol, PERIOD_M1, MODE_HIGH, InpLevelLookback, 2);
   double swing = (idx >= 0) ? iHigh(_Symbol, PERIOD_M1, idx) : 0;
   double pd    = iHigh(_Symbol, PERIOD_D1, 1);
   return ((swing > 0 && high1 >= swing - tol) || (pd > 0 && high1 >= pd - tol));
  }

//+------------------------------------------------------------------+
//| تأكيد الفريم الأعلى                                               |
//+------------------------------------------------------------------+
bool HTFOk(bool is_buy)
  {
   if(!InpUseHTF)
      return true;
   if(CopyBuffer(h_htf, 0, 0, 3, buf_htf) < 3)
      return false;
   double htf_close = iClose(_Symbol, InpHTF, 1);
   if(htf_close <= 0)
      return false;
   return is_buy ? (htf_close > buf_htf[1]) : (htf_close < buf_htf[1]);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);

   ManagePositions();

   if(InpShowDashboard && dashboard.NeedsUpdate())
      UpdateDashboard();

   if(current_bar_time == last_bar_time)
      return;
   last_bar_time = current_bar_time;

   g_block_reason = GetBlockReason();

   if(CopyBuffer(h_ema, 0, 0, 3, buf_ema) < 3)
      return;
   if(CopyBuffer(h_atr, 0, 0, 3, buf_atr) < 3)
      return;
   g_last_atr = buf_atr[1];

   double vol_avg = CalcVolumeAverage(InpVolumePeriod);
   if(vol_avg <= 0)
      return;

   double vol1 = GetBarVolume(1);

   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double open1  = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);

   double total_range = high1 - low1;
   if(total_range <= 0 || buf_atr[1] <= 0)
      return;

   double body_size  = MathAbs(close1 - open1);
   double upper_tail = high1 - MathMax(open1, close1);
   double lower_tail = MathMin(open1, close1) - low1;

   double body_ratio  = body_size  / total_range;
   double upper_ratio = upper_tail / total_range;
   double lower_ratio = lower_tail / total_range;

   double eff_tail = InpMinTailRatio;
   double eff_body = InpMaxBodyRatio;
   if(InpAdaptive)
     {
      double r_atr = total_range / buf_atr[1];
      if(r_atr >= 2.0)
        {
         eff_tail -= 0.05;
         eff_body += 0.05;
        }
      else if(r_atr < 1.5)
        {
         eff_tail += 0.05;
         eff_body -= 0.05;
        }
     }

   bool size_ok   = (total_range >= buf_atr[1] * InpMinBarATR);
   bool body_ok   = (body_ratio  <= eff_body);
   bool volume_ok = (vol1 > vol_avg * InpVolumeMulti);

   int spread     = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool spread_ok = (spread <= InpMaxSpread);

   bool is_bullish_pin = body_ok &&
                         (lower_ratio >= eff_tail) &&
                         size_ok && volume_ok &&
                         (close1 > buf_ema[1]);

   bool is_bearish_pin = body_ok &&
                         (upper_ratio >= eff_tail) &&
                         size_ok && volume_ok &&
                         (close1 < buf_ema[1]);

   if(!is_bullish_pin && !is_bearish_pin)
      return;
   if(!spread_ok || g_block_reason != "" || !CanOpenTrade())
      return;

   double tol = InpLevelTolATR * buf_atr[1];
   int    bar_sec = PeriodSeconds(PERIOD_M1);

   if(is_bullish_pin && HTFOk(true) && LevelOk(true, high1, low1, tol) &&
      (g_last_buy_bar == 0 || (current_bar_time - g_last_buy_bar) / bar_sec >= InpMinBarsBetween))
     {
      if(ExecuteTrade(true, high1, low1, buf_atr[1], vol1 / vol_avg))
         g_last_buy_bar = current_bar_time;
     }

   if(is_bearish_pin && HTFOk(false) && LevelOk(false, high1, low1, tol) &&
      (g_last_sell_bar == 0 || (current_bar_time - g_last_sell_bar) / bar_sec >= InpMinBarsBetween))
     {
      if(ExecuteTrade(false, high1, low1, buf_atr[1], vol1 / vol_avg))
         g_last_sell_bar = current_bar_time;
     }
  }

//+------------------------------------------------------------------+
//| حساب حجم العقد (نسبة مخاطرة / ثابت) مع احترام حدود الوسيط والهامش  |
//+------------------------------------------------------------------+
double CalcLot(bool is_buy, double price, double sl)
  {
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0)
      step = 0.01;
   int lot_digits = (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9));

   ENUM_ORDER_TYPE otype = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double lot = InpLotSize;

   if(InpUseRiskPercent)
     {
      double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double loss_per_lot = 0;
      if(!OrderCalcProfit(otype, _Symbol, 1.0, price, sl, loss_per_lot) || loss_per_lot >= 0)
        {
         NotifyError("Pin Bar EA: تعذر حساب قيمة المخاطرة لـ " + _Symbol + " - تم تخطي الصفقة");
         return 0;
        }
      lot = risk_money / MathAbs(loss_per_lot);

      // إذا كان أقل لوت مسموح يتجاوز ضعف المخاطرة المطلوبة نتخطى الصفقة
      if(lot < min_lot)
        {
         if(min_lot * MathAbs(loss_per_lot) > 2.0 * risk_money)
           {
            Print("تخطي الصفقة: أقل لوت (", DoubleToString(min_lot, lot_digits),
                  ") يتجاوز ضعف المخاطرة المسموحة");
            return 0;
           }
         lot = min_lot;
        }
     }

   lot = MathMin(lot, InpMaxLot);
   lot = MathMin(lot, max_lot);
   lot = MathFloor(lot / step + 1e-9) * step;
   lot = NormalizeDouble(lot, lot_digits);
   if(lot < min_lot)
      lot = min_lot;

   // التحقق من الهامش الحر
   double margin = 0;
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(otype, _Symbol, lot, price, margin) && margin > free_margin * 0.9)
     {
      lot = MathFloor(lot * (free_margin * 0.9 / margin) / step) * step;
      lot = NormalizeDouble(lot, lot_digits);
      if(lot < min_lot)
        {
         NotifyError("Pin Bar EA: الهامش الحر غير كاف لفتح صفقة على " + _Symbol);
         return 0;
        }
     }
   return lot;
  }

//+------------------------------------------------------------------+
//| هل رمز الخطأ قابل لإعادة المحاولة                                 |
//+------------------------------------------------------------------+
bool IsRetriable(uint rc)
  {
   return (rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT ||
           rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_TOO_MANY_REQUESTS);
  }

//+------------------------------------------------------------------+
//| تنفيذ صفقة (شراء / بيع)                                           |
//+------------------------------------------------------------------+
bool ExecuteTrade(bool is_buy, double high1, double low1, double atr, double vol_ratio)
  {
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   long   stops_lvl  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long   freeze_lvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_dist   = (double)MathMax(stops_lvl, freeze_lvl) * point;

   double buffer = MathMax(InpSLBufferPips * PipSize(), InpSLBufferATR * atr);
   string dir    = is_buy ? "BUY" : "SELL";
   string dir_ar = is_buy ? "شراء" : "بيع";

   for(int attempt = 0; attempt <= InpMaxRetries; attempt++)
     {
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double price = is_buy ? ask : bid;

      double sl   = is_buy ? low1 - buffer : high1 + buffer;
      double risk = is_buy ? price - sl : sl - price;

      // احترام STOPS_LEVEL / FREEZE_LEVEL
      double need = min_dist + 2 * point;
      if(risk < need)
        {
         if(!InpAdjustStops)
           {
            Print("تخطي الصفقة: الوقف أقرب من STOPS_LEVEL");
            return false;
           }
         sl   = is_buy ? price - need : price + need;
         risk = need;
        }
      if(risk <= 0)
         return false;

      // السبريد مقارنة بالمخاطرة
      double spread_price = ask - bid;
      if(InpMaxSpreadRisk > 0 && spread_price > InpMaxSpreadRisk * risk)
        {
         Print("تخطي الصفقة: السبريد (", DoubleToString(spread_price, digits),
               ") كبير بالنسبة للمخاطرة (", DoubleToString(risk, digits), ")");
         return false;
        }

      sl = NormalizeDouble(sl, digits);
      double tp_dist = MathMax(risk * InpRiskReward, need);
      double tp = NormalizeDouble(is_buy ? price + tp_dist : price - tp_dist, digits);

      double lot = CalcLot(is_buy, price, sl);
      if(lot <= 0)
         return false;

      bool sent;
      if(is_buy)
         sent = trade.Buy(lot, _Symbol, price, sl, tp, "PinBar BUY");
      else
         sent = trade.Sell(lot, _Symbol, price, sl, tp, "PinBar SELL");

      uint rc = trade.ResultRetcode();
      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED ||
                  rc == TRADE_RETCODE_DONE_PARTIAL))
        {
         if(is_buy)
            g_total_buy++;
         else
            g_total_sell++;

         DrawArrow(iTime(_Symbol, PERIOD_M1, 1), is_buy ? low1 : high1, is_buy);

         SignalRecord sig;
         sig.time         = iTime(_Symbol, PERIOD_M1, 1);
         sig.type         = dir_ar;
         sig.entry        = price;
         sig.sl           = sl;
         sig.tp           = tp;
         sig.atr          = atr;
         sig.volume_ratio = vol_ratio;
         sig.active       = true;
         dashboard.AddSignal(sig);

         SendAlerts(dir_ar, price, sl, tp);
         LogCsv("OPEN", TimeCurrent(), dir, trade.ResultOrder(), trade.ResultPrice(),
                sl, tp, lot, (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), risk,
                atr, vol_ratio, 0, "signal");
         Print("══ صفقة ", dir_ar, " ══ السعر: ", DoubleToString(price, digits),
               " | SL: ", DoubleToString(sl, digits),
               " | TP: ", DoubleToString(tp, digits),
               " | Lot: ", DoubleToString(lot, 2));
         return true;
        }

      if(IsRetriable(rc) && attempt < InpMaxRetries)
        {
         Print("إعادة محاولة (", attempt + 1, ") بعد رمز: ", rc);
         Sleep(300);
         continue;
        }

      NotifyError("Pin Bar EA: فشل فتح صفقة " + dir_ar + " على " + _Symbol +
                  " | الرمز: " + IntegerToString((int)rc) + " | " + trade.ResultRetcodeDescription());
      return false;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| نقل الوقف للتعادل + وقف متحرك                                     |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   if(!InpUseBE && !InpUseTrail)
      return;

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long   stops_lvl  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long   freeze_lvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_dist   = (double)MathMax(stops_lvl, freeze_lvl) * point + 2 * point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      bool   is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double cur_sl = PositionGetDouble(POSITION_SL);
      double tp     = PositionGetDouble(POSITION_TP);
      if(tp <= 0 || InpRiskReward <= 0)
         continue;

      // المخاطرة الأصلية = مسافة الهدف / نسبة العائد
      double risk   = MathAbs(tp - open) / InpRiskReward;
      if(risk <= 0)
         continue;
      double profit_dist = is_buy ? bid - open : open - ask;

      double new_sl = cur_sl;

      if(InpUseBE && profit_dist >= InpBE_R * risk)
        {
         double be = is_buy ? open + InpBEOffsetPips * PipSize()
                            : open - InpBEOffsetPips * PipSize();
         if(is_buy && be > new_sl)
            new_sl = be;
         if(!is_buy && (new_sl == 0 || be < new_sl))
            new_sl = be;
        }

      if(InpUseTrail && g_last_atr > 0 && profit_dist >= InpTrailStartR * risk)
        {
         double tr = is_buy ? bid - InpTrailATR * g_last_atr
                            : ask + InpTrailATR * g_last_atr;
         if(is_buy && tr > new_sl)
            new_sl = tr;
         if(!is_buy && (new_sl == 0 || tr < new_sl))
            new_sl = tr;
        }

      new_sl = NormalizeDouble(new_sl, digits);
      bool improved = is_buy ? (new_sl > cur_sl + point) : (cur_sl == 0 || new_sl < cur_sl - point);
      if(!improved)
         continue;

      // احترام الحد الأدنى لمسافة الوقف عن السعر الحالي
      if(is_buy && new_sl > bid - min_dist)
         continue;
      if(!is_buy && new_sl < ask + min_dist)
         continue;

      if(!trade.PositionModify(ticket, new_sl, tp))
         Print("فشل تعديل الوقف للصفقة ", ticket, ": ", trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| رسم السهم على الرسم البياني                                       |
//+------------------------------------------------------------------+
void DrawArrow(datetime time, double price, bool is_buy)
  {
   string name = "PB_ARROW_" + TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS);

   int   arrow_code;
   color arrow_clr;
   if(is_buy)
     {
      arrow_code = 233;
      arrow_clr  = clrLime;
     }
   else
     {
      arrow_code = 234;
      arrow_clr  = clrRed;
     }

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
   SendTelegram(msg);
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
   return (count < InpMaxOpenTrades);
  }

//+------------------------------------------------------------------+
//| تحديث الإحصائيات وتسجيل الإغلاق عند كل صفقة                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;

   double profit = DealNet(trans.deal);
   RegisterClosed(profit, true);

   ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   // صفقة الإغلاق عكس اتجاه الصفقة الأصلية
   string type = (dt == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   ENUM_DEAL_REASON rs = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);

   LogCsv("CLOSE", (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), type,
          (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID),
          HistoryDealGetDouble(trans.deal, DEAL_PRICE),
          HistoryDealGetDouble(trans.deal, DEAL_SL),
          HistoryDealGetDouble(trans.deal, DEAL_TP),
          HistoryDealGetDouble(trans.deal, DEAL_VOLUME),
          0, 0, 0, 0, profit, EnumToString(rs));
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

   double vol_avg       = CalcVolumeAverage(InpVolumePeriod);
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   string status;
   color  status_clr;
   int    open_trades = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         open_trades++;
     }

   if(g_block_reason != "")
     {
      status     = g_block_reason;
      status_clr = DASH_ACCENT_RED;
     }
   else if(open_trades > 0)
     {
      status     = "نشط - " + IntegerToString(open_trades) + " صفقات";
      status_clr = DASH_ACCENT_GREEN;
     }
   else
     {
      status     = "يراقب السوق...";
      status_clr = DASH_ACCENT_BLUE;
     }

   int    total_trades = g_wins + g_losses;
   double win_rate     = 0;
   if(total_trades > 0)
      win_rate = g_wins * 100.0 / total_trades;

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
