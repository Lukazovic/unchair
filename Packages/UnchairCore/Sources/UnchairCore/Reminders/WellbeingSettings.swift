import Foundation

/// 20-20-20 eye breaks: every 20 minutes, look about 20 feet (6 m) away for 20 seconds.
public struct EyeBreakSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var interval: TimeInterval
    /// While a Pomodoro session is active, skip separate eye reminders and
    /// mention resting the eyes in break notifications instead.
    public var mergeWithPomodoro: Bool

    public init(isEnabled: Bool = false, interval: TimeInterval = 20 * 60, mergeWithPomodoro: Bool = true) {
        self.isEnabled = isEnabled
        self.interval = interval
        self.mergeWithPomodoro = mergeWithPomodoro
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, interval, mergeWithPomodoro
    }

    public init(from decoder: any Decoder) throws {
        let defaults = EyeBreakSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? defaults.interval
        mergeWithPomodoro = try container.decodeIfPresent(Bool.self, forKey: .mergeWithPomodoro)
            ?? defaults.mergeWithPomodoro
    }
}

/// A gentle, widely spaced nudge to check posture.
public struct PostureCheckSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var interval: TimeInterval

    public init(isEnabled: Bool = false, interval: TimeInterval = 2 * 60 * 60) {
        self.isEnabled = isEnabled
        self.interval = interval
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, interval
    }

    public init(from decoder: any Decoder) throws {
        let defaults = PostureCheckSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        interval = try container.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? defaults.interval
    }
}

/// Options for what happens during Pomodoro breaks.
public struct BreakSettings: Codable, Equatable, Sendable {
    /// Suggest a stretch during breaks.
    public var suggestsStretches: Bool
    /// Cover the screens during breaks so the user actually stops.
    public var showsOverlay: Bool

    public init(suggestsStretches: Bool = true, showsOverlay: Bool = false) {
        self.suggestsStretches = suggestsStretches
        self.showsOverlay = showsOverlay
    }

    private enum CodingKeys: String, CodingKey {
        case suggestsStretches, showsOverlay
    }

    public init(from decoder: any Decoder) throws {
        let defaults = BreakSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        suggestsStretches = try container.decodeIfPresent(Bool.self, forKey: .suggestsStretches)
            ?? defaults.suggestsStretches
        showsOverlay = try container.decodeIfPresent(Bool.self, forKey: .showsOverlay) ?? defaults.showsOverlay
    }
}

/// End-of-day summary notification.
public struct DailySummarySettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    /// Time of the summary in minutes after midnight. When working hours are
    /// on, their end time and days are used instead.
    public var time: Int

    public init(isEnabled: Bool = true, time: Int = 18 * 60) {
        self.isEnabled = isEnabled
        self.time = time
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled, time
    }

    public init(from decoder: any Decoder) throws {
        let defaults = DailySummarySettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        time = try container.decodeIfPresent(Int.self, forKey: .time) ?? defaults.time
    }
}
