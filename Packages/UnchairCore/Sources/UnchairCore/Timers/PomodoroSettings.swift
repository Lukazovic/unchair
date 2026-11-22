import Foundation

/// The phases of a Pomodoro cycle.
public enum PomodoroPhase: String, Codable, Sendable, CaseIterable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool {
        self != .focus
    }
}

/// User-configurable Pomodoro durations and behavior.
public struct PomodoroSettings: Codable, Equatable, Sendable {
    public var focusDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    /// Number of completed focus sessions before a long break. Values below 1 are treated as 1.
    public var sessionsBeforeLongBreak: Int
    public var autoStartBreaks: Bool
    public var autoStartFocus: Bool

    public init(
        focusDuration: TimeInterval = 25 * 60,
        shortBreakDuration: TimeInterval = 5 * 60,
        longBreakDuration: TimeInterval = 15 * 60,
        sessionsBeforeLongBreak: Int = 4,
        autoStartBreaks: Bool = true,
        autoStartFocus: Bool = false
    ) {
        self.focusDuration = focusDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.sessionsBeforeLongBreak = sessionsBeforeLongBreak
        self.autoStartBreaks = autoStartBreaks
        self.autoStartFocus = autoStartFocus
    }

    public func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }
}

/// Common duration presets. Research finds nothing special about 25 minutes,
/// so longer presets are offered for deep work.
public enum PomodoroPreset: String, CaseIterable, Identifiable, Sendable {
    /// 25 min focus, 5 min short break, 15 min long break.
    case classic
    /// 50 min focus, 10 min short break, 20 min long break.
    case extended
    /// 90 min focus, 20 min short break, 30 min long break.
    case deepWork

    public var id: String {
        rawValue
    }

    public var focusDuration: TimeInterval {
        switch self {
        case .classic: 25 * 60
        case .extended: 50 * 60
        case .deepWork: 90 * 60
        }
    }

    public var shortBreakDuration: TimeInterval {
        switch self {
        case .classic: 5 * 60
        case .extended: 10 * 60
        case .deepWork: 20 * 60
        }
    }

    public var longBreakDuration: TimeInterval {
        switch self {
        case .classic: 15 * 60
        case .extended: 20 * 60
        case .deepWork: 30 * 60
        }
    }

    /// Overwrites the durations in `settings`, keeping the other options.
    public func apply(to settings: inout PomodoroSettings) {
        settings.focusDuration = focusDuration
        settings.shortBreakDuration = shortBreakDuration
        settings.longBreakDuration = longBreakDuration
    }

    /// The preset whose durations match `settings`, or `nil` for custom durations.
    public static func matching(_ settings: PomodoroSettings) -> PomodoroPreset? {
        allCases.first {
            $0.focusDuration == settings.focusDuration
                && $0.shortBreakDuration == settings.shortBreakDuration
                && $0.longBreakDuration == settings.longBreakDuration
        }
    }
}
