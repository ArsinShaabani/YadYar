//
//  ParserTests.swift
//  YadYarTests
//
//  Deterministic parser tests: a fixed reference "now" in Asia/Tehran keeps
//  expectations stable on any machine.
//

import XCTest
@testable import YadYar

final class ParserTests: XCTestCase {

    private let parser = AppointmentParser()
    private let tz = TimeZone(identifier: "Asia/Tehran")!
    /// 2024-11-05 10:00 (سه‌شنبه) Tehran — 1403/08/15
    private var now: Date {
        var comps = DateComponents()
        comps.year = 2024; comps.month = 11; comps.day = 5
        comps.hour = 10; comps.minute = 0
        comps.timeZone = tz
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: comps)!
    }

    private func expected(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = h; comps.minute = min
        comps.timeZone = tz
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: comps)!
    }

    private func fire(_ text: String) -> Date? {
        parser.parse(text, now: now, timeZone: tz)?.fireDate
    }

    func testJalaliNumericDateAndTime() {
        let result = parser.parse("نوبت شما در تاریخ ۱۴۰۳/۰۸/۱۵ ساعت ۱۰:۳۰ ثبت شد", now: now, timeZone: tz)
        XCTAssertEqual(result?.fireDate, expected(2024, 11, 5, 10, 30))
        XCTAssertEqual(result?.hasExplicitTime, true)
        XCTAssertGreaterThanOrEqual(result?.confidence ?? 0, 0.9)
    }

    func testTomorrowWithEveningMarker() {
        XCTAssertEqual(fire("قرار ما فردا ساعت ۵ عصر دفتر"), expected(2024, 11, 6, 17, 0))
    }

    func testPersianWeekdayNextWeek() {
        // 2024-11-05 is Tuesday (سه‌شنبه) → same weekday rolls to next week.
        XCTAssertEqual(fire("جلسه سه‌شنبه ساعت ۹ صبح"), expected(2024, 11, 12, 9, 0))
    }

    func testEnglishTomorrowAt5pm() {
        XCTAssertEqual(fire("Appointment tomorrow at 5pm"), expected(2024, 11, 6, 17, 0))
    }

    func testSlashTimeBumpsToTomorrowWhenPassed() {
        // «ساعت ۵/۳۰» is 05:30; now is 10:00 → next day.
        XCTAssertEqual(fire("قرار ساعت ۵/۳۰"), expected(2024, 11, 6, 5, 30))
    }

    func testBankSMSGetsLowerConfidence() {
        let result = parser.parse("برداشت ۵۰۰٬۰۰۰ ریال از حساب شما در تاریخ ۱۴۰۳/۰۸/۱۵ ساعت ۱۴:۳۰", now: now, timeZone: tz)
        XCTAssertNotNil(result)
        XCTAssertLessThan(result?.confidence ?? 1, 0.75)
    }

    func testGibberishReturnsNil() {
        XCTAssertNil(parser.parse("سلام خوبی چطوری", now: now, timeZone: tz))
    }

    func testMonthNameWithToday() {
        // 15 آبان 1403 == 2024-11-05 (today) → 18:00 today.
        XCTAssertEqual(fire("قرار ۱۵ آبان ساعت ۱۸"), expected(2024, 11, 5, 18, 0))
    }

    func testPostTomorrowWithNightMarker() {
        XCTAssertEqual(fire("قرار پس‌فردا ساعت ۸ شب"), expected(2024, 11, 7, 20, 0))
    }

    func testOrdinalDayWithMonth() {
        let result = parser.parse("قرار بیست و پنجم بهمن ساعت ۱۰", now: now, timeZone: tz)
        let base = JalaliCalendar.gregorianDate(from: JalaliCalendar.JalaliDate(year: 1403, month: 11, day: 25),
                                                hour: 10, minute: 0, timeZone: tz)!
        XCTAssertEqual(result?.fireDate, base)
    }

    func testTonightDefaultsToEvening() {
        let result = parser.parse("قرار امشب", now: now, timeZone: tz)
        XCTAssertEqual(result?.fireDate, expected(2024, 11, 5, 21, 0))
        XCTAssertEqual(result?.hasExplicitTime, false)
    }

    func testTimeOnlyToday() {
        XCTAssertEqual(fire("ساعت ۱۸:۴۵ تماس بگیر"), expected(2024, 11, 5, 18, 45))
    }

    func testMonthNameStaysInCurrentYear() {
        // 15 اسفند 1403 is in the future relative to 1403/08/15 → stays in 1403.
        let result = parser.parse("قرار ۱۵ اسفند ساعت ۱۰", now: now, timeZone: tz)
        XCTAssertEqual(result?.fireDate,
                       JalaliCalendar.gregorianDate(from: JalaliCalendar.JalaliDate(year: 1403, month: 12, day: 15),
                                                    hour: 10, minute: 0, timeZone: tz))
    }

    func testRejectsImpossibleDates() {
        // 31 آبان has only 30 days → must not roll over into آذر.
        XCTAssertNil(parser.parse("قرار ۳۱ آبان ساعت ۱۰", now: now, timeZone: tz))
        // 32/13/1403 is not a real calendar date either.
        XCTAssertNil(parser.parse("قرار ۱۴۰۳/۱۳/۳۲ ساعت ۱۰", now: now, timeZone: tz))
    }

    func testAmbiguousBarePairIgnored() {
        // «۵/۶» without a year could be day/month or month/day → ignored.
        XCTAssertNil(parser.parse("قرار ۵/۶ ساعت ۱۰", now: now, timeZone: tz))
    }

    func testEnglishMonthWithoutYearRollsForward() {
        // now = 2024-11-05 10:00 → «November 5» resolves to next year's occurrence.
        let result = parser.parse("Meeting November 5 at 10am", now: now, timeZone: tz)
        XCTAssertEqual(result?.fireDate, expected(2025, 11, 5, 10, 0))
    }

    func testBankSMSPenaltyKeepsLowConfidence() {
        let result = parser.parse("برداشت ۵۰۰٬۰۰۰ ریال از حساب شما در تاریخ ۱۴۰۳/۰۸/۱۵ ساعت ۱۴:۳۰", now: now, timeZone: tz)
        XCTAssertNotNil(result)
        XCTAssertLessThan(result?.confidence ?? 1, 0.6)
    }

    func testRelativeHalfHour() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let target = cal.date(byAdding: .minute, value: 30, to: now)!
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        XCTAssertEqual(fire("قرار نیم ساعت دیگه"), expected(parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!))
    }

    func testRelativeTwoHours() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let target = cal.date(byAdding: .hour, value: 2, to: now)!
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        XCTAssertEqual(fire("قرار 2 ساعت دیگه"), expected(parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!))
    }

    func testTitleStripsDateFragments() {
        let result = parser.parse("قرار دندانپزشکی فردا ساعت ۵ عصر", now: now, timeZone: tz)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.suggestedTitle.contains("ساعت") ?? true)
        XCTAssertFalse(result?.suggestedTitle.contains("فردا") ?? true)
    }
}
