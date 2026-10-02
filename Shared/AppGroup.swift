//
//  AppGroup.swift
//  Shared
//
//  Constants shared between the YadYar app and its Share Extension.
//

import Foundation

public enum AppGroup {
    /// App Group identifier — MUST match the entitlements of both targets.
    /// If you change it, update `project.yml` (entitlements) and this constant together.
    public static let suiteName = "group.ir.yadyar.shared"

    /// Custom URL scheme used to hand a saved draft back to the main app.
    public static let urlScheme = "yadyar"

    /// Shared on-disk container (visible to both targets).
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    /// Shared `UserDefaults`.
    public static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

public enum YadYarURL {

    /// Builds `yadyar://draft?id=<uuid>`
    public static func openDraftURL(id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = AppGroup.urlScheme
        components.host = "draft"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        return components.url!
    }

    /// Extracts the draft id from `yadyar://draft?id=<uuid>`
    public static func draftID(from url: URL) -> UUID? {
        guard url.scheme?.lowercased() == AppGroup.urlScheme,
              url.host?.lowercased() == "draft",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "id" })?.value
        else { return nil }
        return UUID(uuidString: raw)
    }
}
