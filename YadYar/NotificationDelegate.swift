//
//  NotificationDelegate.swift
//  YadYar
//
//  Handles foreground presentation and notification actions
//  («انجام شد» / «+۱۵ دقیقه»).
//

import UserNotifications

extension NotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        guard let raw = userInfo["appointmentID"] as? String,
              let id = UUID(uuidString: raw) else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case "DONE":
            if let appointment = AppointmentStore.shared.appointment(id: id) {
                NotificationCenter.default.post(name: .yadYarMarkDone, object: nil,
                                                userInfo: ["appointmentID": appointment.id])
            }
        case "SNOOZE15":
            if let appointment = AppointmentStore.shared.appointment(id: id) {
                snooze(appointment: appointment, minutes: 15)
            }
        case "SNOOZE60":
            if let appointment = AppointmentStore.shared.appointment(id: id) {
                snooze(appointment: appointment, minutes: 60)
            }
        default:
            break
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let yadYarMarkDone = Notification.Name("ir.yadyar.markdone")
}
