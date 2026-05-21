## Hi there 👋

---

<div align="center">

# 📊 Multi Forex Chart Indicator (MT5)

[![Download](https://img.shields.io/badge/⬇️_Download-.mq5_File-brightgreen?style=for-the-badge)](https://raw.githubusercontent.com/Fuadrahma/Fuadrahma/main/MultiForexChart.mq5)
[![Website](https://img.shields.io/badge/🌐_Live_Page-GitHub_Pages-blue?style=for-the-badge)](https://fuadrahma.github.io/Fuadrahma/)
[![License](https://img.shields.io/badge/License-Free-orange?style=for-the-badge)](#)
[![MT5](https://img.shields.io/badge/Platform-MetaTrader_5-blueviolet?style=for-the-badge)](#)

**مؤشر مخصص لمنصة MetaTrader 5 يعرض 10 أزواج فوركس على شارت واحد باستخدام نسبة التغير المئوية (% Change)**

[⬇️ تحميل مباشر](https://raw.githubusercontent.com/Fuadrahma/Fuadrahma/main/MultiForexChart.mq5) • [🌐 صفحة المشروع](https://fuadrahma.github.io/Fuadrahma/) • [📘 شارك على فيسبوك](https://www.facebook.com/sharer/sharer.php?u=https://fuadrahma.github.io/Fuadrahma/) • [✈️ شارك على تيليجرام](https://t.me/share/url?url=https://fuadrahma.github.io/Fuadrahma/)

</div>

---

### الأزواج الافتراضية

| # | الزوج | اللون | | # | الزوج | اللون |
|---|-------|-------|-|---|-------|-------|
| 1 | EURUSD | 🔵 أزرق | | 6 | NZDUSD | 🟠 برتقالي |
| 2 | GBPUSD | 🔴 أحمر | | 7 | USDCAD | 🔵 سماوي |
| 3 | USDJPY | 🟢 أخضر | | 8 | EURJPY | ⚪ أبيض |
| 4 | USDCHF | 🟡 ذهبي | | 9 | GBPJPY | 🟡 أصفر |
| 5 | AUDUSD | 🟣 أرجواني | | 10 | EURGBP | 🟣 بنفسجي |

---

### المميزات

- 📈 **مقارنة عادلة** — نسبة التغير المئوية للمقارنة بين الأزواج
- 🎨 **ألوان مميزة** — كل زوج بلون مختلف قابل للتخصيص
- ⚙️ **قابل للتخصيص** — غيّر أي زوج من الإعدادات
- ⏱️ **كل الإطارات الزمنية** — من M1 إلى MN1
- 🔄 **تحديث لحظي** — يتحدث مع كل تك جديد
- 💡 **سهل الاستخدام** — اسحب وأفلت فقط

---

### طريقة التثبيت

1. **حمّل الملف** — اضغط على [⬇️ تحميل مباشر](https://raw.githubusercontent.com/Fuadrahma/Fuadrahma/main/MultiForexChart.mq5)
2. **انسخ إلى مجلد المؤشرات** — في MT5: `File` → `Open Data Folder` → `MQL5` → `Indicators`
3. **اعمل Compile** — افتح في MetaEditor واضغط `F7`
4. **أضفه على الشارت** — من Navigator اسحب المؤشر على أي شارت
5. **تأكد من Market Watch** — تأكد أن الأزواج العشرة مفعّلة

---

### المدخلات (Inputs)

| المدخل | الوصف | القيمة الافتراضية |
|--------|-------|-------------------|
| Pair1 - Pair10 | أسماء أزواج الفوركس | EURUSD, GBPUSD, ... |
| BaseBars | عدد الشموع لحساب نقطة البداية | 100 |

---

### كيف يعمل

- يفتح **نافذة منفصلة** أسفل الشارت الرئيسي
- يحسب **نسبة التغير المئوية** لكل زوج من نقطة بداية محددة
- **خط الصفر** = نقطة البداية — فوقه ارتفاع، تحته انخفاض
- جميع الأزواج العشرة تظهر كخطوط ملونة مع أسماء في Legend

---

### شارك المؤشر

أعجبك المؤشر؟ شاركه مع أصدقائك المتداولين!

[![Share Twitter](https://img.shields.io/badge/Share-Twitter-1DA1F2?style=flat-square&logo=twitter&logoColor=white)](https://twitter.com/intent/tweet?text=%D9%85%D8%A4%D8%B4%D8%B1%20MT5%20%D9%85%D8%AC%D8%A7%D9%86%D9%8A%20%D9%8A%D8%B9%D8%B1%D8%B6%2010%20%D8%A3%D8%B2%D9%88%D8%A7%D8%AC%20%D9%81%D9%88%D8%B1%D9%83%D8%B3%20%D8%B9%D9%84%D9%89%20%D8%B4%D8%A7%D8%B1%D8%AA%20%D9%88%D8%A7%D8%AD%D8%AF&url=https://fuadrahma.github.io/Fuadrahma/)
[![Share Telegram](https://img.shields.io/badge/Share-Telegram-0088CC?style=flat-square&logo=telegram&logoColor=white)](https://t.me/share/url?url=https://fuadrahma.github.io/Fuadrahma/&text=%D9%85%D8%A4%D8%B4%D8%B1%20MT5%20%D9%85%D8%AC%D8%A7%D9%86%D9%8A%20%D9%8A%D8%B9%D8%B1%D8%B6%2010%20%D8%A3%D8%B2%D9%88%D8%A7%D8%AC%20%D9%81%D9%88%D8%B1%D9%83%D8%B3%20%D8%B9%D9%84%D9%89%20%D8%B4%D8%A7%D8%B1%D8%AA%20%D9%88%D8%A7%D8%AD%D8%AF)
[![Share WhatsApp](https://img.shields.io/badge/Share-WhatsApp-25D366?style=flat-square&logo=whatsapp&logoColor=white)](https://wa.me/?text=%D9%85%D8%A4%D8%B4%D8%B1%20MT5%20%D9%85%D8%AC%D8%A7%D9%86%D9%8A%20%D9%8A%D8%B9%D8%B1%D8%B6%2010%20%D8%A3%D8%B2%D9%88%D8%A7%D8%AC%20%D9%81%D9%88%D8%B1%D9%83%D8%B3%20%D8%B9%D9%84%D9%89%20%D8%B4%D8%A7%D8%B1%D8%AA%20%D9%88%D8%A7%D8%AD%D8%AF%20https://fuadrahma.github.io/Fuadrahma/)
[![Share Facebook](https://img.shields.io/badge/Share-Facebook-1877F2?style=flat-square&logo=facebook&logoColor=white)](https://www.facebook.com/sharer/sharer.php?u=https://fuadrahma.github.io/Fuadrahma/)

---

<div align="center">

**🔗 رابط الصفحة للمشاركة:**

```
https://fuadrahma.github.io/Fuadrahma/
```

</div>

<!--
**Fuadrahma/Fuadrahma** is a ✨ _special_ ✨ repository because its `README.md` (this file) appears on your GitHub profile.
-->
