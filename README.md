# یاد یار (YadYar) 📅🔔

اپ iOS هوشمند برای تشخیص قرارها از متن پیام‌ها (پیامک، تلگرام، واتساپ، اینستاگرام و…) و ساختن خودکار یادآور و آلارم.

**معماری:** اپ اصلی (SwiftUI) + Share Extension + پارسر قرار فارسی/انگلیسی + EventKit + اعلان محلی.

> ⚠️ نکته مهم iOS: خوندن «خودکارِ» نوتیفیکیشن اپ‌های دیگه در iOS با API عمومی **غیرممکنه** (برخلاف اندروید). راه‌حل استاندارد و App Store-Safe همینه که کاربر متن رو **Share** کنه — با یک تپ اضافه، بقیه‌ی فرایند خودکاره. برای SMS هم فاز ۲ (Message Filter Extension) پیش‌بینی شده که مجوز ویژه از اپل می‌خواد.

## ✨ قابلیت‌ها

**هسته:**
- Share Extension: از هر اپی متن رو Share کن → پیش‌نمایش قرار → تأیید → یادآور
- پارسر فارسی: «فردا ساعت ۵ عصر»، «۱۴۰۳/۰۸/۱۵ ساعت ۱۰:۳۰»، «سه‌شنبه ساعت ۹»، «۱۵ آبان»، «بیست و پنجم بهمن»، «ساعت ۵/۳۰» (سبک ایرانی) و…
- پارسر انگلیسی: "tomorrow at 5pm"، "November 5"، weekdays و… + fallback با NSDataDetector
- تبدیل دقیق تقویم شمسی↔میلادی (تست‌شده روی Nowruzهای ۱۴۰۰–۱۴۰۵ و سال‌های کبیسه)
- ثبت در اپ Reminders با آلارم + اعلان محلی (قبل از قرار و سرِ وقت)

**۱۳ قابلیت اضافه (v1.1):**
1. 🔁 **قرار تکرارشونده** (روزانه/هفتگی) با اعلان تکرارشو و RecurrenceRule در Reminders
2. 🏷 **دسته‌بندی** (عمومی/کاری/پزشکی/شخصی) با آیکون و فیلتر از تولبار
3. 🔎 **جستجو** در عنوان و متن اصلی قرارها
4. 📆 **تغییر تقویم نمایش** (شمسی/میلادی)
5. 🌗 **حالت نمایش** (سیستم/روشن/تاریک)
6. 🗓 **ثبت همزمان در تقویم** (Events) علاوه بر Reminders
7. 📤 **اشتراک‌گذاری متن قرار** (Context Menu)
8. ⏰ **تعویق سریع** (+۱ ساعت / +۱ روز) با Swipe و Context Menu
9. 🧹 **پاک‌سازی خودکار آرشیو** (خاموش/۷/۳۰/۹۰ روز)
10. ⚡️ **اعلان Time-Sensitive** (قابل غیرفعال‌سازی)
11. 🔢 **بدج شمارنده** تعداد قرارهای امروز
12. 📥 **باز شدن خودکار پیش‌نویس‌ها** هنگام اجرای اپ (قابل خاموش کردن)
13. سنوز دوگانه (۱۵ دقیقه / ۱ ساعت)
14. زمان نسبی (نیم ساعت دیگه)
15. یادآوری ۱۰ دقیقه + ۱ هفته
16. تکرار ماهانه
17. Info.plist + entitlements

## 🗂 ساختار

```
project.yml                ← تعریف پروژه برای XcodeGen
Shared/                    ← کد مشترک اپ + اکستنشن (+ تست‌ها)
  AppointmentParser*.swift ← پارسر (Support/Time/Date/Router/Kinds/Numeric/Resolution)
  JalaliCalendar.swift     ← تبدیل شمسی↔میلادی
  PersianTextNormalizer.swift
  AppointmentStore.swift   ← JSON در App Group (اپ + پیش‌نویس‌ها)
  Models.swift / Formatting.swift / AppGroup.swift
YadYar/                    ← اپ اصلی (SwiftUI)
ShareExtension/            ← اکستنشن Share
Tests/                     ← XCTest (پارسر + شمسی + نرمالایزر)
tools/validate_jalali.py   ← اعتبارسنجی الگوریتم شمسی (Python)
```

