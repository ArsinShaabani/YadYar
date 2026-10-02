//
//  RepeatAndCategoryTests.swift
//  YadYarTests
//

import XCTest
@testable import YadYar

final class RepeatAndCategoryTests: XCTestCase {

    func testRepeatNextDate() {
        let tz = TimeZone(identifier: "Asia/Tehran")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        var comps = DateComponents()
        comps.year = 2024; comps.month = 11; comps.day = 5; comps.hour = 10
        comps.timeZone = tz
        let base = calendar.date(from: comps)!

        XCTAssertEqual(RepeatRule.daily.nextDate(after: base, calendar: calendar),
                       calendar.date(byAdding: .day, value: 1, to: base))
        XCTAssertEqual(RepeatRule.weekly.nextDate(after: base, calendar: calendar),
                       calendar.date(byAdding: .weekOfYear, value: 1, to: base))
        XCTAssertNil(RepeatRule.none.nextDate(after: base, calendar: calendar))
    }

    func testCategoryAndCalendarRoundTrip() {
        for category in AppointmentCategory.allCases {
            XCTAssertEqual(AppointmentCategory(rawValue: category.rawValue), category)
        }
        for display in DisplayCalendar.allCases {
            XCTAssertEqual(DisplayCalendar(rawValue: display.rawValue), display)
        }
        XCTAssertEqual(AppointmentCategory.medical.icon, "cross.case")
    }

    func testAppointmentCodableKeepsNewFields() throws {
        let appointment = Appointment(title: "دکتر",
                                       source: .manual,
                                       fireDate: Date(),
                                       hasExplicitTime: true,
                                       category: .medical,
                                       repeatRule: .weekly,
                                       isTimeSensitive: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(appointment)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Appointment.self, from: data)

        XCTAssertEqual(decoded, appointment)
    }
}
