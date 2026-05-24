# ProTrader EA v3.0 - بوت التداول الاحترافي

<div align="center">

### اقوى بوت تداول آلي لمنصة MetaTrader 5

**ProTrader EA - Advanced Multi-Strategy Trading Bot**

[![MetaTrader 5](https://img.shields.io/badge/MetaTrader-5-blue?logo=metatrader)](https://www.metatrader5.com)
[![MQL5](https://img.shields.io/badge/MQL5-Expert%20Advisor-green)](https://www.mql5.com)
[![License](https://img.shields.io/badge/License-Free-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-3.0-gold)]()

</div>

---

## المميزات الرئيسية | Key Features

### 5 استراتيجيات تداول متقدمة

| # | الاستراتيجية | الوصف | المؤشرات |
|---|---|---|---|
| 1 | **تتبع الاتجاه** (Trend Following) | تداول مع الاتجاه العام | MA Crossover + MACD + ADX |
| 2 | **الارتداد** (Mean Reversion) | تداول عند مناطق التشبع | RSI + Bollinger Bands + Stochastic |
| 3 | **الاختراق** (Breakout) | تداول عند كسر المستويات | Donchian Channel + Volume Spike |
| 4 | **السيولة الذكية** (Smart Money) | مفاهيم السمارت موني | Order Blocks + Fair Value Gaps |
| 5 | **الاستراتيجية المدمجة** (Combined) | تصويت جميع الاستراتيجيات | نظام نقاط التوافق (Confluence) |

### ادارة مخاطر احترافية

- **4 اوضاع حجم اللوت**: ثابت / نسبة المخاطرة / Kelly Criterion / Anti-Martingale
- **حد اقصى للسحب** (Max Drawdown) - ايقاف تلقائي
- **حدود يومية** للخسارة والربح
- **حد اقصى لعدد الصفقات المفتوحة**
- **فلتر الاسبريد** - لا تداول عند ارتفاع الاسبريد

### ادارة خروج متطورة

- **وقف خسارة ديناميكي** بناء على ATR
- **وقف متحرك** (Trailing Stop)
- **نقطة التعادل** (Breakeven)
- **خروج شمعداني** (Chandelier Exit)
- **جني ارباح جزئي** (Partial Take Profit)
- **نسبة مخاطرة/عائد** قابلة للتخصيص

### فلاتر التداول

- **فلتر الجلسات**: لندن / نيويورك / اسيا / التداخل
- **تحليل اطار زمني اعلى** (Multi-Timeframe)
- **تحليل هيكل السوق** (Market Structure)
- **فلتر قوة الاتجاه** (ADX Filter)

### لوحة معلومات حية

لوحة بيانات مباشرة على الشارت تعرض:
- حالة الاستراتيجية والاشارات
- الرصيد والعائد اليومي
- نسبة الفوز وعدد الصفقات
- مستوى السحب والحالة

---

## التثبيت | Installation

### الخطوة 1: تحميل الملف
قم بتحميل ملف [`ProTraderEA.mq5`](ProTraderEA.mq5)

### الخطوة 2: نسخ الملف
انسخ الملف الى مجلد الخبراء في MetaTrader 5:
```
C:\Users\[اسمك]\AppData\Roaming\MetaQuotes\Terminal\[ID]\MQL5\Experts\
```

او من داخل MetaTrader 5:
**File → Open Data Folder → MQL5 → Experts**

### الخطوة 3: الترجمة
افتح **MetaEditor** واضغط **Compile** (F7)

### الخطوة 4: التشغيل
1. اسحب الـ EA على اي شارت
2. فعّل **AutoTrading** من شريط الادوات
3. اضبط الاعدادات حسب رغبتك
4. اضغط **OK** لبدء التداول

---

## الاعدادات التفصيلية | Settings

### اعدادات الاستراتيجية
| الاعداد | القيمة الافتراضية | الوصف |
|---|---|---|
| Trading Strategy | Combined | استراتيجية التداول |
| Main Timeframe | H1 | الاطار الزمني الرئيسي |
| Higher TF Filter | H4 | فلتر الاطار الاعلى |
| Min Confluence | 3 | الحد الادنى لنقاط التوافق |

### اعدادات المخاطرة
| الاعداد | القيمة الافتراضية | الوصف |
|---|---|---|
| Risk Mode | Risk % | وضع المخاطرة |
| Risk % | 1.0% | نسبة المخاطرة لكل صفقة |
| Max Lot | 5.0 | الحد الاقصى للوت |
| Max Drawdown | 10% | الحد الاقصى للسحب |
| Max Trades | 3 | الحد الاقصى للصفقات |
| Max Daily Loss | 3% | الحد الاقصى للخسارة اليومية |
| Max Daily Profit | 5% | هدف الربح اليومي |

### اعدادات الخروج
| الاعداد | القيمة الافتراضية | الوصف |
|---|---|---|
| Exit Mode | Combined | استراتيجية الخروج |
| SL ATR Multiple | 1.5 | مضاعف وقف الخسارة |
| TP ATR Multiple | 3.0 | مضاعف جني الارباح |
| Risk:Reward | 2.0 | نسبة المخاطرة/العائد |
| Breakeven Pips | 20 | نقاط تحريك وقف الخسارة للتعادل |
| Partial TP | 50% | نسبة الاغلاق الجزئي |

---

## الاستراتيجيات بالتفصيل | Strategy Details

### 1. تتبع الاتجاه (Trend Following)
```
شروط الشراء:
✓ تقاطع EMA السريع فوق EMA البطيء
✓ السعر فوق SMA 50 (اتجاه صاعد)
✓ MACD فوق خط الاشارة وفوق الصفر
✓ ADX > 25 (اتجاه قوي)
✓ DI+ > DI- (قوة شرائية)
✓ الاطار الاعلى صاعد (اختياري)
```

### 2. الارتداد (Mean Reversion)
```
شروط الشراء:
✓ RSI في منطقة التشبع البيعي (< 30)
✓ RSI بدأ بالارتداد
✓ السعر لمس Bollinger Band السفلي
✓ السعر ارتد من Band السفلي
✓ Stochastic تقاطع صعودي في منطقة < 20
✓ الاطار الاعلى ليس هبوطي (اختياري)
```

### 3. الاختراق (Breakout)
```
شروط الشراء:
✓ السعر كسر اعلى قمة في فترة Donchian
✓ حجم التداول اعلى من المتوسط × 1.5
✓ الاغلاق فوق مستوى الاختراق لعدة شموع
✓ الاطار الاعلى صاعد (اختياري)
```

### 4. السيولة الذكية (Smart Money)
```
شروط الشراء:
✓ تحديد Order Block صعودي
✓ السعر وصل لمنطقة OB
✓ وجود Fair Value Gap صعودي
✓ هيكل السوق صاعد (Higher Highs)
✓ RSI في منطقة مناسبة
```

### 5. المدمجة (Combined) - الاقوى
```
نظام التصويت (7 نقاط):
1. محاذاة المتوسطات المتحركة
2. اشارة MACD
3. قوة الاتجاه (ADX)
4. RSI في المنطقة المناسبة
5. موقع السعر من Bollinger
6. اتجاه الاطار الاعلى
7. هيكل السوق

يتم فتح صفقة عند تحقق 3 نقاط او اكثر (قابل للتعديل)
```

---

## نصائح الاستخدام | Tips

### للمبتدئين
1. ابدأ بحساب تجريبي (Demo) دائماً
2. استخدم الاعدادات الافتراضية
3. ابدأ بالاستراتيجية المدمجة (Combined)
4. لا تزيد المخاطرة عن 1% لكل صفقة
5. راقب الاداء لمدة شهر على الاقل

### للمتقدمين
1. جرب الاستراتيجيات المختلفة على ازواج مختلفة
2. استخدم Strategy Tester للاختبار الخلفي
3. عدّل معلمات المؤشرات حسب الزوج والاطار الزمني
4. استخدم وضع Kelly Criterion بعد 20+ صفقة
5. جرب Smart Money على الاطر الزمنية الكبيرة (H4, D1)

### الازواج الموصى بها
| الزوج | الاستراتيجية المقترحة | الاطار الزمني |
|---|---|---|
| EURUSD | Combined / Trend | H1, H4 |
| GBPUSD | Breakout / Trend | H1, H4 |
| USDJPY | Reversal / Combined | H1 |
| XAUUSD | Smart Money / Breakout | H1, H4 |
| GBPJPY | Breakout / Trend | H4 |

---

## تحذير المخاطر | Risk Disclaimer

> **تحذير هام**: التداول في الاسواق المالية ينطوي على مخاطر عالية وقد لا يكون مناسباً لجميع المستثمرين. الاداء السابق لا يضمن النتائج المستقبلية. استخدم هذا البوت على مسؤوليتك الخاصة. يُنصح بشدة بالاختبار على حساب تجريبي اولاً.

> **Risk Warning**: Trading in financial markets involves high risk and may not be suitable for all investors. Past performance does not guarantee future results. Use this EA at your own risk. Always test on a demo account first.

---

## الترخيص | License

هذا البرنامج مجاني ومفتوح المصدر. يمكنك استخدامه وتعديله بحرية.

This software is free and open source. You may use and modify it freely.

---

<div align="center">

**صنع بواسطة [Fuad Trading Systems](https://github.com/Fuadrahma)**

⭐ اذا اعجبك البوت، لا تنسى اضافة نجمة للمشروع

</div>