## 🚀 راه‌اندازی روی مک

پیش‌نیاز: **Xcode 15+**، **Homebrew**، اکانت Apple Developer (برای دستگاه واقعی/App Store).

```bash
brew install xcodegen
cd YadYar   # همین پوشه
xcodegen    # فایل YadYar.xcodeproj ساخته می‌شه
open YadYar.xcodeproj
```

در Xcode:
1. Target های `YadYar` و `ShareExtension` را انتخاب کن و **Signing & Capabilities → Team** را ست کن (هر دو target).
2. اگر App Group با Team‌ت ثبت نشد، در Capabilities → App Groups یک گروه جدید مثلاً `group.com.YOURTEAM.yadyar` بساز و **همین مقدار** را در `Shared/AppGroup.swift` (suiteName) و `project.yml` هم عوض کن؛ بعد دوباره `xcodegen` اجرا کن.
3. برای تست پارسر: `⌘U` (اسکیم YadYar → Test).
4. روی Simulator/دستگاه اجرا کن (`⌘R`).

## 📱 استفاده

1. روی متن پیام لمس طولانی بزن → **Share** → **یاد یار**
2. پیش‌نمایش تاریخ/ساعت تشخیص‌داده‌شده رو ببین → «ادامه در یاد یار»
3. داخل اپ، جزئیات رو (در صورت نیاز) اصلاح و **ثبت یادآور** کن
4. یادآور در Reminders ثبت می‌شه + اعلان محلی با اکشن‌ها تنظیم می‌شه

## 🔒 مجوزها

- **Reminders** (EventKit): هنگام ثبت اولین یادآور درخواست می‌شه
- **Notifications**: در اولین اجرا یک‌بار درخواست می‌شه
- App Group: اشتراک داده بین اپ و اکستنشن (پیش‌نویس‌ها)

## 🏪 چک‌لیست App Store

- [ ] App Group و bundle id ها با Team Account سازگار باشن
- [ ] آیکون اپ رو به `Assets.xcassets/AppIcon` اضافه کن (۱۰۲۴×۱۰۲۴)
- [ ] در App Store Connect متن توضیح دسترسی‌ها (Reminders/Notifications) بنویس
- [ ] Privacy Policy اضافه کن — داده‌ای به سروری نمی‌ره؛ همه‌چیز روی دستگاهه
- [ ] «قابل استفاده بدون ورود» بودن اپ رو در Review Notes ذکر کن

## 🛣 نقشه راه

- **فاز ۲ (iOS):** Message Filter Extension برای پردازش خودکار پیامک‌های فرستنده‌های ناشناس — نیازمند درخواست Entitlement از اپل و رعایت Guide 5.1.2
- **نسخه اندروید:** `NotificationListenerService` (خوندن واقعی نوتیفیکیشن‌های اجتماعی با رضایت کاربر) + محدودیت Play برای `READ_SMS` (فقط اپ Default-SMS)

## 🐙 انتشار روی GitHub

```bash
git init
git add .
git commit -m "YadYar v1.1 — iOS appointment reminder with Persian parser"
git branch -M main
git remote add origin https://github.com/USERNAME/YadYar.git
git push -u origin main
```
یا با GitHub CLI: `gh repo create YadYar --public --source=. --push`

## 🧪 تست پارسر (بدون مک)

`python tools/validate_jalali.py` الگوریتم شمسی رو با وکتورهای شناخته‌شده و fuzz چک می‌کنه (همه PASS).
