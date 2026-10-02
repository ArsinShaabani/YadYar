//
//  YadYarApp.swift
//  YadYar
//
//  App entry point. The Share Extension saves a draft and opens
//  yadyar://draft?id=... — this app picks it up via onOpenURL.
//

import SwiftUI

@main
struct YadYarApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @AppStorage("appearanceMode") private var appearanceModeRaw = "system"
    @Environment(\.scenePhase) private var scenePhase

    private var colorScheme: ColorScheme? {
        switch appearanceModeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environment(\.layoutDirection, .rightToLeft)
                .tint(Color("AccentColor"))
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    if let id = YadYarURL.draftID(from: url) {
                        viewModel.consumeDraft(id: id)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    viewModel.reload()
                    viewModel.refreshBadge()
                    autoCleanIfNeeded()
                    autoOpenDraftsIfNeeded()
                }
        }
    }

    private func autoCleanIfNeeded() {
        let raw = UserDefaults.standard.string(forKey: "autoCleanDays") ?? "never"
        guard let days = Int(raw), days > 0 else { return }
        viewModel.cleanArchive(olderThanDays: days)
    }

    private func autoOpenDraftsIfNeeded() {
        guard UserDefaults.standard.object(forKey: "autoOpenDrafts") == nil
              || UserDefaults.standard.bool(forKey: "autoOpenDrafts") else { return }
        viewModel.reload()
        if viewModel.pendingDraftCount > 0, viewModel.sheet == nil {
            viewModel.openFirstDraft()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                     [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationService.shared.registerCategories()
        NotificationService.shared.activateDelegate()
        return true
    }
}
