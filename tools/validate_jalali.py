# -*- coding: utf-8 -*-
"""Validation of the Jalali<->Gregorian algorithm (port of jdf.scr.ir)
before porting it to Swift for the YadYar project."""

def div(a, b):
    return a // b

def g2j(gy, gm, gd):
    g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    gy2 = gy + 1 if gm > 2 else gy
    days = 355666 + (365 * gy) + div(gy2 + 3, 4) - div(gy2 + 99, 100) + div(gy2 + 399, 400) + gd + g_d_m[gm - 1]
    jy = -1595 + 33 * div(days, 12053)
    days %= 12053
    jy += 4 * div(days, 1461)
    days %= 1461
    if days > 365:
        jy += div(days - 1, 365)
        days = (days - 1) % 365
    if days < 186:
        jm = 1 + div(days, 31)
        jd = 1 + (days % 31)
    else:
        jm = 7 + div(days - 186, 30)
        jd = 1 + ((days - 186) % 30)
    return jy, jm, jd

def j2g(jy, jm, jd):
    jy += 1595
    days = -355668 + (365 * jy) + (div(jy, 33) * 8) + div((jy % 33) + 3, 4) + jd
    if jm < 7:
        days += (jm - 1) * 31
    else:
        days += ((jm - 7) * 30) + 186
    gy = 400 * div(days, 146097)
    days %= 146097
    if days > 36524:
        days -= 1
        gy += 100 * div(days, 36524)
        days %= 36524
        if days >= 365:
            days += 1
    gy += 4 * div(days, 1461)
    days %= 1461
    if days > 365:
        gy += div(days - 1, 365)
        days = (days - 1) % 365
    gd = days + 1
    leap = (gy % 4 == 0 and gy % 100 != 0) or (gy % 400 == 0)
    sal_a = [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    gm = 0
    for i, md in enumerate(sal_a):
        if gd <= md:
            gm = i + 1
            break
        gd -= md
    return gy, gm, gd

def weekday(gy, gm, gd):
    import datetime
    return datetime.date(gy, gm, gd).weekday()  # 0=Monday

tests = [
    # (jy, jm, jd, gy, gm, gd, description)
    (1403, 8, 15, 2024, 11, 5,  "1403/08/15 == 2024-11-05"),
    (1403, 1, 1,  2024, 3, 20,  "Nowruz 1403 == 2024-03-20"),
    (1403, 12, 30, 2025, 3, 20, "1403 leap year, 30 Esfand == 2025-03-20"),
    (1404, 1, 1,  2025, 3, 21,  "Nowruz 1404 == 2025-03-21"),
    (1402, 1, 1,  2023, 3, 21,  "Nowruz 1402 == 2023-03-21"),
    (1400, 1, 1,  2021, 3, 21,  "Nowruz 1400 == 2021-03-21"),
    (1399, 12, 30, 2021, 3, 20, "1399 leap year ends 2021-03-20"),
    (1404, 12, 29, 2026, 3, 20, "1404 not leap ends 2026-03-20"),
    (1405, 1, 1,  2026, 3, 21,  "Nowruz 1405 == 2026-03-21"),
    (1375, 10, 12, 1997, 1, 1,  "1375/10/12 == 1997-01-01"),
]

fail = 0
for jy, jm, jd, gy, gm, gd, desc in tests:
    got_g = j2g(jy, jm, jd)
    got_j = g2j(gy, gm, gd)
    ok1 = got_g == (gy, gm, gd)
    ok2 = got_j == (jy, jm, jd)
    status = "PASS" if (ok1 and ok2) else "FAIL"
    if status == "FAIL":
        fail += 1
    print(f"{status}  {desc:45s} j2g={got_g} g2j={got_j}")

# Round-trip fuzz over ~150 years
import datetime
start = datetime.date(1990, 1, 1)
fuzz_fail = 0
for i in range(0, 365 * 150, 7):  # weekly steps
    d = start + datetime.timedelta(days=i)
    j = g2j(d.year, d.month, d.day)
    back = j2g(*j)
    if back != (d.year, d.month, d.day):
        fuzz_fail += 1
        print("FUZZ FAIL", d, j, back)
        if fuzz_fail > 5:
            break
print(f"Fuzz round-trip: {'PASS' if fuzz_fail == 0 else 'FAIL'} ({(365*150)//7} samples)")

# Weekday sanity: 1403/08/15 was a Tuesday
wd = weekday(2024, 11, 5)
print("2024-11-05 weekday index:", wd, "(expect 1 = Tuesday)")
print("RESULT:", "ALL PASS" if fail == 0 and fuzz_fail == 0 else "FAILURES!")
