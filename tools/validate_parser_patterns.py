# -*- coding: utf-8 -*-
"""Design-validation of the core regex patterns used in AppointmentParser.
Mirrors the Swift patterns (ICU) with Python's `re` to confirm they match
the same fragments on the same test sentences used in ParserTests."""

import re

def normalize(text):
    # Mirror of PersianTextNormalizer (subset relevant to these cases)
    trans = str.maketrans("۰۱۲۳۴۵۶۷۸۹", "0123456789")
    t = text.translate(trans)
    t = t.replace("\u200c", " ")          # ZWNJ → space
    t = t.replace("٫", ".")               # arabic decimal sep
    t = re.sub(r"\s+", " ", t).strip()
    return t

P_TIME_HM_SAAT = r"ساعت\s*(\d{1,2})\s*[:.\/]\s*(\d{1,2})(?!\d)"
P_TIME_H_SAAT  = r"ساعت\s*(\d{1,2})(?![\d:.\/])"
P_RELATIVE     = r"(?<![^\W\d_])(پس\s*فردا|پسفردا|فردا|امروز|امشب)(?![^\W\d_])"
P_WEEKDAY_FA   = r"(?<![^\W\d_])(چهارشنبه|سه\s*شنبه|پنج\s*شنبه|پنجشنبه|دوشنبه|یکشنبه|جمعه|شنبه)\s*(ای)?\s*(هفته\s*)?(بعد|بعدی|آینده|دیگه|دیگر)?(?![^\W\d_])"
P_JMONTH_DAY   = r"(?<![\d\w])(\d{1,2})\s*(?:ام)?\s*(?:ماه)?\s*(فروردین|اردیبهشت|خرداد|تیر|مرداد|امرداد|شهریور|مهر|آبان|آذر|دی|بهمن|اسفند)(?:\s*(?:ماه)?\s*(\d{4}))?(?![^\W\d_])"
P_NUM_YMD      = r"(?<![\d\/])(\d{4})\s*[\/.\-]\s*(\d{1,2})\s*[\/.\-]\s*(\d{1,2})(?![\d\/])"
P_NUM_DM       = r"(?<![\d\/])(\d{1,2})\s*[\/.]\s*(\d{1,2})(?![\d\/])"
P_EN_REL       = r"(?<![^\W\d_])(today|tomorrow|tonight)(?![^\W\d_])"
P_EN_AT        = r"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"
P_MARKER       = r"^\s*(صبح|بامداد|ظهر|بعد\s*از\s*ظهر|بعدازظهر|عصر|شب|نیمه\s*شب|ق\s*\.?\s*ظ|ب\s*\.?\s*ظ|am|pm)"

# Mirror of ParserKit.ordinalPattern (Swift builds the same alternation)
_ords = ["اول", "دوم", "سوم", "چهارم", "پنجم", "ششم", "هفتم", "هشتم", "نهم", "دهم",
         "یازدهم", "دوازدهم", "سیزدهم", "چهاردهم", "پانزدهم", "شانزدهم", "هفدهم",
         "هجدهم", "نوزدهم", "بیستم"]
for _o in ["یکم", "دوم", "سوم", "چهارم", "پنجم", "ششم", "هفتم", "هشتم", "نهم"]:
    _ords.append("بیست و " + _o)
_ords.append("سی ام")
P_ORDINAL = "|".join(o.replace(" ", r"\s*و\s*") for o in _ords)
P_ORDINAL_MONTH = r"(?<![^\W\d_])(" + P_ORDINAL + r")\s*(?:ماه\s*)?(فروردین|اردیبهشت|خرداد|تیر|مرداد|امرداد|شهریور|مهر|آبان|آذر|دی|بهمن|اسفند)(?:\s*(?:ماه)?\s*(\d{4}))?(?![^\W\d_])"

def first(pattern, text):
    m = re.search(pattern, text, re.IGNORECASE)
    return m

cases = [
    # (sentence, expect_time_tuple, expect_date_fragment_kind)
    ("نوبت شما در تاریخ ۱۴۰۳/۰۸/۱۵ ساعت ۱۰:۳۰ ثبت شد", ("10", "30"), "num_ymd"),
    ("قرار ما فردا ساعت ۵ عصر دفتر", ("5", None), "relative"),
    ("جلسه سه‌شنبه ساعت ۹ صبح", ("9", None), "weekday"),
    ("قرار ساعت ۵/۳۰", ("5", "30"), None),
    ("برداشت ۵۰۰٬۰۰۰ ریال از حساب شما در تاریخ ۱۴۰۳/۰۸/۱۵ ساعت ۱۴:۳۰", ("14", "30"), "num_ymd"),
    ("سلام خوبی چطوری", None, None),
    ("قرار ۱۵ آبان ساعت ۱۸", ("18", None), "jmonth_day"),
    ("قرار پس‌فردا ساعت ۸ شب", ("8", None), "relative"),
    ("قرار بیست و پنجم بهمن ساعت ۱۰", ("10", None), "ordinal"),
    ("ساعت ۱۸:۴۵ تماس بگیر", ("18", "45"), None),
    ("Appointment tomorrow at 5pm", ("5", None), "en_relative"),
]

fails = 0
for sentence, expect_time, expect_date in cases:
    t = normalize(sentence)
    ok = True
    notes = []

    # TIME (priority: HM_SAAT → standalone → H_SAAT → … → EN_AT)
    m1 = first(P_TIME_HM_SAAT, t)
    m3 = first(P_TIME_H_SAAT, t)
    m6 = first(P_EN_AT, t)
    time_hit = m1 or m3 or m6
    if expect_time is None:
        if time_hit:
            ok = False; notes.append(f"unexpected time {time_hit.group(0)!r}")
    else:
        if not time_hit:
            ok = False; notes.append("time NOT found")
        else:
            got_h = (m1 or m3 or m6).group(1)
            got_m = m1.group(2) if m1 else (m6.group(2) if m6 else None)
            if got_h != expect_time[0] or got_m != expect_time[1]:
                ok = False; notes.append(f"time {got_h}:{got_m} != {expect_time}")

    # DATE — must skip ranges overlapped by time (simplified: search date first if time is None else after time span)
    date_kind = None
    consumed = None
    if time_hit:
        consumed = time_hit.span()
    for name, pat in [("relative", P_RELATIVE), ("weekday", P_WEEKDAY_FA),
                      ("jmonth_day", P_JMONTH_DAY), ("ordinal", P_ORDINAL_MONTH),
                      ("num_ymd", P_NUM_YMD), ("num_dm", P_NUM_DM),
                      ("en_relative", P_EN_REL)]:
        m = first(pat, t)
        if m:
            if consumed and not (m.span()[1] <= consumed[0] or m.span()[0] >= consumed[1]):
                continue  # overlaps time → skipped (mirrors Swift)
            if name in ("relative", "weekday", "jmonth_day", "ordinal", "num_ymd", "en_relative"):
                date_kind = name
                break
    if expect_date != date_kind:
        ok = False; notes.append(f"date {date_kind!r} != {expect_date!r}")

    status = "PASS" if ok else "FAIL"
    if not ok:
        fails += 1
    print(f"{status}  {sentence[:52]:54s} {('; '.join(notes))}")

print("RESULT:", "ALL PASS" if fails == 0 else f"{fails} FAILURES")
