//
//  AppointmentParser+DateResolution.swift
//  Shared
//
//  Sub resolvers that turn numbers/components into concrete results,
//  plus small calendar helpers.
//

import Foundation

extension AppointmentParser {

    /// Builds Jalali components; without an explicit year the next future
    /// occurrence is used (e.g. «15 آبان» said in Azar → next year).
    func jalaliComponents(day: Int, month: Int, yearText: String?,
                          now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let nowJalali = JalaliCalendar.jalaliDate(for: now, timeZone: timeZone)
        var year = Int(yearText ?? "") ?? nowJalali.year

        func build(_ y: Int) -> DateComponents {
            let g = JalaliCalendar.toGregorian(year: y, month: month, day: day)
            var comps = DateComponents()
            comps.year = g.year
            comps.month = g.month
            comps.day = g.day
            comps.timeZone = timeZone
            return comps
        }

        var comps = build(year)
        if yearText == nil,
           let resolvedDate = calendarDate(from: comps, timeZone: timeZone),
           resolvedDate < startOfDay(now, timeZone: timeZone) {
            year += 1
            comps = build(year)
        }
        return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
    }

    func dayComponents(offset: Int, from now: Date, calendar: Calendar,
                       fragment: String, evening: Bool) -> ParserFoundDate {
        let target = calendar.date(byAdding: .day, value: offset, to: now) ?? now
        var comps = calendar.dateComponents([.year, .month, .day], from: target)
        comps.timeZone = calendar.timeZone
        return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: evening)
    }

    /// Next occurrence of a weekday; same-day rolls to next week,
    /// «هفته بعد» guarantees at least a full week ahead.
    func nextWeekdayComponents(target: Int, weekly: Bool, now: Date, calendar: Calendar) -> DateComponents {
        let today = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
        var delta = (target - (today.weekday ?? 1) + 7) % 7
        if delta == 0 { delta = 7 }
        if weekly && delta < 7 { delta += 7 }
        var base = DateComponents()
        base.year = today.year
        base.month = today.month
        base.day = today.day
        base.timeZone = calendar.timeZone
        let startDate = calendar.date(from: base) ?? now
        let result = calendar.date(byAdding: .day, value: delta, to: startDate) ?? now
        var comps = calendar.dateComponents([.year, .month, .day], from: result)
        comps.timeZone = calendar.timeZone
        return comps
    }

    // MARK: Calendar helpers

    func calendarDate(from components: DateComponents, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: components)
    }

    func startOfDay(_ date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }
}
