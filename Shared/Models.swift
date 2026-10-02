//
//  Models.swift
//  Shared
//
//  Data models shared between the app, the Share Extension and the tests.
//

import Foundation

// MARK: - Enums

public enum AppointmentSource: String, Codable {
    case shareExtension
    case clipboard
    case manual
}

/// How long before the appointment the user wants a heads-up notification.
public enum ReminderOffset: String, Codable, CaseIterable, Identifiable {
    case none
    case minutes30
    case hour1
    case day1

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "فقط در زمان قرار"
        case .minutes30: return "۳۰ دقیقه قبل"
        case .hour1: return "۱ ساعت قبل"
        case .day1: return "۱ روز قبل"
        }
    }

    public var minutesBefore: Int? {
        switch self {
        case .none: return nil
        case .minutes30: return 30
        case .hour1: return 60
        case .day1: return 24 * 60
        }
    }
}

// MARK: - Category

public enum AppointmentCategory: String, Codable, CaseIterable, Identifiable {
    case general
    case work
    case medical
    case personal

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .general: return "عمومی"
        case .work: return "کاری"
        case .medical: return "پزشکی"
        case .personal: return "شخصی"
        }
    }

    public var icon: String {
        switch self {
        case .general: return "circle.grid.2x2"
        case .work: return "briefcase"
        case .medical: return "cross.case"
        case .personal: return "person"
        }
    }
}

// MARK: - Repeat rule

public enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "بدون تکرار"
        case .daily: return "روزانه"
        case .weekly: return "هفتگی"
        }
    }

    /// Next occurrence after marking a repeating appointment as done.
    public func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        }
    }
}

// MARK: - Display calendar

public enum DisplayCalendar: String, Codable, CaseIterable, Identifiable {
    case jalali
    case gregorian

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .jalali: return "شمسی"
        case .gregorian: return "میلادی"
        }
    }
}

// MARK: - Appointment

public struct Appointment: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var sourceText: String
    public var source: AppointmentSource
    public var fireDate: Date
    public var hasExplicitTime: Bool
    public var reminderOffset: ReminderOffset
    public var category: AppointmentCategory
    public var repeatRule: RepeatRule
    public var isTimeSensitive: Bool
    public var notes: String?
    public var createdAt: Date
    public var isDone: Bool
    public var reminderID: String?
    public var calendarEventID: String?
    public var notificationIDs: [String]

    public init(id: UUID = UUID(),
                title: String,
                sourceText: String = "",
                source: AppointmentSource,
                fireDate: Date,
                hasExplicitTime: Bool,
                reminderOffset: ReminderOffset = .hour1,
                category: AppointmentCategory = .general,
                repeatRule: RepeatRule = .none,
                isTimeSensitive: Bool = true,
                notes: String? = nil,
                createdAt: Date = Date(),
                isDone: Bool = false,
                reminderID: String? = nil,
                calendarEventID: String? = nil,
                notificationIDs: [String] = []) {
        self.id = id
        self.title = title
        self.sourceText = sourceText
        self.source = source
        self.fireDate = fireDate
        self.hasExplicitTime = hasExplicitTime
        self.reminderOffset = reminderOffset
        self.category = category
        self.repeatRule = repeatRule
        self.isTimeSensitive = isTimeSensitive
        self.notes = notes
        self.createdAt = createdAt
        self.isDone = isDone
        self.reminderID = reminderID
        self.calendarEventID = calendarEventID
        self.notificationIDs = notificationIDs
    }
}

// MARK: - Draft (created by the Share Extension, confirmed inside the app)

public struct AppointmentDraft: Identifiable, Codable, Equatable {
    public var id: UUID
    public var sourceText: String
    public var suggestedTitle: String
    public var suggestedDate: Date
    public var hasExplicitTime: Bool
    public var confidence: Double
    public var createdAt: Date

    public init(id: UUID = UUID(),
                sourceText: String,
                suggestedTitle: String,
                suggestedDate: Date,
                hasExplicitTime: Bool,
                confidence: Double,
                createdAt: Date = Date()) {
        self.id = id
        self.sourceText = sourceText
        self.suggestedTitle = suggestedTitle
        self.suggestedDate = suggestedDate
        self.hasExplicitTime = hasExplicitTime
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

// MARK: - Parse result

/// Output of `AppointmentParser`.
public struct ParsedAppointment: Equatable, Codable {
    public var suggestedTitle: String
    public var fireDate: Date
    public var hasExplicitTime: Bool
    public var confidence: Double
    public var matchedFragments: [String]

    public init(suggestedTitle: String,
                fireDate: Date,
                hasExplicitTime: Bool,
                confidence: Double,
                matchedFragments: [String]) {
        self.suggestedTitle = suggestedTitle
        self.fireDate = fireDate
        self.hasExplicitTime = hasExplicitTime
        self.confidence = confidence
        self.matchedFragments = matchedFragments
    }
}
