//
//  AppointmentStore.swift
//  Shared
//
//  JSON persistence inside the App Group container so both the main app and
//  the Share Extension see the same data:
//    • appointments.json — written by the app
//    • drafts.json       — written by the Share Extension, consumed by the app
//

import Foundation

public final class AppointmentStore {

    public static let shared = AppointmentStore()

    private let queue = DispatchQueue(label: "ir.yadyar.appointmentstore")
    private let appointmentsURL: URL
    private let draftsURL: URL

    public init(directory: URL? = nil) {
        let base: URL
        if let directory = directory {
            base = directory
        } else if let group = AppGroup.containerURL {
            base = group.appendingPathComponent("Data", isDirectory: true)
        } else {
            base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        appointmentsURL = base.appendingPathComponent("appointments.json")
        draftsURL = base.appendingPathComponent("drafts.json")
    }

    // MARK: - Appointments

    public func allAppointments() -> [Appointment] {
        queue.sync { load([Appointment].self, from: appointmentsURL) ?? [] }
    }

    public func appointment(id: UUID) -> Appointment? {
        queue.sync { (load([Appointment].self, from: appointmentsURL) ?? []).first { $0.id == id } }
    }

    public func save(_ appointment: Appointment) {
        queue.sync {
            var list = load([Appointment].self, from: appointmentsURL) ?? []
            if let index = list.firstIndex(where: { $0.id == appointment.id }) {
                list[index] = appointment
            } else {
                list.append(appointment)
            }
            write(list, to: appointmentsURL)
        }
    }

    public func delete(id: UUID) {
        queue.sync {
            var list = load([Appointment].self, from: appointmentsURL) ?? []
            list.removeAll { $0.id == id }
            write(list, to: appointmentsURL)
        }
    }

    public func markDone(id: UUID, done: Bool = true) {
        queue.sync {
            var list = load([Appointment].self, from: appointmentsURL) ?? []
            if let index = list.firstIndex(where: { $0.id == id }) {
                list[index].isDone = done
                write(list, to: appointmentsURL)
            }
        }
    }

    // MARK: - Drafts

    public func drafts() -> [AppointmentDraft] {
        queue.sync { load([AppointmentDraft].self, from: draftsURL) ?? [] }
    }

    public func draft(id: UUID) -> AppointmentDraft? {
        queue.sync { (load([AppointmentDraft].self, from: draftsURL) ?? []).first { $0.id == id } }
    }

    public func addDraft(_ draft: AppointmentDraft) {
        queue.sync {
            var list = load([AppointmentDraft].self, from: draftsURL) ?? []
            list.removeAll { $0.id == draft.id }
            list.append(draft)
            write(list, to: draftsURL)
        }
    }

    public func removeDraft(id: UUID) {
        queue.sync {
            var list = load([AppointmentDraft].self, from: draftsURL) ?? []
            list.removeAll { $0.id == id }
            write(list, to: draftsURL)
        }
    }

    // MARK: - Persistence

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
