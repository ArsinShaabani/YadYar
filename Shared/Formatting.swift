//
//  Formatting.swift
//  Shared
//
//  Persian-friendly display formatting (Jalali dates, Persian digits,
//  relative labels and countdowns).
//

import Foundation

public enum AppFormat {

    /// Converts ASCII digits to Persian digits.
    public static func persianDigits(_ text: String) -> String {
        let map: [Character: Character] = [
            "0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴",
            "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"
        ]
        return String(text.map { map[$0] ?? $0 })
    }

    /// «سه‌شنبه ۱۵ آبان ۱۴۰۳» / «سه‌شنبه ۵ نوامبر ۲۰۲۴»
    public static func fullDate(_ date: Date, calendar: DisplayCalendar = .jalali) -> String {
        switch calendar {
        case .jalali:
            let jalali = JalaliCalendar.jalaliDate(for: date)
            let weekday = JalaliCalendar.weekdayName(for: date)
            return "\(weekday) \(persianDigits(String(jalali.day))) \(jalali.monthName) \(persianDigits(String(jalali.year)))"
        case .gregorian:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fa_IR")
            formatter.dateStyle = .full
            return formatter.string(from: date)
        }
    }

    /// «سه‌شنبه ۱۵ آبان ۱۴۰۳» — شمسی همیشه
    public static func jalaliFull(_ date: Date) -> String {
        let jalali = JalaliCalendar.jalaliDate(for: date)
        let weekday = JalaliCalendar.weekdayName(for: date)
        return "\(weekday) \(persianDigits(String(jalali.day))) \(jalali.monthName) \(persianDigits(String(jalali.year)))"
    }

    /// «۱۷:۳۰»
    public static func clockTime(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = String(format: "%02d", comps.hour ?? 0)
        let minute = String(format: "%02d", comps.minute ?? 0)
        return persianDigits("\(hour):\(minute)")
    }

    /// «امروز» / «فردا» / «۳ روز دیگر» / «۲ روز پیش»
    public static func relativeDayLabel(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "امروز" }
        if calendar.isDateInTomorrow(date) { return "فردا" }
        if calendar.isDateInYesterday(date) { return "دیروز" }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        if days > 0 { return "\(persianDigits(String(days))) روز دیگر" }
        return "\(persianDigits(String(-days))) روز پیش"
    }

    /// «۳ روز و ۲ ساعت مانده»
    public static func countdown(_ date: Date, now: Date = Date()) -> String {
        guard date > now else { return "گذشته" }
        let comps = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: date)
        var parts: [String] = []
        if let d = comps.day, d > 0 { parts.append("\(persianDigits(String(d))) روز") }
        if let h = comps.hour, h > 0 { parts.append("\(persianDigits(String(h))) ساعت") }
        if parts.count < 2, let m = comps.minute, m > 0 { parts.append("\(persianDigits(String(m))) دقیقه") }
        if parts.isEmpty { return "چند دقیقه دیگر" }
        return parts.joined(separator: " و ") + " مانده"
    }

    /// «فردا ساعت ۱۷:۳۰»
    public static func shortDateTime(_ date: Date) -> String {
        "\(relativeDayLabel(date)) ساعت \(clockTime(date))"
    }
}
