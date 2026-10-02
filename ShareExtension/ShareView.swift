//
//  ShareView.swift
//  ShareExtension
//
//  Compact SwiftUI card shown inside the share sheet: parsed preview,
//  source text and the hand-off button.
//

import SwiftUI

struct ShareView: View {

    let sourceText: String
    let parsed: ParsedAppointment?
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .frame(width: 44, height: 5)
                .foregroundStyle(.quaternary)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.teal)
                Text("یاد یار").font(.headline)
                Spacer()
            }
            .padding()

            if let parsed {
                VStack(alignment: .leading, spacing: 6) {
                    Text(parsed.suggestedTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(AppFormat.jalaliFull(parsed.fireDate)) — ساعت \(AppFormat.clockTime(parsed.fireDate))")
                        .font(.subheadline)
                    ConfidenceLabel(confidence: parsed.confidence)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                Text(sourceText.isEmpty
                     ? "متنی برای پردازش پیدا نشد؛ داخل اپ دستی وارد کن."
                     : "تاریخ و ساعتی در متن پیدا نکردم؛ داخل اپ دستی تنظیم کن.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            }

            if !sourceText.isEmpty {
                ScrollView {
                    Text(sourceText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Spacer()

            Button(action: onContinue) {
                Label("ادامه در یاد یار", systemImage: "arrow.left.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .padding(.horizontal)

            Button("انصراف", action: onCancel)
                .font(.subheadline)
                .padding(.vertical, 10)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Local copy for the extension (it has no access to the app's asset catalog).
private struct ConfidenceLabel: View {
    let confidence: Double

    private var badge: (text: String, color: Color) {
        confidence >= 0.75 ? ("تطبیق قوی", .green)
            : confidence >= 0.5 ? ("احتمالاً قراره", .orange)
            : ("مطمئن نیستم — چک کن", .red)
    }

    var body: some View {
        Label(badge.text, systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(badge.color)
    }
}
