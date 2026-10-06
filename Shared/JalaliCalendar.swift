//
//  JalaliCalendar.swift
//  Shared
//
//  Jalali (Solar Hijri) ⇄ Gregorian date conversion.
//  Port of the well-known jdf.scr.ir algorithm. Validated against known
//  reference dates (Nowruz 1400–1405, leap years) and round-trips over
//  ~150 years of daily samples.
//

import Foundation

public enum JalaliCalendar {

    public static let monthNames = [
        "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
        "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"
    ]

    /// Persian weekday names indexed by Calendar weekday (1 = Sunday ... 7 = Saturday).
    public static let weekdayNames = [
        "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه"
    ]

    public struct JalaliDate: Equatable {
        public var year: Int
        public var month: Int   // 1...12
        public var day: Int     // 1...31

        public init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }

        public var monthName: String {
            monthNames[max(0, min(11, month - 1))]
        }
    }

    // MARK: - Conversion

    /// Gregorian → Jalali
    public static func toJalali(year gy: Int, month gm: Int, day gd: Int) -> JalaliDate {
        let gDayOfMonthSum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let gy2 = gm > 2 ? gy + 1 : gy
        var days = 355666 + 365 * gy
        days += (gy2 + 3) / 4 - (gy2 + 99) / 100 + (gy2 + 399) / 400
        days += gd + gDayOfMonthSum[gm - 1]

        var jy = -1595 + 33 * (days / 12053)
        days %= 12053
        jy += 4 * (days / 1461)
        days %= 1461
        if days > 365 {
            jy += (days - 1) / 365
            days = (days - 1) % 365
        }
        var jm = 1
        var jd = 1
        if days < 186 {
            jm = 1 + days / 31
            jd = 1 + days % 31
        } else {
            jm = 7 + (days - 186) / 30
            jd = 1 + (days - 186) % 30
        }
        return JalaliDate(year: jy, month: jm, day: jd)
    }

    /// Jalali → Gregorian
    public static func toGregorian(year jy: Int, month jm: Int, day jd: Int) -> JalaliDate {
        let jy2 = jy + 1595
        var days = -355668 + 365 * jy2
        days += (jy2 / 33) * 8
        days += ((jy2 % 33) + 3) / 4
        days += jd
        if jm < 7 {
            days += (jm - 1) * 31
        } else {
            days += ((jm - 7) * 30) + 186
        }
        var gy = 400 * (days / 146097)
        days %= 146097
        if days > 36524 {
            days -= 1
            gy += 100 * (days / 36524)
            days %= 36524
            if days >= 365 { days += 1 }
        }
        gy += 4 * (days / 1461)
        days %= 1461
        if days > 365 {
            gy += (days - 1) / 365
            days = (days - 1) % 365
        }
        var gd = days + 1
        let isLeap = (gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0)
        let monthLengths = [31, isLeap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var gm = 1
        for (index, length) in monthLengths.enumerated() {
            if gd <= length {
                gm = index + 1
                break
            }
            gd -= length
        }
        return JalaliDate(year: gy, month: gm, day: gd)
    }

    // MARK: - Helpers

    public static func jalaliDate(for date: Date, timeZone: TimeZone = .current) -> JalaliDate {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let components = gregorian.dateComponents([.year, .month, .day], from: date)
        return toJalali(year: components.year ?? 1, month: components.month ?? 1, day: components.day ?? 1)
    }

    public static func gregorianDate(from jalali: JalaliDate,
                                     hour: Int = 9,
                                     minute: Int = 0,
                                     timeZone: TimeZone = .current) -> Date? {
        let g = toGregorian(year: jalali.year, month: jalali.month, day: jalali.day)
        var components = DateComponents()
        components.year = g.year
        components.month = g.month
        components.day = g.day
        components.hour = hour
        components.minute = minute
        components.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)
    }

    public static func daysInMonth(year jy: Int, month jm: Int) -> Int {
        guard (1...12).contains(jm) else { return 0 }
        if jm <= 6 { return 31 }
        if jm <= 11 { return 30 }
        return isLeapYear(jy) ? 30 : 29
    }

    /// True when the Jalali year is a leap year (33-year cycle used by the
    /// jdf algorithm: remainders 1, 5, 9, 13, 17, 22, 26, 30 mod 33).
    public static func isLeapYear(_ jy: Int) -> Bool {
        let r = ((jy % 33) + 33) % 33
        return r == 1 || r == 5 || r == 9 || r == 13 || r == 17 || r == 22 || r == 26 || r == 30
    }

    public static func weekdayName(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        return weekdayNames[max(0, min(6, weekday - 1))]
    }
}
