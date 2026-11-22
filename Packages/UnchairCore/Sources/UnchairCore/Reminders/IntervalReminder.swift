import Foundation

/// A reminder that repeats at a fixed interval, restarting whenever it fires
/// or is acknowledged. Used for eye breaks and posture checks.
public struct IntervalReminder: Equatable, Sendable {
    public var interval: TimeInterval
    public private(set) var nextReminderAt: Date?

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    public var isRunning: Bool {
        nextReminderAt != nil
    }

    public mutating func start(now: Date) {
        nextReminderAt = now.addingTimeInterval(interval)
    }

    public mutating func stop() {
        nextReminderAt = nil
    }

    /// Restarts the interval, for example after the user did what was asked.
    public mutating func acknowledge(now: Date) {
        guard isRunning else { return }
        start(now: now)
    }

    public mutating func snooze(by duration: TimeInterval, now: Date) {
        guard isRunning else { return }
        nextReminderAt = now.addingTimeInterval(duration)
    }

    /// Fires when due (or due by `dueBy`) and schedules the next reminder.
    ///
    /// - Returns: Whether the reminder fired.
    public mutating func tick(now: Date, dueBy: Date? = nil) -> Bool {
        guard let nextReminderAt, max(now, dueBy ?? now) >= nextReminderAt else { return false }
        start(now: now)
        return true
    }
}
