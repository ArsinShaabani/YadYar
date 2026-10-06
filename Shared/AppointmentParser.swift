//
//  AppointmentParser.swift
//  Shared
//
//  Extracts appointment (date/time) information from Persian or English text.
//  Pure Foundation — works in the main app, the Share Extension and tests.
//
//  Pipeline:
//    1. Normalize Persian text (digits, letters, ZWNJ).
//    2. Extract TIME  (first match wins; its range is marked as consumed).
//    3. Extract DATE  (relative / weekday / Jalali / Gregorian / English;
//                      numeric matches overlapping the time range are skipped).
//    4. NSDataDetector fallback for English phrases.
//    5. Resolve into a concrete Date + confidence score.
//

import Foundation

public final class AppointmentParser {

    public init() {}

    // MARK: - Public API

    public func parse(_ rawText: String,
                      now: Date = Date(),
                      timeZone: TimeZone = .current) -> ParsedAppointment? {
        // Guard the raw input too: callers (tests, clipboard, share sheet)
        // sometimes pass pure whitespace / control characters.
        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let text = PersianTextNormalizer.normalize(rawText)
        guard !text.isEmpty else { return nil }

        var fragments: [String] = []
        var consumed: [NSRange] = []

        let foundTime = extractTime(in: text, now: now, timeZone: timeZone, fragments: &fragments, consumed: &consumed)
        let foundDate = extractDate(in: text, now: now, timeZone: timeZone,
                                    fragments: &fragments, consumed: &consumed)

        if foundTime == nil && foundDate == nil {
            guard let fallback = dataDetectorFallback(raw: rawText, now: now, timeZone: timeZone,
                                                      fragments: &fragments) else { return nil }
            return ParsedAppointment(suggestedTitle: makeTitle(from: text, excluding: fragments),
                                     fireDate: fallback.date,
                                     hasExplicitTime: fallback.hasTime,
                                     confidence: 0.55,
                                     matchedFragments: fragments)
        }

        let fireDate = resolveFireDate(foundDate: foundDate, foundTime: foundTime,
                                       now: now, timeZone: timeZone)
        let title = makeTitle(from: text, excluding: fragments)

        var confidence = 0.0
        if firstKeyword(in: text) != nil { confidence += 0.30 }
        if foundDate != nil { confidence += 0.35 }
        if foundTime != nil { confidence += 0.30 }
        if foundDate != nil, foundTime != nil { confidence += 0.05 }
        // Bank/OTP/spam phrasing argues against an appointment.
        let negatives = ParserKit.negativeKeywords.filter { text.contains($0) }.count
        confidence -= 0.20 * Double(min(negatives, 2))
        confidence = min(max(confidence, 0.0), 0.98)

        return ParsedAppointment(suggestedTitle: title,
                                 fireDate: fireDate,
                                 hasExplicitTime: foundTime != nil,
                                 confidence: confidence,
                                 matchedFragments: fragments)
    }

    // MARK: - Fire-date resolution

    func resolveFireDate(foundDate: ParserFoundDate?, foundTime: ParserFoundTime?,
                         now: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var comps = DateComponents()
        comps.timeZone = timeZone

        if let found = foundDate {
            comps.year = found.components.year
            comps.month = found.components.month
            comps.day = found.components.day
        } else {
            let nowParts = calendar.dateComponents([.year, .month, .day], from: now)
            comps.year = nowParts.year
            comps.month = nowParts.month
            comps.day = nowParts.day
        }

        if let time = foundTime {
            comps.hour = time.hour
            comps.minute = time.minute
        } else {
            comps.hour = (foundDate?.prefersEvening ?? false) ? 21 : 9
            comps.minute = 0
        }

        var date = calendar.date(from: comps) ?? now

        // «today at hh:mm» that already passed (with no explicit date) → assume tomorrow.
        let isRelativeTime = foundTime?.isRelative ?? false
        if foundDate == nil && !isRelativeTime && date <= now {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }

    // MARK: - NSDataDetector fallback (mostly English)

    func dataDetectorFallback(raw: String, now: Date, timeZone: TimeZone,
                              fragments: inout [String]) -> (date: Date, hasTime: Bool)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let result = detector.matches(in: raw, options: [], range: range).first(where: { $0.date != nil }),
              let date = result.date else { return nil }
        guard date >= now.addingTimeInterval(-86400) else { return nil }
        if let stringRange = Range(result.range, in: raw) {
            fragments.append(String(raw[stringRange]).trimmingCharacters(in: .whitespaces))
        }
        return (date, result.duration > 0)
    }

    // MARK: - Title

    func makeTitle(from text: String, excluding fragments: [String] = []) -> String {
        let separators = CharacterSet(charactersIn: ".!؟?;؛\n،,")
        // Strip the exact fragments the parser consumed so the title keeps
        // the human part («قرار دندانپزشکی») instead of («ساعت ۵ عصر»).
        var cleaned = text
        for fragment in fragments where !fragment.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: fragment, with: " ")
        }
        cleaned = ParserKit.collapseSpaces(cleaned)
        let sentences = cleaned
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let hit = sentences.first(where: { sentence in
            ParserKit.keywords.contains { sentence.contains($0) }
        }) {
            return String(hit.prefix(60))
        }
        if let first = sentences.first {
            return String(first.prefix(48))
        }
        return "قرار"
    }

    func firstKeyword(in text: String) -> String? {
        ParserKit.keywords.first { text.contains($0) }
    }
}
