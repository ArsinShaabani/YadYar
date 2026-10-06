//
//  NotificationService.swift
//  YadYar
//
//  Local notifications for appointment alarms (heads-up + on-time).
//

import UserNotifications

final class NotificationService: NSObject {

    static let shared = NotificationService()
    static let categoryIdentifier = "APPOINTMENT"

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func registerCategories() {
        let done = UNNotificationAction(identifier: "DONE",
                                        title: "انجام شد",
                                        options: [.authenticationNotRequired])
        let snooze15 = UNNotificationAction(identifier: "SNOOZE15",
                                            title: "+۱۵ دقیقه",
                                            options: [.authenticationNotRequired])
        let snooze60 = UNNotificationAction(identifier: "SNOOZE60",
                                            title: "+۱ ساعت",
                                            options: [.authenticationNotRequired])
        let category = UNNotificationCategory(identifier: Self.categoryIdentifier,
                                              actions: [done, snooze15, snooze60],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func activateDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Requests permission only when it has never been asked before.
    func ensureAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = await requestAuthorization()
    }

    // MARK: - Scheduling

    /// Schedules notifications for an appointment and returns identifiers.
    /// One-time appointments get the exact-time trigger plus an optional
    /// heads-up; repeating appointments get one repeating trigger
    /// (hour/minute based) so iOS fires them indefinitely.
    /// Past dates are skipped — there is no point scheduling an alarm
    /// that would either never fire or fire immediately by mistake.
    func scheduleNotifications(for appointment: Appointment) -> [String] {
        let center = UNUserNotificationCenter.current()
        var identifiers: [String] = []
        let suffix = appointment.repeatRule == .none ? "" : "-repeat"

        // Main trigger (repeats for recurring appointments).
        if appointment.fireDate > Date() {
            let id = "appt-\(appointment.id.uuidString)-main\(suffix)"
            let content = makeContent(for: appointment,
                                      title: appointment.repeatRule == .none ? "وقت قرار رسید!" : "وقت قرار همیشگی رسید!",
                                      body: appointment.title)
            let trigger = mainTrigger(for: appointment)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            identifiers.append(id)
        }

        // Heads-up before (one-time appointments only).
        if appointment.repeatRule == .none,
           let minutes = appointment.reminderOffset.minutesBefore,
           let preDate = Calendar.current.date(byAdding: .minute, value: -minutes, to: appointment.fireDate),
           preDate > Date() {
            let id = "appt-\(appointment.id.uuidString)-pre"
            let content = makeContent(for: appointment,
                                      title: "یادآوری قرار",
                                      body: "«\(appointment.title)» \(AppFormat.shortDateTime(appointment.fireDate)) است.")
            add(id: id, content: content, at: preDate)
            identifiers.append(id)
        }

        return identifiers
    }

    /// Exact-time trigger; repeating rules use calendar matching without dates.
    private func mainTrigger(for appointment: Appointment) -> UNNotificationTrigger {
        let calendar = Calendar.current
        if appointment.repeatRule == .none {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: appointment.fireDate)
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        }
        if appointment.repeatRule == .monthly {
            var comps = calendar.dateComponents([.day, .hour, .minute], from: appointment.fireDate)
            comps.timeZone = calendar.timeZone
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }
        if appointment.repeatRule == .weekly {
            var comps = calendar.dateComponents([.weekday, .hour, .minute], from: appointment.fireDate)
            comps.timeZone = calendar.timeZone
            return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }
        var comps = calendar.dateComponents([.hour, .minute], from: appointment.fireDate)
        comps.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
    }

    func cancelNotifications(ids: [String]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }

    func snooze(appointment: Appointment, minutes: Int) {
        let id = "appt-\(appointment.id.uuidString)-snooze-\(UUID().uuidString.prefix(8))"
        let content = makeContent(for: appointment,
                                  title: "یادآوری به تعویق افتاد",
                                  body: appointment.title)
        let date = Date().addingTimeInterval(TimeInterval(minutes * 60))
        add(id: id, content: content, at: date)
    }

    /// Updates the app badge with the number of today's upcoming appointments.
    func updateBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - Builders

    private func add(id: String, content: UNMutableNotificationContent, at date: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func makeContent(for appointment: Appointment,
                             title: String,
                             body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if appointment.isTimeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        content.userInfo = ["appointmentID": appointment.id.uuidString]
        content.categoryIdentifier = Self.categoryIdentifier
        return content
    }
}
