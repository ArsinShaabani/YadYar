//
//  AppointmentParser+Date.swift
//  Shared
//
//  Date extraction patterns: relative days, Persian weekdays, Jalali
//  day+month (digits & ordinals), numeric Jalali/Gregorian dates and
//  English phrases. First pattern that resolves wins.
//

import Foundation

extension AppointmentParser {

    static var datePatterns: [NSRegularExpression] {
        let month = ParserKit.persianMonthPattern
        let enMonth = ParserKit.englishMonthPattern
        let ordinals = ParserKit.ordinalPattern
        let definitions: [String] = [
            // 1 — Relative days (Persian); longest-first alternation.
            "(?<![\\p{L}])(پس\\s*فردا|پسفردا|فردا|امروز|امشب)(?![\\p{L}])",
            // 2 — Persian weekday (+ optional هفته بعد / آینده).
            "(?<![\\p{L}])(چهارشنبه|سه\\s*شنبه|پنج\\s*شنبه|پنجشنبه|دوشنبه|یکشنبه|جمعه|شنبه)\\s*(ای)?\\s*(هفته\\s*)?(بعد|بعدی|آینده|دیگه|دیگر)?(?![\\p{L}])",
            // 3 — Jalali: «15 آبان 1403» / «15 ام آبان»
            "(?<![\\d\\p{L}])(\\d{1,2})\\s*(?:ام)?\\s*(?:ماه)?\\s*(\(month))\\s*(?:ماه\\s*)?(\\d{4})?(?![\\p{L}])",
            // 4 — Jalali reversed: «آبان 15»
            "(?<![\\d\\p{L}])(\(month))\\s*(?:ماه\\s*)?(\\d{1,2})\\s*(?:ام)?\\s*(\\d{4})?(?![\\p{L}])",
            // 5 — Jalali ordinal: «بیست و پنجم بهمن»
            "(?<![\\p{L}])(\(ordinals))\\s*(?:ماه\\s*)?(\(month))\\s*(?:ماه\\s*)?(\\d{4})?(?![\\p{L}])",
            // 6 — Numeric with year: 1403/08/15 (Jalali) or 2024/11/05 (Gregorian).
            "(?<![\\d\\/])(\\d{4})\\s*[\\/.\\-]\\s*(\\d{1,2})\\s*[\\/.\\-]\\s*(\\d{1,2})(?![\\d\\/])",
            // 7 — Numeric without year: 15/8 → Jalali day/month.
            "(?<![\\d\\/])(\\d{1,2})\\s*[\\/.]\\s*(\\d{1,2})(?![\\d\\/])",
            // 8 — English: «November 5 (2024)»
            "(?<![\\p{L}])(\(enMonth))\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:\\s*,?\\s*(\\d{4}))?(?![\\p{L}])",
            // 9 — English reversed: «5 November 2024»
            "(?<![\\d\\p{L}])(\\d{1,2})(?:st|nd|rd|th)?\\s+(\(enMonth))(?:\\s*,?\\s*(\\d{4}))?(?![\\p{L}])",
            // 10 — English weekday («next tuesday»).
            "(?<![\\p{L}])(next\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?![\\p{L}])",
            // 11 — English relative days.
            "(?<![\\p{L}])(today|tomorrow|tonight)(?![\\p{L}])"
        ]
        return definitions.compactMap { ParserKit.regex($0) }
    }

    func extractDate(in text: String,
                     now: Date,
                     timeZone: TimeZone,
                     fragments: inout [String],
                     consumed: inout [NSRange]) -> ParserFoundDate? {
        let fullRange = NSRange(text.startIndex..., in: text)
        for regex in Self.datePatterns {
            guard let match = regex.firstMatch(in: text, options: [], range: fullRange) else { continue }
            let matchRange = match.range

            // Numeric 2-part dates must not collide with an already extracted time («ساعت 5/30»).
            if ParserKit.overlaps(matchRange, consumed) { continue }

            guard let stringRange = Range(matchRange, in: text) else { continue }
            let fragment = text[stringRange].trimmingCharacters(in: .whitespaces)

            if let resolved = resolveDateMatch(match, in: text, now: now,
                                               timeZone: timeZone, fragment: fragment) {
                consumed.append(matchRange)
                fragments.append(fragment)
                return resolved
            }
        }
        return nil
    }
}
