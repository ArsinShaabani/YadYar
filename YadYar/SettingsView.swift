//
//  SettingsView.swift
//  YadYar
//
//  Permission status, default pre-reminder and usage guide.
//

import SwiftUI
import UIKit
import EventKit
import UserNotifications

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultReminderOffset") private var defaultOffsetRaw = ReminderOffset.hour1.rawValue
    @AppStorage("defaultCategory") private var defaultCategoryRaw = AppointmentCategory.general.rawValue
    @AppStorage("displayCalendar") private var displayCalendarRaw = DisplayCalendar.jalali.rawValue
    @AppStorage("appearanceMode") private var appearanceModeRaw = "system"
    @AppStorage("timeSensitiveDefault") private var timeSensitiveDefault = true
    @AppStorage("syncCalendarDefault") private var syncCalendarDefault = false
    @AppStorage("showBadge") private var showBadge = true
    @AppStorage("autoOpenDrafts") private var autoOpenDrafts = true
    @AppStorage("autoCleanDays") private var autoCleanDaysRaw = "never"

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderStatus: EKAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("دسترسی‌ها") {
                    HStack {
                        Label("اعلان‌ها", systemImage: "bell")
                        Spacer()
                        Text(statusText(notificationStatus))
                            .foregroundStyle(statusColor(notificationStatus))
                    }
                    if notificationStatus == .denied {
                        Button("باز کردن تنظیمات") { openAppSettings() }
                    }

                    HStack {
                        Label("یادآورها (Reminders)", systemImage: "checklist")
                        Spacer()
                        Text(reminderStatusText)
                            .foregroundStyle(reminderGranted ? .green : .orange)
                    }
                    if reminderStatus == .denied || reminderStatus == .restricted {
                        Button("باز کردن تنظیمات") { openAppSettings() }
                    }
                }

                Section("پیش‌فرض قرار") {
                    Picker("یادآوری قبل از قرار", selection: Binding(
                        get: { ReminderOffset(rawValue: defaultOffsetRaw) ?? .hour1 },
                        set: { defaultOffsetRaw = $0.rawValue })) {
                        ForEach(ReminderOffset.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    Picker("دسته پیش‌فرض", selection: Binding(
                        get: { AppointmentCategory(rawValue: defaultCategoryRaw) ?? .general },
                        set: { defaultCategoryRaw = $0.rawValue })) {
                        ForEach(AppointmentCategory.allCases) { value in
                            Label(value.label, systemImage: value.icon).tag(value)
                        }
                    }
                    Toggle("اعلان Time-Sensitive پیش‌فرض", isOn: $timeSensitiveDefault)
                    Toggle("ثبت همزمان در تقویم پیش‌فرض", isOn: $syncCalendarDefault)
                }

                Section("نمایش") {
                    Picker("تقویم", selection: Binding(
                        get: { DisplayCalendar(rawValue: displayCalendarRaw) ?? .jalali },
                        set: { displayCalendarRaw = $0.rawValue })) {
                        ForEach(DisplayCalendar.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    Picker("حالت نمایش", selection: $appearanceModeRaw) {
                        Text("سیستم").tag("system")
                        Text("روشن").tag("light")
                        Text("تاریک").tag("dark")
                    }
                }

                Section("اعلان و رفتار") {
                    Toggle("بدج شمارنده قرارهای امروز", isOn: $showBadge)
                    Toggle("باز شدن خودکار پیش‌نویس‌ها", isOn: $autoOpenDrafts)
                    Picker("پاک‌سازی خودکار آرشیو", selection: $autoCleanDaysRaw) {
                        Text("خاموش").tag("never")
                        Text("بعد از ۷ روز").tag("7")
                        Text("بعد از ۳۰ روز").tag("30")
                        Text("بعد از ۹۰ روز").tag("90")
                    }
                }

                Section("چطور استفاده کنم؟") {
                    VStack(alignment: .leading, spacing: 8) {
                        howToRow("۱", "روی متن پیام (پیامک، تلگرام، واتساپ، اینستاگرام و…) لمس طولانی بزن.")
                        howToRow("۲", "گزینه Share / اشتراک‌گذاری را انتخاب کن.")
                        howToRow("۳", "از لیست، «یاد یار» را بزن.")
                        howToRow("۴", "تاریخ و ساعت تشخیص‌داده‌شده را داخل اپ تأیید کن — یادآور در Reminders ثبت می‌شود.")
                    }
                    .font(.footnote)
                }

                Section("درباره") {
                    LabeledContent("نسخه", value: "۱٫۰٫۰")
                    Text("یادآور هوشمند قرارها از متن پیام‌ها")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تمام") { dismiss() }
                }
            }
            .task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationStatus = settings.authorizationStatus
                reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
        }
    }

    private func howToRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number).foregroundStyle(.tint).bold()
            Text(text)
        }
    }

    private func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "فعال ✓"
        case .denied: return "رد شده"
        case .notDetermined: return "تعیین نشده"
        @unknown default: return "نامشخص"
        }
    }

    private func statusColor(_ status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .secondary
        }
    }

    private var reminderStatusText: String {
        // rawValue mapping avoids availability issues: 3 = authorized/fullAccess,
        // 4 = writeOnly (iOS 17+), 0 = notDetermined, 1 = restricted, 2 = denied.
        switch reminderStatus.rawValue {
        case 3: return "فعال ✓"
        case 4: return "فقط نوشتن"
        case 0: return "تعیین نشده"
        case 1: return "محدود"
        case 2: return "رد شده"
        default: return "نامشخص"
        }
    }

    private var reminderGranted: Bool {
        reminderStatus.rawValue == 3 || reminderStatus.rawValue == 4
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
