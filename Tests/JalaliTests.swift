//
//  JalaliTests.swift
//  YadYarTests
//
//  Validates the Jalali⇄Gregorian conversion against known reference dates
//  (mirrors tools/validate_jalali.py which passed on all vectors + fuzz).
//

import XCTest
@testable import YadYar

final class JalaliTests: XCTestCase {

    private let tz = TimeZone(identifier: "Asia/Tehran")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = 12
        comps.timeZone = tz
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: comps)!
    }

    func testKnownReferenceDates() {
        let vectors: [(JalaliCalendar.JalaliDate, (Int, Int, Int))] = [
            (JalaliCalendar.JalaliDate(year: 1403, month: 8, day: 15), (2024, 11, 5)),
            (JalaliCalendar.JalaliDate(year: 1403, month: 1, day: 1), (2024, 3, 20)),
            (JalaliCalendar.JalaliDate(year: 1403, month: 12, day: 30), (2025, 3, 20)),
            (JalaliCalendar.JalaliDate(year: 1404, month: 1, day: 1), (2025, 3, 21)),
            (JalaliCalendar.JalaliDate(year: 1402, month: 1, day: 1), (2023, 3, 21)),
            (JalaliCalendar.JalaliDate(year: 1400, month: 1, day: 1), (2021, 3, 21)),
            (JalaliCalendar.JalaliDate(year: 1399, month: 12, day: 30), (2021, 3, 20)),
            (JalaliCalendar.JalaliDate(year: 1404, month: 12, day: 29), (2026, 3, 20)),
            (JalaliCalendar.JalaliDate(year: 1375, month: 10, day: 12), (1997, 1, 1))
        ]
        for (jalali, expected) in vectors {
            let gregorian = JalaliCalendar.toGregorian(year: jalali.year, month: jalali.month, day: jalali.day)
            XCTAssertEqual((gregorian.year, gregorian.month, gregorian.day), expected,
                           "j2g failed for \(jalali)")
        }
    }

    func testGregorianToJalali() {
        let vectors: [((Int, Int, Int), JalaliCalendar.JalaliDate)] = [
            ((2024, 11, 5), JalaliCalendar.JalaliDate(year: 1403, month: 8, day: 15)),
            ((2025, 3, 21), JalaliCalendar.JalaliDate(year: 1404, month: 1, day: 1)),
            ((2023, 3, 21), JalaliCalendar.JalaliDate(year: 1402, month: 1, day: 1)),
            ((2026, 3, 21), JalaliCalendar.JalaliDate(year: 1405, month: 1, day: 1))
        ]
        for (gregorian, expected) in vectors {
            let jalali = JalaliCalendar.toJalali(year: gregorian.0, month: gregorian.1, day: gregorian.2)
            XCTAssertEqual(jalali, expected, "g2j failed for \(gregorian)")
        }
    }

    // Day 31 only exists in Farvardin..Shahrivar; Esfand 30 only in leap years.
    func testRejectsImpossibleJalaliDays() {
        XCTAssertEqual(JalaliCalendar.daysInMonth(year: 1403, month: 8), 30)
        XCTAssertEqual(JalaliCalendar.daysInMonth(year: 1403, month: 1), 31)
        XCTAssertEqual(JalaliCalendar.daysInMonth(year: 1403, month: 12), 30) // leap year
        XCTAssertEqual(JalaliCalendar.daysInMonth(year: 1404, month: 12), 29)
        XCTAssertTrue(JalaliCalendar.isLeapYear(1403))
        XCTAssertFalse(JalaliCalendar.isLeapYear(1404))
    }

    func testRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let start = date(1990, 1, 1)
        for dayOffset in stride(from: 0, through: 365 * 60, by: 7) {
            let gregorian = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            let jalali = JalaliCalendar.toJalali(year: calendar.component(.year, from: gregorian),
                                                 month: calendar.component(.month, from: gregorian),
                                                 day: calendar.component(.day, from: gregorian))
            let back = JalaliCalendar.toGregorian(year: jalali.year, month: jalali.month, day: jalali.day)
            XCTAssertEqual((back.year, back.month, back.day),
                           (calendar.component(.year, from: gregorian),
                            calendar.component(.month, from: gregorian),
                            calendar.component(.day, from: gregorian)),
                           "round-trip failed at offset \(dayOffset)")
        }
    }
}
