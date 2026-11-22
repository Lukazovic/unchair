import Foundation

public struct HydrationSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var reminderInterval: TimeInterval
    /// Daily goal in milliliters.
    public var dailyGoal: Int
    /// Amount logged per glass, in milliliters.
    public var glassSize: Int

    public init(
        isEnabled: Bool = true,
        reminderInterval: TimeInterval = 60 * 60,
        dailyGoal: Int = 2000,
        glassSize: Int = 250
    ) {
        self.isEnabled = isEnabled
        self.reminderInterval = reminderInterval
        self.dailyGoal = dailyGoal
        self.glassSize = glassSize
    }
}

/// Water intake for one calendar day.
public struct HydrationLog: Codable, Equatable, Sendable {
    /// Start of the day this log belongs to.
    public var day: Date
    /// Intake in milliliters.
    public var intake: Int

    public init(day: Date, intake: Int = 0) {
        self.day = day
        self.intake = intake
    }
}

public enum HydrationEvent: Equatable, Sendable {
    /// Time to drink. Carries today's intake and goal, in milliliters.
    case reminder(intake: Int, goal: Int)
}

/// Tracks daily water intake and reminds the user to drink at an interval.
///
/// Logging a glass restarts the interval. Intake resets at the start of each
/// calendar day.
public struct HydrationTracker: Equatable, Sendable {
    public var settings: HydrationSettings
    public private(set) var log: HydrationLog
    public private(set) var nextReminderAt: Date?
    private let calendar: Calendar

    public init(
        settings: HydrationSettings = HydrationSettings(),
        log: HydrationLog? = nil,
        calendar: Calendar = .current,
        now: Date
    ) {
        self.settings = settings
        self.calendar = calendar
        self.log = log ?? HydrationLog(day: calendar.startOfDay(for: now))
        rollOverIfNeeded(now: now)
    }

    /// Intake on the day containing `now`.
    public func intake(at now: Date) -> Int {
        calendar.isDate(log.day, inSameDayAs: now) ? log.intake : 0
    }

    /// Progress toward the daily goal on the day containing `now`, from 0 to 1.
    public func progress(at now: Date) -> Double {
        guard settings.dailyGoal > 0 else { return 1 }
        return min(1, Double(intake(at: now)) / Double(settings.dailyGoal))
    }

    public mutating func start(now: Date) {
        rollOverIfNeeded(now: now)
        nextReminderAt = now.addingTimeInterval(settings.reminderInterval)
    }

    public mutating func stop() {
        nextReminderAt = nil
    }

    /// Logs one glass and restarts the reminder interval.
    public mutating func logGlass(now: Date) {
        log(amount: settings.glassSize, now: now)
        if nextReminderAt != nil {
            nextReminderAt = now.addingTimeInterval(settings.reminderInterval)
        }
    }

    /// Removes one glass, for example to undo a mistaken log.
    public mutating func removeGlass(now: Date) {
        log(amount: -settings.glassSize, now: now)
    }

    public mutating func snooze(by interval: TimeInterval, now: Date) {
        guard nextReminderAt != nil else { return }
        nextReminderAt = now.addingTimeInterval(interval)
    }

    /// Reminds the user when the interval has passed, then schedules the next one.
    public mutating func tick(now: Date) -> HydrationEvent? {
        rollOverIfNeeded(now: now)
        guard let nextReminderAt, now >= nextReminderAt else { return nil }
        self.nextReminderAt = now.addingTimeInterval(settings.reminderInterval)
        return .reminder(intake: log.intake, goal: settings.dailyGoal)
    }

    private mutating func log(amount: Int, now: Date) {
        rollOverIfNeeded(now: now)
        log.intake = max(0, log.intake + amount)
    }

    private mutating func rollOverIfNeeded(now: Date) {
        guard !calendar.isDate(log.day, inSameDayAs: now) else { return }
        log = HydrationLog(day: calendar.startOfDay(for: now))
    }
}
