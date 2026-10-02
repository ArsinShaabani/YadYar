//
//  ConfidenceBadge.swift
//  YadYar
//
//  Shows how confident the parser is about the extracted appointment.
//

import SwiftUI

struct ConfidenceBadge: View {

    let confidence: Double

    private var badge: (text: String, color: Color) {
        confidence >= 0.75 ? ("تطبیق قوی", .green)
            : confidence >= 0.5 ? ("احتمالاً قراره", .orange)
            : ("مطمئن نیستم — چک کن", .red)
    }

    var body: some View {
        Label(badge.text, systemImage: "sparkles")
            .font(.subheadline)
            .foregroundStyle(badge.color)
    }
}
