//
//  ContentView.swift
//  YadYar
//
//  Main list: upcoming appointments, archive, pending drafts banner and
//  entry points (manual / clipboard / settings).
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showSettings = false
    @State private var searchText = ""
    @State private var categoryFilter: AppointmentCategory?
    @AppStorage("displayCalendar") private var displayCalendarRaw = DisplayCalendar.jalali.rawValue

    private var displayCalendar: DisplayCalendar {
        DisplayCalendar(rawValue: displayCalendarRaw) ?? .jalali
    }

    private var filteredUpcoming: [Appointment] {
        filter(viewModel.upcoming)
    }

    private var filteredArchive: [Appointment] {
        filter(viewModel.archive)
    }

    private func filter(_ list: [Appointment]) -> [Appointment] {
        var result = list
        if let categoryFilter {
            result = result.filter { $0.category == categoryFilter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.sourceText.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.appointments.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("یاد یار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $viewModel.sheet) { mode in
                ConfirmAppointmentView(mode: mode)
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .overlay(alignment: .bottom) { toastView }
            .alert("خطا",
                   isPresented: Binding(
                        get: { viewModel.errorMessage != nil },
                        set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("باشه", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            if viewModel.pendingDraftCount > 0 {
                Section {
                    Button {
                        viewModel.openFirstDraft()
                    } label: {
                        Label("\(AppFormat.persianDigits(String(viewModel.pendingDraftCount))) پیش‌نویس منتظر تأیید",
                              systemImage: "tray.full")
                    }
                }
            }
            Section("پیش رو") {
                if filteredUpcoming.isEmpty {
                    Text("قراری پیدا نشد.").foregroundStyle(.secondary)
                }
                ForEach(filteredUpcoming) { appointment in
                    AppointmentRow(appointment: appointment, calendar: displayCalendar)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(appointment)
                            } label: { Label("حذف", systemImage: "trash") }
                            Button {
                                viewModel.toggleDone(appointment)
                            } label: { Label("انجام شد", systemImage: "checkmark") }
                            .tint(.green)
                            Button {
                                viewModel.postpone(appointment, byMinutes: 60)
                            } label: { Label("+۱ ساعت", systemImage: "clock.arrow.circlepath") }
                            .tint(.orange)
                        }
                        .contextMenu {
                            Button {
                                viewModel.postpone(appointment, byMinutes: 60)
                            } label: { Label("تعویق ۱ ساعت", systemImage: "clock.arrow.circlepath") }
                            Button {
                                viewModel.postpone(appointment, byMinutes: 24 * 60)
                            } label: { Label("تعویق ۱ روز", systemImage: "calendar.badge.clock") }
                            ShareLink(item: shareText(for: appointment)) {
                                Label("اشتراک‌گذاری متن قرار", systemImage: "square.and.arrow.up")
                            }
                        }
                }
            }
            if !filteredArchive.isEmpty {
                Section("گذشته / انجام‌شده") {
                    ForEach(filteredArchive) { appointment in
                        AppointmentRow(appointment: appointment, calendar: displayCalendar)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.delete(appointment)
                                } label: { Label("حذف", systemImage: "trash") }
                            }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "جستجو در قرارها…")
    }

    private func shareText(for appointment: Appointment) -> String {
        "📅 \(appointment.title)\n🗓 \(AppFormat.fullDate(appointment.fireDate, calendar: displayCalendar)) — ساعت \(AppFormat.clockTime(appointment.fireDate))\n(یاد یار)"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.badge")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("یاد یار").font(.title2).bold()
            Text("روی متن هر پیامی Share بزن تا اینجا یادآور ساخته بشه.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button {
                    viewModel.sheet = .manual
                } label: { Label("یادآور دستی", systemImage: "square.and.pencil") }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.parseClipboard()
                } label: { Label("از کلیپ‌بورد", systemImage: "doc.on.clipboard") }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Toolbar & toast

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    categoryFilter = nil
                } label: {
                    Label(categoryFilter == nil ? "همه (فعال)" : "همه",
                          systemImage: categoryFilter == nil ? "checkmark" : "line.3.horizontal.decrease")
                }
                ForEach(AppointmentCategory.allCases) { category in
                    Button {
                        categoryFilter = categoryFilter == category ? nil : category
                    } label: {
                        Label(category.label,
                              systemImage: categoryFilter == category ? "checkmark" : category.icon)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            Menu {
                Button {
                    viewModel.sheet = .manual
                } label: { Label("یادآور دستی", systemImage: "square.and.pencil") }
                Button {
                    viewModel.parseClipboard()
                } label: { Label("از کلیپ‌بورد", systemImage: "doc.on.clipboard") }
            } label: {
                Image(systemName: "plus")
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = viewModel.toast {
            Text(toast)
                .font(.footnote)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 24)
                .task(id: toast) {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    viewModel.toast = nil
                }
        }
    }
}
