//
//  AppointmentRow.swift
//  YadYar
//
//  A single appointment row: source icon, title, Jalali date + time,
//  countdown and done state.
//

import SwiftUI

struct AppointmentRow: View {

    let appointment: Appointment
    var calendar: DisplayCalendar = .jalali

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appointment.category.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.headline)
                    .strikethrough(appointment.isDone)
                if appointment.category != .general {
                    Text(appointment.category.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                Text("\(AppFormat.fullDate(appointment.fireDate, calendar: calendar)) • \(AppFormat.clockTime(appointment.fireDate))" + repeatSuffix)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !appointment.isDone && appointment.fireDate > Date() {
                    Text(AppFormat.countdown(appointment.fireDate))
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }
            Spacer()
            if appointment.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private var repeatSuffix: String {
        switch appointment.repeatRule {
        case .none: return ""
        case .daily: return " 🔁"
        case .weekly: return " 🔁 (هفتگی)"
        case .monthly: return " R-ماهانه"
        }
    }
}
