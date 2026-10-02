//
//  AppointmentParser+DateNumeric.swift
//  Shared
//
//  Resolvers for numeric dates (Jalali/Gregorian, with or without year) and
//  English month/weekday phrases.
//

import Foundation

extension AppointmentParser {

    // MARK: Numeric dates

    func resolveNumericMatch(_ match: NSTextCheckingResult, in text: String,
                             now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        // With year: 1403/08/15 (Jalali) or 2024/11/05 (Gregorian)
        if let y = ParserKit.intGroup(match, 1, in: text),
           let m = ParserKit.intGroup(match, 2, in: text),
           let d = ParserKit.intGroup(match, 3, in: text) {
            if (1300...1500).contains(y) {
                return jalaliComponents(day: d, month: m, yearText: String(y),
                                        now: now, timeZone: timeZone, fragment: fragment)
            }
            if (1900...2100).contains(y), (1...12).contains(m), (1...31).contains(d) {
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = d
                return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
            }
            return nil
        }
        // Without year: 15/8 → Jalali day/month
        if let d = ParserKit.intGroup(match, 1, in: text),
           let m = ParserKit.intGroup(match, 2, in: text),
           (1...31).contains(d), (1...12).contains(m) {
            return jalaliComponents(day: d, month: m, yearText: nil,
                                    now: now, timeZone: timeZone, fragment: fragment)
        }
        return nil
    }

    // MARK: English month & weekday phrases

    func resolveEnglishMatch(_ match: NSTextCheckingResult, in text: String,
                             now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        // «November 5 (2024)»
        if let monthName = ParserKit.textGroup(match, 1, in: text),
           let month = ParserKit.englishMonthNumbers[monthName.lowercased()],
           let day = ParserKit.intGroup(match, 2, in: text) {
            var comps = DateComponents()
            comps.month = month
            comps.day = day
            if let year = ParserKit.intGroup(match, 3, in: text) { comps.year = year }
            return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
        }
        // «5 November 2024»
        if let day = ParserKit.intGroup(match, 1, in: text),
           let monthName = ParserKit.textGroup(match, 2, in: text),
           let month = ParserKit.englishMonthNumbers[monthName.lowercased()] {
            var comps = DateComponents()
            comps.month = month
            comps.day = day
            if let year = ParserKit.intGroup(match, 3, in: text) { comps.year = year }
            return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
        }
        // «(next) monday»
        if let name = ParserKit.textGroup(match, 2, in: text),
           let target = ParserKit.englishWeekdayNumbers[name.lowercased()] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let weekly = (ParserKit.textGroup(match, 1, in: text) ?? "").lowercased().contains("next")
            let comps = nextWeekdayComponents(target: target, weekly: weekly, now: now, calendar: calendar)
            return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
        }
        return nil
    }
}
