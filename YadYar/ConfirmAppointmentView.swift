//
//  ConfirmAppointmentView.swift
//  YadYar
//
//  Confirmation / editing sheet for drafts from the Share Extension,
//  clipboard text and manual entry. Date picker shows the Jalali calendar.
//

import SwiftUI

struct ConfirmAppointmentView: View {

    let mode: AppViewModel.SheetMode

    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultReminderOffset") private var defaultOffsetRaw = ReminderOffset.hour1.rawValue
    @AppStorage("defaultCategory") private var defaultCategoryRaw = AppointmentCategory.general.rawValue
    @AppStorage("timeSensitiveDefault") private var timeSensitiveDefault = true
    @AppStorage("syncCalendarDefault") private var syncCalendarDefault = false

    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = true
    @State private var offset: ReminderOffset = .hour1
    @State private var category: AppointmentCategory = .general
    @State private var repeatRule: RepeatRule = .none
    @State private var isTimeSensitive = true
    @State private var syncToCalendar = false
    @State private var sourceText = ""
    @State private var source: AppointmentSource = .manual
    @State private var draft: AppointmentDraft?
    @State private var confidence: Double?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if !sourceText.isEmpty {
                    Section("متن دریافتی") {
                        Text(sourceText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let confidence {
                    Section { ConfidenceBadge(confidence: confidence) }
                }
                Section("جزئیات قرار") {
                    TextField("عنوان", text: $title)
                    Toggle("ساعت مشخص دارم", isOn: $hasTime)
                    DatePicker("تاریخ", selection: $date, displayedComponents: .date)
                        .environment(\.calendar, persianCalendar)
                    if hasTime {
                        DatePicker("ساعت", selection: $date, displayedComponents: .hourAndMinute)
                    }
                    Picker("یادآوری قبل از قرار", selection: $offset) {
                        ForEach(ReminderOffset.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    Picker("دسته", selection: $category) {
                        ForEach(AppointmentCategory.allCases) { value in
                            Label(value.label, systemImage: value.icon).tag(value)
                        }
                    }
                    Picker("تکرار", selection: $repeatRule) {
                        ForEach(RepeatRule.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    Toggle("اعلان Time-Sensitive", isOn: $isTimeSensitive)
                    Toggle("ثبت در تقویم هم", isOn: $syncToCalendar)
                }
                Section("خلاصه") {
                    LabeledContent("تاریخ", value: AppFormat.jalaliFull(date))
                    LabeledContent("ساعت", value: hasTime ? AppFormat.clockTime(date) : "۹:۰۰ (پیش‌فرض)")
                }
                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("ثبت یادآور", systemImage: "bell.badge.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .navigationTitle(draft == nil && sourceText.isEmpty ? "یادآور جدید" : "تأیید قرار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("انصراف") {
                        if let draft { viewModel.discardDraft(draft) }
                        viewModel.sheet = nil
                        dismiss()
                    }
                }
            }
        }
        .onAppear { seed() }
    }

    private var persianCalendar: Calendar {
        var calendar = Calendar(identifier: .persian)
        calendar.locale = Locale(identifier: "fa_IR")
        return calendar
    }

    private func seed() {
        category = AppointmentCategory(rawValue: defaultCategoryRaw) ?? .general
        isTimeSensitive = timeSensitiveDefault
        syncToCalendar = syncCalendarDefault
        switch mode {
        case .draft(let d):
            draft = d
            sourceText = d.sourceText
            source = .shareExtension
            title = d.suggestedTitle
            date = d.suggestedDate
            hasTime = d.hasExplicitTime
            confidence = d.confidence
            offset = ReminderOffset(rawValue: defaultOffsetRaw) ?? .hour1
        case .clipboard(let text, let parsed):
            sourceText = text
            source = .clipboard
            if let parsed {
                title = parsed.suggestedTitle
                date = parsed.fireDate
                hasTime = parsed.hasExplicitTime
                confidence = parsed.confidence
            } else {
                title = firstLine(of: text)
                date = defaultDate()
                hasTime = true
            }
            offset = ReminderOffset(rawValue: defaultOffsetRaw) ?? .hour1
        case .manual:
            title = ""
            date = defaultDate()
            hasTime = true
            offset = ReminderOffset(rawValue: defaultOffsetRaw) ?? .hour1
        }
    }

    private func defaultDate() -> Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? tomorrow
    }

    private func firstLine(of text: String) -> String {
        let line = text.components(separatedBy: .newlines).first ?? text
        return String(line.trimmingCharacters(in: .whitespaces).prefix(48))
    }

    private func save() {
        isSaving = true
        var fireDate = date
        if !hasTime {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
            comps.hour = 9
            comps.minute = 0
            fireDate = Calendar.current.date(from: comps) ?? date
        }
        Task {
            await viewModel.createAppointment(title: title, fireDate: fireDate,
                                              hasExplicitTime: hasTime, offset: offset,
                                              category: category, repeatRule: repeatRule,
                                              isTimeSensitive: isTimeSensitive,
                                              syncToCalendar: syncToCalendar,
                                              sourceText: sourceText, source: source, draft: draft)
            isSaving = false
            dismiss()
        }
    }
}
