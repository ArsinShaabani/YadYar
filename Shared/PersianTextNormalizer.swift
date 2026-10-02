//
//  PersianTextNormalizer.swift
//  Shared
//
//  Normalizes Persian/Arabic text so the parser can work with a single
//  consistent representation: ASCII digits, unified letters, no ZWNJ.
//

import Foundation

public enum PersianTextNormalizer {

    public static func normalize(_ input: String) -> String {
        var text = input

        // 1. Remove Arabic diacritics (tashkeel) and tatweel.
        let diacritics: Set<Character> = [
            "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
            "\u{0650}", "\u{0651}", "\u{0652}", "\u{0653}", "\u{0654}",
            "\u{0655}", "\u{0656}", "\u{0670}", "\u{0640}"
        ]
        text.removeAll { diacritics.contains($0) }

        // 2. Persian (U+06F0–U+06F9) and Arabic (U+0660–U+0669) digits → ASCII digits.
        text = String(text.map { character -> Character in
            guard let scalar = character.unicodeScalars.first else { return character }
            if (0x06F0...0x06F9).contains(scalar.value) {
                return Character(UnicodeScalar(0x30 + (scalar.value - 0x06F0))!)
            }
            if (0x0660...0x0669).contains(scalar.value) {
                return Character(UnicodeScalar(0x30 + (scalar.value - 0x0660))!)
            }
            return character
        })

        // 3. Unify Persian/Arabic letter variants.
        text = text.replacingOccurrences(of: "\u{064A}", with: "\u{06CC}") // ي → ی
        text = text.replacingOccurrences(of: "\u{0649}", with: "\u{06CC}") // ى → ی
        text = text.replacingOccurrences(of: "\u{0643}", with: "\u{06A9}") // ك → ک
        text = text.replacingOccurrences(of: "\u{0629}", with: "\u{0647}") // ة → ه

        // 4. Arabic decimal/thousands separators → Latin equivalents.
        text = text.replacingOccurrences(of: "\u{066B}", with: ".") // ٫ → .
        text = text.replacingOccurrences(of: "\u{066C}", with: ",")

        // 5. ZWNJ / ZWJ → plain space (سه‌شنبه == سه شنبه).
        text = text.replacingOccurrences(of: "\u{200C}", with: " ")
        text = text.replacingOccurrences(of: "\u{200D}", with: " ")

        // 6. Latin lowercase (no-op for Persian).
        text = text.lowercased()

        // 7. Collapse runs of whitespace.
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
