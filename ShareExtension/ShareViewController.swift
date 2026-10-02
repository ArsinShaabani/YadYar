//
//  ShareViewController.swift
//  ShareExtension
//
//  Principal class of the Share Extension. Receives shared text from any
//  app, parses it with the shared AppointmentParser, shows a compact
//  confirmation card and hands the draft to the main app via the App Group
//  + yadyar:// URL scheme.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private var sourceText = ""
    private var parsed: ParsedAppointment?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadSharedText { [weak self] text in
            DispatchQueue.main.async {
                self?.presentUI(with: text)
            }
        }
    }

    // MARK: - Reading shared content

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion("")
            return
        }
        let providers = items.flatMap { $0.attachments ?? [] }

        if let textProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) {
            textProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                completion(Self.string(from: item))
            }
            return
        }

        if let urlProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) {
            urlProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                completion(Self.string(from: item))
            }
            return
        }

        completion("")
    }

    private static func string(from item: Any?) -> String {
        switch item {
        case let text as String: return text
        case let data as Data:
            return String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1256)
                ?? ""
        case let url as URL: return url.absoluteString
        case let attributed as NSAttributedString: return attributed.string
        default: return ""
        }
    }

    // MARK: - UI

    private func presentUI(with text: String) {
        sourceText = text
        parsed = AppointmentParser().parse(text)

        let shareView = ShareView(sourceText: text,
                                  parsed: parsed,
                                  onContinue: { self.saveDraftAndOpenApp() },
                                  onCancel: { self.finish() })
        let hosting = UIHostingController(rootView: shareView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    // MARK: - Hand-off to the main app

    private func saveDraftAndOpenApp() {
        let draft = makeDraft()
        AppointmentStore.shared.addDraft(draft)

        let url = YadYarURL.openDraftURL(id: draft.id)
        extensionContext?.open(url) { [weak self] _ in
            // Even if opening the app fails, the draft is saved and will be
            // picked up the next time the user opens YadYar.
            self?.finish()
        }
    }

    private func makeDraft() -> AppointmentDraft {
        if let parsed {
            return AppointmentDraft(sourceText: sourceText,
                                    suggestedTitle: parsed.suggestedTitle,
                                    suggestedDate: parsed.fireDate,
                                    hasExplicitTime: parsed.hasExplicitTime,
                                    confidence: parsed.confidence)
        }
        var comps = Calendar.current.dateComponents([.year, .month, .day],
                                                    from: Date().addingTimeInterval(86400))
        comps.hour = 9
        comps.minute = 0
        return AppointmentDraft(sourceText: sourceText,
                                suggestedTitle: fallbackTitle(),
                                suggestedDate: Calendar.current.date(from: comps) ?? Date(),
                                hasExplicitTime: false,
                                confidence: 0)
    }

    private func fallbackTitle() -> String {
        let line = sourceText.components(separatedBy: .newlines).first ?? sourceText
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "قرار" : String(trimmed.prefix(48))
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
