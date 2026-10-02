//
//  AppointmentParser+DateRouter.swift
//  Shared
//
//  Dispatches a raw regex match to shape-specific resolvers. Each resolver
//  returns nil when the group shapes do not match its pattern kind.
//

import Foundation

extension AppointmentParser {

    func resolveDateMatch(_ match: NSTextCheckingResult,
                          in text: String,
                          now: Date,
                          timeZone: TimeZone,
                          fragment: String) -> ParserFoundDate? {
        resolveRelative(match, in: text, now: now, timeZone: timeZone, fragment: fragment)
            ?? resolvePersianWeekday(match, in: text, now: now, timeZone: timeZone, fragment: fragment)
            ?? resolveJalaliMatch(match, in: text, now: now, timeZone: timeZone, fragment: fragment)
            ?? resolveNumericMatch(match, in: text, now: now, timeZone: timeZone, fragment: fragment)
            ?? resolveEnglishMatch(match, in: text, now: now, timeZone: timeZone, fragment: fragment)
    }
}
