import Foundation
import OSLog
import SwiftData
import UnchairCore

/// Records what happens in Unchair and reads it back as core ``History``.
/// Everything stays on this Mac.
final class HistoryStore {
    private let context: ModelContext?

    init(inMemory: Bool = false) {
        do {
            let schema = Schema([
                FocusSessionRecord.self,
                PresenceRecord.self,
                WaterRecord.self,
                ReminderRecord.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: schema, configurations: configuration)
            context = ModelContext(container)
            context?.autosaveEnabled = true
        } catch {
            Logger(subsystem: "com.lukazovic.Unchair", category: "history")
                .error("History unavailable: \(error.localizedDescription, privacy: .public)")
            context = nil
        }
    }

    // MARK: - Recording

    func recordFocusSession(_ session: FocusSession) {
        insert(FocusSessionRecord(end: session.end, duration: session.duration))
    }

    func recordPresence(_ state: PresenceState, at date: Date) {
        insert(PresenceRecord(date: date, state: state))
    }

    func recordWater(_ amount: Int, at date: Date) {
        guard amount != 0 else { return }
        insert(WaterRecord(date: date, amount: amount))
    }

    func recordReminder(_ kind: ReminderKind, _ outcome: ReminderOutcome, at date: Date) {
        insert(ReminderRecord(date: date, kind: kind, outcome: outcome))
    }

    // MARK: - Reading

    /// Records from `start` on. Presence also includes the last change before
    /// `start`, so time spent in that state is counted.
    func history(since start: Date = .distantPast) -> History {
        guard let context else { return History() }
        let focus = (try? context.fetch(FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.end >= start },
            sortBy: [SortDescriptor(\.end)]
        ))) ?? []
        let water = (try? context.fetch(FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        let reminders = (try? context.fetch(FetchDescriptor<ReminderRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        var presence = (try? context.fetch(FetchDescriptor<PresenceRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        ))) ?? []
        var previous = FetchDescriptor<PresenceRecord>(
            predicate: #Predicate { $0.date < start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        previous.fetchLimit = 1
        if let last = try? context.fetch(previous).first {
            presence.insert(last, at: 0)
        }

        return History(
            focusSessions: focus.map(\.value),
            presenceChanges: presence.compactMap(\.value),
            waterEntries: water.map(\.value),
            reminderResponses: reminders.compactMap(\.value)
        )
    }

    /// Permanently removes all recorded history.
    func deleteAll() {
        guard let context else { return }
        try? context.delete(model: FocusSessionRecord.self)
        try? context.delete(model: PresenceRecord.self)
        try? context.delete(model: WaterRecord.self)
        try? context.delete(model: ReminderRecord.self)
        try? context.save()
    }

    func save() {
        try? context?.save()
    }

    private func insert(_ model: some PersistentModel) {
        context?.insert(model)
        try? context?.save()
    }
}
