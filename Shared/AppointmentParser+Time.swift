//
//  AppointmentParser+Time.swift
//  Shared
//
//  Time extraction: «ساعت 10:30»، «ساعت 5 عصر»، «ساعت پنج و نیم»، «10:30 pm»، "at 5pm".
//  The first matching pattern wins; «ساعت X/Y» (Persian style clock) is matched
//  before generic numeric dates so it never collides with «15/8» style dates.
//

import Foundation

extension AppointmentParser {

    private enum TimeKind {
        case hourMinuteWithSaat   // ساعت 10:30 / ساعت 5/30
        case standaloneClock      // 10:30 / 5:30 pm
        case hourWithSaat         // ساعت 5
        case hourMarker
        case wordTime
        case englishAt
        case relativeIn
    }

    private static var timePatterns: [(NSRegularExpression, TimeKind)] {
        let definitions: [(String, TimeKind)] = [
            ("ساعت\\s*(\\d{1,2})\\s*[:.\\/]\\s*(\\d{1,2})(?!\\d)", .hourMinuteWithSaat),
            ("(?<![\\d:])(\\d{1,2})\\s*[:.]\\s*(\\d{2})(?!\\d)\\s*\(ParserKit.markerPattern)?", .standaloneClock),
            ("ساعت\\s*(\\d{1,2})(?![\\d:.\\/])", .hourWithSaat),
            ("(?<![\\d:])(\\d{1,2})\\s*(صبح|بامداد|ظهر|بعد\\s*از\\s*ظهر|بعدازظهر|عصر|شب|نیمه\\s*شب)(?![\\p{L}\\d])", .hourMarker),
            ("ساعت\\s*(یک|دو|سه|چهار|پنج|شش|هفت|هشت|نه|ده|یازده|دوازده)(?:\\s*و\\s*(نیم|ربع|سه\\s*ربع))?(?![\\p{L}])", .wordTime),
            ("(\U{0646}\U{06CC}\U{0645}|\d{1,2}|(\U{06CC}\U{06A9}|\U{062F}\U{0648}|\U{0633}\U{0647}|\U{0686}\U{0647}\U{0627}\U{0631}|\U{067E}\U{0646}\U{062C}|\U{0634}\U{0634}|\U{0647}\U{0641}\U{062A}|\U{0647}\U{0634}\U{062A}|\U{0646}\U{0647}|\U{062F}\U{0647}))\s*\U{0633}\U{0627}\U{0639}\U{062A}\s*\U{062F}\U{06CC}\U{06AF}\U{0647}", .relativeIn),
            ("(\d{1,2})\s*\U{062F}\U{0642}\U{06CC}\U{0642}\U{0647}\s*\U{062F}\U{06CC}\U{06AF}\U{0647}", .relativeIn),
            ("\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?", .englishAt)
        ]
        return definitions.compactMap { pattern, kind in
            guard let regex = ParserKit.regex(pattern) else { return nil }
            return (regex, kind)
        }
    }

    func extractTime(in text: String,
                     now: Date = Date(),
                     timeZone: TimeZone = .current,
                     fragments: inout [String],
                     consumed: inout [NSRange]) -> ParserFoundTime? {
        let fullRange = NSRange(text.startIndex..., in: text)
        for (regex, kind) in Self.timePatterns {
            // Try every match: an out-of-range value must not block a later valid one.
            let matches = regex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                let fragment = text[Range(match.range, in: text)!].trimmingCharacters(in: .whitespaces)

                var hour = 0
                var minute = 0
                var marker: String?

                switch kind {
                case .hourMinuteWithSaat:
                    hour = ParserKit.intGroup(match, 1, in: text) ?? 0
                    minute = ParserKit.intGroup(match, 2, in: text) ?? 0
                    marker = scanMarker(after: match.range, in: text)
                case .standaloneClock:
                    hour = ParserKit.intGroup(match, 1, in: text) ?? 0
                    minute = ParserKit.intGroup(match, 2, in: text) ?? 0
                    if let captured = ParserKit.textGroup(match, 3, in: text) { marker = captured }
                    if marker == nil { marker = scanMarker(after: match.range, in: text) }
                case .hourWithSaat:
                    hour = ParserKit.intGroup(match, 1, in: text) ?? 0
                    marker = scanMarker(after: match.range, in: text)
                case .hourMarker:
                    hour = ParserKit.intGroup(match, 1, in: text) ?? 0
                    marker = ParserKit.textGroup(match, 2, in: text)
                case .wordTime:
                    guard let word = ParserKit.textGroup(match, 1, in: text),
                          let value = ParserKit.hourWords[word] else { continue }
                    hour = value
                    switch ParserKit.textGroup(match, 2, in: text) ?? "" {
                    case "نیم": minute = 30
                    case "ربع": minute = 15
                    case "سه ربع": minute = 45
                    default: break
                    }
                    marker = scanMarker(after: match.range, in: text)
                case .englishAt:
                    hour = ParserKit.intGroup(match, 1, in: text) ?? 0
                    minute = ParserKit.intGroup(match, 2, in: text) ?? 0
                    marker = ParserKit.textGroup(match, 3, in: text)
                case .relativeIn:
                    guard let rel = relativeOffset(match, in: text, now: now) else { continue }
                    consumed.append(match.range)
                    fragments.append(fragment)
                    return ParserFoundTime(hour: rel.hour, minute: rel.minute,
                                         fragment: fragment, isRelative: true)
                }

                let adjusted = ParserKit.adjustedHour(hour: hour, marker: marker)
                guard (0...23).contains(adjusted), (0...59).contains(minute) else { continue }

                consumed.append(match.range)
                fragments.append(fragment)
                return ParserFoundTime(hour: adjusted, minute: minute, fragment: fragment)
            }
        }
        return nil
    }

    /// Looks for صبح/عصر/شب/... within a small window right after a time match.
    func relativeOffset(_ match: NSTextCheckingResult, in text: String, now: Date) -> (hour: Int, minute: Int)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var minutes = 0
        if let g1 = ParserKit.textGroup(match, 1, in: text)?.trimmingCharacters(in: .whitespaces),
           !g1.isEmpty {
            if let n = Int(g1) { minutes += n * 60 }
            else if g1 == "نیم" { minutes += 30 }
            else if let w = ParserKit.relativeHourWords[g1] { minutes += w * 60 }
        }
        if let g2 = ParserKit.textGroup(match, 2, in: text)?.trimmingCharacters(in: .whitespaces),
           !g2.isEmpty, let n = Int(g2) { minutes += n }
        guard minutes > 0, minutes <= 12 * 60 else { return nil }
        guard let target = cal.date(byAdding: .minute, value: minutes, to: now) else { return nil }
        let parts = cal.dateComponents([.hour, .minute], from: target)
        guard let h = parts.hour, let m = parts.minute else { return nil }
        return (h, m)
    }

    func scanMarker(after range: NSRange, in text: String) -> String? {
        guard let regex = ParserKit.regex("^\\s*\(ParserKit.markerPattern)") else { return nil }
        let end = range.location + range.length
        guard end != NSNotFound else { return nil }
        let remaining = (text as NSString).length - end
        guard remaining > 0 else { return nil }
        let window = min(16, remaining)
        guard let match = regex.firstMatch(in: text, options: [],
                                           range: NSRange(location: end, length: window)),
              let marker = ParserKit.textGroup(match, 1, in: text) else { return nil }
        return ParserKit.collapseSpaces(marker)
    }
}
