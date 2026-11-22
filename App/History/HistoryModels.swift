import Foundation
import SwiftData
import UnchairCore

// SwiftData mirrors of the core history records. Raw values are stored as
// strings so new cases never break existing stores.

@Model
final class FocusSessionRecord {
    var end: Date
    var duration: TimeInterval

    init(end: Date, duration: TimeInterval) {
        self.end = end
        self.duration = duration
    }

    var value: FocusSession {
        FocusSession(end: end, duration: duration)
    }
}

@Model
final class PresenceRecord {
    var date: Date
    var state: String

    init(date: Date, state: PresenceState) {
        self.date = date
        self.state = state.rawValue
    }

    var value: PresenceChange? {
        PresenceState(rawValue: state).map { PresenceChange(date: date, state: $0) }
    }
}

@Model
final class WaterRecord {
    var date: Date
    var amount: Int

    init(date: Date, amount: Int) {
        self.date = date
        self.amount = amount
    }

    var value: WaterEntry {
        WaterEntry(date: date, amount: amount)
    }
}

@Model
final class ReminderRecord {
    var date: Date
    var kind: String
    var outcome: String

    init(date: Date, kind: ReminderKind, outcome: ReminderOutcome) {
        self.date = date
        self.kind = kind.rawValue
        self.outcome = outcome.rawValue
    }

    var value: ReminderResponse? {
        guard let kind = ReminderKind(rawValue: kind), let outcome = ReminderOutcome(rawValue: outcome) else {
            return nil
        }
        return ReminderResponse(date: date, kind: kind, outcome: outcome)
    }
}
