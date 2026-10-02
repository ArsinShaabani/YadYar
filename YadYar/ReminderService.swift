//
//  ReminderService.swift
//  YadYar
//
//  EventKit bridge: creates Reminders (یادآور) with alarms at the exact
//  appointment time and optionally a heads-up alarm before it.
//

import EventKit

enum ReminderServiceError: LocalizedError {
    case accessDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "دسترسی به یادآورها داده نشد. از تنظیمات › حریم خصوصی › یادآورها فعالش کن."
        case .saveFailed:
            return "ذخیره یادآور در اپ Reminders ناموفق بود."
        }
    }
}

final class ReminderService {

    static let shared = ReminderService()
    private let eventStore = EKEventStore()

    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    /// iOS 17+: requestFullAccessToReminders / iOS 16: requestAccess(to:)
    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            return await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Creates a reminder and returns its EventKit identifier.
    func createReminder(title: String,
                        notes: String?,
                        fireDate: Date,
                        offset: ReminderOffset,
                        repeatRule: RepeatRule = .none,
                        category: AppointmentCategory = .general) async throws -> String {
        guard await requestAccess() else { throw ReminderServiceError.accessDenied }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        if let notes, !notes.isEmpty {
            reminder.notes = notes
        }
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        var due = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        due.calendar = Calendar.current
        reminder.dueDateComponents = due

        // Alarm exactly at the appointment time…
        reminder.addAlarm(EKAlarm(absoluteDate: fireDate))

        // …and an optional heads-up alarm before it.
        if let minutes = offset.minutesBefore {
            reminder.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }

        // Recurrence (daily / weekly).
        switch repeatRule {
        case .none:
            break
        case .daily:
            reminder.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .daily,
                                                         interval: 1, end: nil)]
        case .weekly:
            reminder.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly,
                                                         interval: 1, end: nil)]
        }

        // Prefix tag for the category so it is visible in the Reminders app too.
        if category != .general {
            reminder.title = "[\(category.label)] \(reminder.title ?? "")"
        }

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw ReminderServiceError.saveFailed
        }
        return reminder.calendarItemIdentifier
    }

    /// Creates a Calendar event (instead of/in addition to a Reminder).
    func createCalendarEvent(title: String,
                             notes: String?,
                             fireDate: Date,
                             durationMinutes: Int = 60,
                             repeatRule: RepeatRule = .none) async throws -> String {
        // Event access: iOS 17 write-only, older full request.
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = (try? await eventStore.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            granted = await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard granted else { throw ReminderServiceError.accessDenied }

        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw ReminderServiceError.saveFailed
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes
        event.calendar = calendar
        event.startDate = fireDate
        event.endDate = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: fireDate) ?? fireDate
        event.addAlarm(EKAlarm(absoluteDate: fireDate))

        switch repeatRule {
        case .none:
            break
        case .daily:
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)]
        case .weekly:
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)]
        }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            throw ReminderServiceError.saveFailed
        }
        return event.eventIdentifier
    }

    func deleteReminder(identifier: String) {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? eventStore.remove(reminder, commit: true)
    }

    func deleteCalendarEvent(identifier: String) {
        guard let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
    }
}
