//
//  AppointmentParser+DateKinds.swift
//  Shared
//
//  Resolvers for relative days, Persian weekdays and Jalali day+month patterns.
//

import Foundation

extension AppointmentParser {

    // MARK: Relative days (امروز / فردا / پس‌فردا / امشب / today / tomorrow / tonight)

    func resolveRelative(_ match: NSTextCheckingResult, in text: String,
                         now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        guard let relative = ParserKit.textGroup(match, 1, in: text) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        switch ParserKit.collapseSpaces(relative) {
        case "پس فردا", "پسفردا":
            return dayComponents(offset: 2, from: now, calendar: calendar, fragment: fragment, evening: false)
        case "فردا":
            return dayComponents(offset: 1, from: now, calendar: calendar, fragment: fragment, evening: false)
        case "امروز":
            return dayComponents(offset: 0, from: now, calendar: calendar, fragment: fragment, evening: false)
        case "امشب":
            return dayComponents(offset: 0, from: now, calendar: calendar, fragment: fragment, evening: true)
        case "today":
            return dayComponents(offset: 0, from: now, calendar: calendar, fragment: fragment, evening: false)
        case "tomorrow":
            return dayComponents(offset: 1, from: now, calendar: calendar, fragment: fragment, evening: false)
        case "tonight":
            return dayComponents(offset: 0, from: now, calendar: calendar, fragment: fragment, evening: true)
        default:
            return nil
        }
    }

    // MARK: Persian weekday (سه شنبه / شنبه هفته بعد / ...)

    func resolvePersianWeekday(_ match: NSTextCheckingResult, in text: String,
                               now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        guard let name = ParserKit.textGroup(match, 1, in: text),
              let target = ParserKit.persianWeekdayNumbers[ParserKit.collapseSpaces(name)] else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let modifier = (ParserKit.textGroup(match, 3, in: text) ?? "") +
                       (ParserKit.textGroup(match, 4, in: text) ?? "")
        let weekly = modifier.contains("بعد") || modifier.contains("آینده") ||
                     modifier.contains("دیگه") || modifier.contains("دیگر")
        let comps = nextWeekdayComponents(target: target, weekly: weekly, now: now, calendar: calendar)
        return ParserFoundDate(components: comps, fragment: fragment, prefersEvening: false)
    }

    // MARK: Jalali day + month (digits, reversed, ordinals)

    func resolveJalaliMatch(_ match: NSTextCheckingResult, in text: String,
                            now: Date, timeZone: TimeZone, fragment: String) -> ParserFoundDate? {
        // «15 آبان 1403» / «15 ام آبان»
        if let dayText = ParserKit.textGroup(match, 1, in: text),
           let day = Int(dayText),
           let monthName = ParserKit.textGroup(match, 2, in: text),
           let month = ParserKit.persianMonthNumber(monthName) {
            return jalaliComponents(day: day, month: month,
                                    yearText: ParserKit.textGroup(match, 3, in: text),
                                    now: now, timeZone: timeZone, fragment: fragment)
        }
        // «آبان 15»
        if let monthName = ParserKit.textGroup(match, 1, in: text),
           let month = ParserKit.persianMonthNumber(monthName),
           let dayText = ParserKit.textGroup(match, 2, in: text),
           let day = Int(dayText) {
            return jalaliComponents(day: day, month: month,
                                    yearText: ParserKit.textGroup(match, 3, in: text),
                                    now: now, timeZone: timeZone, fragment: fragment)
        }
        // «بیست و پنجم بهمن»
        if let ordinal = ParserKit.textGroup(match, 1, in: text),
           let day = ParserKit.ordinalDayNumbers[ParserKit.collapseSpaces(ordinal)],
           let monthName = ParserKit.textGroup(match, 2, in: text),
           let month = ParserKit.persianMonthNumber(monthName) {
            return jalaliComponents(day: day, month: month,
                                    yearText: ParserKit.textGroup(match, 3, in: text),
                                    now: now, timeZone: timeZone, fragment: fragment)
        }
        return nil
    }
}
