import Foundation

/// A completed focus session.
public struct FocusSession: Codable, Equatable, Sendable {
    public var end: Date
    public var duration: TimeInterval

    public init(end: Date, duration: TimeInterval) {
        self.end = end
        self.duration = duration
    }

    public var start: Date {
        end.addingTimeInterval(-duration)
    }
}

/// Where the user is, as far as Unchair knows.
public enum PresenceState: String, Codable, Sendable, CaseIterable {
    case sitting
    case standing
    case away
}

/// The user's presence changed at `date`. Each change lasts until the next one.
public struct PresenceChange: Codable, Equatable, Sendable {
    public var date: Date
    public var state: PresenceState

    public init(date: Date, state: PresenceState) {
        self.date = date
        self.state = state
    }
}

/// Water logged (positive) or removed (negative), in milliliters.
public struct WaterEntry: Codable, Equatable, Sendable {
    public var date: Date
    public var amount: Int

    public init(date: Date, amount: Int) {
        self.date = date
        self.amount = amount
    }
}

public enum ReminderKind: String, Codable, Sendable, CaseIterable {
    case posture
    case hydration
    case eyes
    case postureCheck
}

public enum ReminderOutcome: String, Codable, Sendable, CaseIterable {
    case delivered
    case completed
    case snoozed
}

/// What happened to a reminder.
public struct ReminderResponse: Codable, Equatable, Sendable {
    public var date: Date
    public var kind: ReminderKind
    public var outcome: ReminderOutcome

    public init(date: Date, kind: ReminderKind, outcome: ReminderOutcome) {
        self.date = date
        self.kind = kind
        self.outcome = outcome
    }
}

/// Everything Unchair records, in a portable form for statistics and export.
public struct History: Codable, Equatable, Sendable {
    public var focusSessions: [FocusSession]
    public var presenceChanges: [PresenceChange]
    public var waterEntries: [WaterEntry]
    public var reminderResponses: [ReminderResponse]

    public init(
        focusSessions: [FocusSession] = [],
        presenceChanges: [PresenceChange] = [],
        waterEntries: [WaterEntry] = [],
        reminderResponses: [ReminderResponse] = []
    ) {
        self.focusSessions = focusSessions
        self.presenceChanges = presenceChanges
        self.waterEntries = waterEntries
        self.reminderResponses = reminderResponses
    }
}
