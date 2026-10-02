//
//  AppointmentParserSupport.swift
//  Shared
//
//  Vocabularies, lookup tables and small helpers used by the appointment
//  parser pipeline. Kept separate so every parser file stays small.
//

import Foundation

// MARK: - Internal parse results

struct ParserFoundTime {
    var hour: Int
    var minute: Int
    var fragment: String
}

struct ParserFoundDate {
    /// Gregorian year/month/day components.
    var components: DateComponents
    var fragment: String
    /// امشب / tonight → the default time should be evening (21:00).
    var prefersEvening: Bool
}

// MARK: - Vocabulary & helpers

enum ParserKit {

    static let keywords: [String] = [
        "قرار", "ملاقات", "نوبت", "ویزیت", "جلسه", "دکتر", "دندانپزشک", "پزشک",
        "کلینیک", "مطب", "آرایشگاه", "سالن زیبایی", "پروانه", "اپیلاسیون",
        "مراجعه", "حضور", "رزرو", "ثبت شد",
        "appointment", "meeting", "doctor", "dentist", "clinic", "salon",
        "barber", "visit", "booking", "booked", "reservation", "reserved"
    ]

    static let persianMonthPattern = "فروردین|اردیبهشت|خرداد|تیر|مرداد|امرداد|شهریور|مهر|آبان|آذر|دی|بهمن|اسفند"

    static let englishMonthPattern = "january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec"

    /// Gregorian weekday numbers (1 = Sunday ... 7 = Saturday).
    static let persianWeekdayNumbers: [String: Int] = [
        "شنبه": 7, "یکشنبه": 1, "دوشنبه": 2, "سه شنبه": 3,
        "چهارشنبه": 4, "پنجشنبه": 5, "پنج شنبه": 5, "جمعه": 6
    ]

    static let englishWeekdayNumbers: [String: Int] = [
        "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
        "thursday": 5, "friday": 6, "saturday": 7
    ]

    static let englishMonthNumbers: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    static let hourWords: [String: Int] = [
        "یک": 1, "دو": 2, "سه": 3, "چهار": 4, "پنج": 5, "شش": 6,
        "هفت": 7, "هشت": 8, "نه": 9, "ده": 10, "یازده": 11, "دوازده": 12
    ]

    static let ordinalDayNumbers: [String: Int] = [
        "اول": 1, "دوم": 2, "سوم": 3, "چهارم": 4, "پنجم": 5, "ششم": 6,
        "هفتم": 7, "هشتم": 8, "نهم": 9, "دهم": 10, "یازدهم": 11, "دوازدهم": 12,
        "سیزدهم": 13, "چهاردهم": 14, "پانزدهم": 15, "شانزدهم": 16, "هفدهم": 17,
        "هجدهم": 18, "نوزدهم": 19, "بیستم": 20,
        "بیست و یکم": 21, "بیست و دوم": 22, "بیست و سوم": 23, "بیست و چهارم": 24,
        "بیست و پنجم": 25, "بیست و ششم": 26, "بیست و هفتم": 27, "بیست و هشتم": 28,
        "بیست و نهم": 29, "سی ام": 30
    ]

    /// Regex alternation for Persian day ordinals (۱..۳۰), longest-first.
    static var ordinalPattern: String {
        var list = ["اول", "دوم", "سوم", "چهارم", "پنجم", "ششم", "هفتم", "هشتم", "نهم", "دهم",
                    "یازدهم", "دوازدهم", "سیزدهم", "چهاردهم", "پانزدهم", "شانزدهم", "هفدهم",
                    "هجدهم", "نوزدهم", "بیستم"]
        let ones = ["یکم", "دوم", "سوم", "چهارم", "پنجم", "ششم", "هفتم", "هشتم", "نهم"]
        for word in ones { list.append("بیست و " + word) }
        list.append("سی ام")
        return list
            .map { $0.replacingOccurrences(of: " ", with: "\\s*و\\s*") }
            .joined(separator: "|")
    }

    /// Time-of-day markers: صبح ظهر بعدازظهر عصر شب نیمه‌شب ق.ظ ب.ظ am pm
    static let markerPattern = "(صبح|بامداد|ظهر|بعد\\s*از\\s*ظهر|بعدازظهر|عصر|شب|نیمه\\s*شب|ق\\s*\\.?\\s*ظ|ب\\s*\\.?\\s*ظ|am|pm)"

    // MARK: Regex & string helpers

    static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    static func intGroup(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> Int? {
        guard let raw = textGroup(match, index, in: text) else { return nil }
        return Int(raw)
    }

    static func textGroup(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, range.length > 0,
              let stringRange = Range(range, in: text) else { return nil }
        return String(text[stringRange])
    }

    static func collapseSpaces(_ value: String) -> String {
        value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func overlaps(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    static func persianMonthNumber(_ name: String) -> Int? {
        switch name {
        case "فروردین": return 1
        case "اردیبهشت": return 2
        case "خرداد": return 3
        case "تیر": return 4
        case "مرداد", "امرداد": return 5
        case "شهریور": return 6
        case "مهر": return 7
        case "آبان": return 8
        case "آذر": return 9
        case "دی": return 10
        case "بهمن": return 11
        case "اسفند": return 12
        default: return nil
        }
    }

    /// Adjusts a 12-hour clock reading to 24-hour using صبح/ظهر/عصر/شب markers.
    static func adjustedHour(hour: Int, marker: String?) -> Int {
        let marker = collapseSpaces(marker ?? "")
        if marker.isEmpty { return hour }
        let normalized = marker.replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "صبح", "بامداد", "ق.ظ", "am":
            return hour == 12 ? 0 : hour
        case "ظهر", "بعدازظهر", "عصر", "ب.ظ", "pm":
            return hour < 12 ? hour + 12 : hour
        case "شب", "نیمهشب":
            return hour == 12 ? 0 : (hour < 12 ? hour + 12 : hour)
        default:
            return hour
        }
    }
}
