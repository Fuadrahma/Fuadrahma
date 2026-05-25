//+------------------------------------------------------------------+
//| PinBarDashboard.mqh - لوحة معلومات عربية احترافية                |
//| لإكسبيرت تداول ذيول الشموع                                      |
//+------------------------------------------------------------------+
#property copyright "Pin Bar EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| ألوان اللوحة والتصميم                                            |
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
//| هيكل بيانات الإشارة                                               |
//+------------------------------------------------------------------+
struct SignalRecord
  {
   datetime          time;
   string            type;       // "شراء" or "بيع"
   double            entry;
   double            sl;
   double            tp;
   double            atr;
   double            volume_ratio;
   bool              active;
  };

//+------------------------------------------------------------------+
//| كلاس لوحة المعلومات العربية                                      |
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

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      CreateLbl("hprc_" + IntegerToString(i),
                DoubleToString(m_last_signals[arr_idx].entry, digits),
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
void CPinBarDashboard::Toggle()
  {
   m_minimized = !m_minimized;
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
