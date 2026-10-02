//
//  AppViewModel.swift
//  YadYar
//
//  Bridges UI and services: list state, draft hand-off from the Share
//  Extension, clipboard parsing and reminder creation.
//

import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {

    enum SheetMode: Identifiable {
        case draft(AppointmentDraft)
        case clipboard(text: String, parsed: ParsedAppointment?)
        case manual

        var id: String {
            switch self {
            case .draft(let draft): return "draft-\(draft.id.uuidString)"
            case .clipboard(let text, _): return "clip-\(text.hashValue)"
            case .manual: return "manual"
            }
        }
    }

    @Published var appointments: [Appointment] = []
    @Published var pendingDraftCount = 0
    @Published var sheet: SheetMode?
    @Published var errorMessage: String?
    @Published var toast: String?

    private let store = AppointmentStore.shared
    private var doneObserverToken: NSObjectProtocol?

    init() {
        reload()
        Task { await requestNotificationPermissionOnce() }
        doneObserverToken = NotificationCenter.default.addObserver(forName: .yadYarMarkDone,
                                                                   object: nil,
                                                                   queue: .main) { [weak self] notification in
            guard let id = notification.userInfo?["appointmentID"] as? UUID else { return }
            Task { @MainActor in
                self?.handleNotificationDone(id: id)
            }
        }
    }

    deinit {
        if let token = doneObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - State

    func reload() {
        appointments = store.allAppointments().sorted { $0.fireDate < $1.fireDate }
        pendingDraftCount = store.drafts().count
    }

    var upcoming: [Appointment] {
        appointments.filter { !$0.isDone && $0.fireDate > Date() }
    }

    var archive: [Appointment] {
        appointments.filter { $0.isDone || $0.fireDate <= Date() }
    }

    // MARK: - Drafts

    func consumeDraft(id: UUID) {
        if let draft = store.draft(id: id) {
            sheet = .draft(draft)
        }
        reload()
    }

    func openFirstDraft() {
        if let first = store.drafts().first {
            sheet = .draft(first)
        }
    }

    func discardDraft(_ draft: AppointmentDraft) {
        store.removeDraft(id: draft.id)
        reload()
    }

    // MARK: - Clipboard

    func parseClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            toast = "کلیپ‌بورد خالیه"
            return
        }
        let parsed = AppointmentParser().parse(text)
        sheet = .clipboard(text: text, parsed: parsed)
    }

    // MARK: - Create

    func createAppointment(title: String,
                           fireDate: Date,
                           hasExplicitTime: Bool,
                           offset: ReminderOffset,
                           category: AppointmentCategory,
                           repeatRule: RepeatRule,
                           isTimeSensitive: Bool,
                           syncToCalendar: Bool,
                           sourceText: String,
                           source: AppointmentSource,
                           draft: AppointmentDraft?) async {
        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? "قرار" : title
        do {
            await NotificationService.shared.ensureAuthorization()

            let reminderID = try await ReminderService.shared.createReminder(
                title: finalTitle,
                notes: sourceText.isEmpty ? nil : String(sourceText.prefix(300)),
                fireDate: fireDate,
                offset: offset,
                repeatRule: repeatRule,
                category: category)

            var calendarEventID: String?
            if syncToCalendar {
                calendarEventID = try? await ReminderService.shared.createCalendarEvent(
                    title: finalTitle,
                    notes: sourceText.isEmpty ? nil : String(sourceText.prefix(300)),
                    fireDate: fireDate,
                    repeatRule: repeatRule)
            }

            var appointment = Appointment(title: finalTitle,
                                           sourceText: sourceText,
                                           source: source,
                                           fireDate: fireDate,
                                           hasExplicitTime: hasExplicitTime,
                                           reminderOffset: offset,
                                           category: category,
                                           repeatRule: repeatRule,
                                           isTimeSensitive: isTimeSensitive,
                                           reminderID: reminderID,
                                           calendarEventID: calendarEventID)
            appointment.notificationIDs = NotificationService.shared.scheduleNotifications(for: appointment)
            store.save(appointment)
            if let draft {
                store.removeDraft(id: draft.id)
            }
            reload()
            sheet = nil
            toast = "یادآور ثبت شد ✓"
            refreshBadge()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Quick postpone from swipe/context menu.
    func postpone(_ appointment: Appointment, byMinutes minutes: Int) {
        guard let newDate = Calendar.current.date(byAdding: .minute, value: minutes, to: appointment.fireDate) else {
            return
        }
        reschedule(appointment, at: newDate)
    }

    /// Reschedules everything for an appointment at a new fire date.
    func reschedule(_ appointment: Appointment, at newDate: Date) {
        var updated = appointment
        updated.fireDate = newDate

        if let reminderID = updated.reminderID {
            ReminderService.shared.deleteReminder(identifier: reminderID)
        }
        NotificationService.shared.cancelNotifications(ids: updated.notificationIDs)

        Task { @MainActor in
            do {
                let newReminderID = try await ReminderService.shared.createReminder(
                    title: updated.title,
                    notes: updated.sourceText.isEmpty ? nil : String(updated.sourceText.prefix(300)),
                    fireDate: updated.fireDate,
                    offset: updated.reminderOffset,
                    repeatRule: updated.repeatRule,
                    category: updated.category)
                updated.reminderID = newReminderID
                updated.notificationIDs = NotificationService.shared.scheduleNotifications(for: updated)
                AppointmentStore.shared.save(updated)
                self.reload()
                self.toast = "به تعویق افتاد ⏰"
                self.refreshBadge()
            } catch {
                AppointmentStore.shared.save(updated) // keep data even if rescheduling failed
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// «انجام شد» from a notification action: recurring → next occurrence,
    /// one-time → done.
    private func handleNotificationDone(id: UUID) {
        guard var appointment = store.appointment(id: id) else { return }
        if appointment.repeatRule != .none,
           let next = appointment.repeatRule.nextDate(after: appointment.fireDate) {
            NotificationService.shared.cancelNotifications(ids: appointment.notificationIDs)
            appointment.fireDate = next
            appointment.notificationIDs = NotificationService.shared.scheduleNotifications(for: appointment)
            store.save(appointment)
            reload()
            toast = "یادآور برای دفعه بعد تنظیم شد ✓"
        } else {
            toggleDone(appointment)
        }
    }

    // MARK: - Maintenance

    /// Removes done/expired appointments older than the given days.
    func cleanArchive(olderThanDays days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let doomed = archive.filter { $0.fireDate < cutoff }
        guard !doomed.isEmpty else { return }
        for appointment in doomed {
            delete(appointment)
        }
        toast = "\(AppFormat.persianDigits(String(doomed.count))) قرار قدیمی پاک شد 🧹"
        refreshBadge()
    }

    /// Sets the badge to the count of today's remaining appointments.
    func refreshBadge() {
        guard UserDefaults.standard.bool(forKey: "showBadge") else {
            NotificationService.shared.updateBadge(count: 0)
            return
        }
        let count = appointments.filter { !$0.isDone && Calendar.current.isDateInToday($0.fireDate) }.count
        NotificationService.shared.updateBadge(count: count)
    }

    // MARK: - Mutations

    func delete(_ appointment: Appointment) {
        if let reminderID = appointment.reminderID {
            ReminderService.shared.deleteReminder(identifier: reminderID)
        }
        if let eventID = appointment.calendarEventID {
            ReminderService.shared.deleteCalendarEvent(identifier: eventID)
        }
        NotificationService.shared.cancelNotifications(ids: appointment.notificationIDs)
        store.delete(id: appointment.id)
        reload()
        refreshBadge()
    }

    func toggleDone(_ appointment: Appointment) {
        var updated = appointment

        // Repeating appointments roll to their next occurrence instead of closing.
        if !updated.isDone, updated.repeatRule != .none,
           let next = updated.repeatRule.nextDate(after: updated.fireDate) {
            NotificationService.shared.cancelNotifications(ids: updated.notificationIDs)
            updated.fireDate = next
            updated.notificationIDs = NotificationService.shared.scheduleNotifications(for: updated)
            store.save(updated)
            reload()
            toast = "یادآور برای دفعه بعد تنظیم شد ✓"
            refreshBadge()
            return
        }

        updated.isDone.toggle()
        if updated.isDone {
            NotificationService.shared.cancelNotifications(ids: updated.notificationIDs)
            updated.notificationIDs = []
        }
        store.save(updated)
        reload()
        refreshBadge()
    }

    // MARK: - Permissions

    private func requestNotificationPermissionOnce() async {
        let defaults = AppGroup.userDefaults ?? UserDefaults.standard
        guard !defaults.bool(forKey: "askedNotificationAuth") else { return }
        defaults.set(true, forKey: "askedNotificationAuth")
        _ = await NotificationService.shared.requestAuthorization()
    }
}
