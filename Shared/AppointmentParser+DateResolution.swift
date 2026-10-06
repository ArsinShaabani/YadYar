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
    /// Impossible day/month pairs (e.g. «31 آبان») are rejected so the
    /// pipeline can keep looking for a real date instead of rolling over.
    func jalaliComponents(day: Int, month: Int, yearText: String?,
                          now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        guard (1...12).contains(month) else { return nil }
        let nowJalali = JalaliCalendar.jalaliDate(for: now, timeZone: timeZone)
        let explicitYear = yearText.flatMap(Int.init)
        if let y = explicitYear {
            // An explicit year outside the supported range is garbage — bail out.
            guard (1300...1500).contains(y) else { return nil }
            guard (1...JalaliCalendar.daysInMonth(year: y, month: month)).contains(day) else { return nil }
        } else if (1...maxJalaliDay(month: month, aroundYear: nowJalali.year)).contains(day) == false {
            return nil
        }

        var year = explicitYear ?? nowJalali.year

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

    /// Upper bound for a Jalali month length (Esfand varies by leap year, so the
    /// max of the current and next year is used when the year is not explicit).
    func maxJalaliDay(month: Int, aroundYear: Int) -> Int {
        max(JalaliCalendar.daysInMonth(year: aroundYear, month: month),
            JalaliCalendar.daysInMonth(year: aroundYear + 1, month: month))
    }

    /// Gregorian month length for the reference year (leap-aware for February).
    func daysInGregorianMonth(year: Int, month: Int) -> Int {
        guard (1...12).contains(month) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 31 }
        return range.count
    }

    /// Current Gregorian year in the parse timezone.
    func referenceYear(now: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.year, from: now)
    }

    /// Next year in which this Gregorian month/day is still in the future
    /// (e.g. «November 5» said on Nov 10 → next year).
    func nextGregorianYear(month: Int, day: Int, now: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let currentYear = calendar.component(.year, from: now)
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = month
        comps.day = day
        comps.timeZone = timeZone
        if let candidate = calendar.date(from: comps),
           candidate >= calendar.startOfDay(for: now) {
            return currentYear
        }
        return currentYear + 1
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
