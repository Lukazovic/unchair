import Foundation

/// Settings that decide when Unchair should *not* interrupt.
public struct InterruptionSettings: Codable, Equatable, Sendable {
    /// Reminders due within this window of each other are delivered together.
    public var coalescingWindow: TimeInterval
    /// Pause a running focus session while the user is away.
    public var pauseFocusWhenAway: Bool
    /// Inactivity after which the user counts as away. Also the minimum
    /// absence that counts as a natural break for posture.
    public var awayThreshold: TimeInterval
    /// Hold reminders while the microphone or camera is in use.
    public var holdDuringMeetings: Bool
    /// Hold reminders while the frontmost app is full screen.
    public var holdDuringFullscreen: Bool
    public var workingHours: WorkingHours

    public init(
        coalescingWindow: TimeInterval = 5 * 60,
        pauseFocusWhenAway: Bool = true,
        awayThreshold: TimeInterval = 5 * 60,
        holdDuringMeetings: Bool = true,
        holdDuringFullscreen: Bool = true,
        workingHours: WorkingHours = WorkingHours()
    ) {
        self.coalescingWindow = coalescingWindow
        self.pauseFocusWhenAway = pauseFocusWhenAway
        self.awayThreshold = awayThreshold
        self.holdDuringMeetings = holdDuringMeetings
        self.holdDuringFullscreen = holdDuringFullscreen
        self.workingHours = workingHours
    }

    private enum CodingKeys: String, CodingKey {
        case coalescingWindow, pauseFocusWhenAway, awayThreshold
        case holdDuringMeetings, holdDuringFullscreen, workingHours
    }

    /// Missing keys fall back to defaults, so adding settings never discards saved ones.
    public init(from decoder: any Decoder) throws {
        let defaults = InterruptionSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coalescingWindow = try container.decodeIfPresent(TimeInterval.self, forKey: .coalescingWindow)
            ?? defaults.coalescingWindow
        pauseFocusWhenAway = try container.decodeIfPresent(Bool.self, forKey: .pauseFocusWhenAway)
            ?? defaults.pauseFocusWhenAway
        awayThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .awayThreshold)
            ?? defaults.awayThreshold
        holdDuringMeetings = try container.decodeIfPresent(Bool.self, forKey: .holdDuringMeetings)
            ?? defaults.holdDuringMeetings
        holdDuringFullscreen = try container.decodeIfPresent(Bool.self, forKey: .holdDuringFullscreen)
            ?? defaults.holdDuringFullscreen
        workingHours = try container.decodeIfPresent(WorkingHours.self, forKey: .workingHours)
            ?? defaults.workingHours
    }
}

/// Days and hours when reminders are allowed.
public struct WorkingHours: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    /// `Calendar` weekday numbers: 1 is Sunday, 7 is Saturday.
    public var weekdays: Set<Int>
    /// Start time in minutes after midnight.
    public var start: Int
    /// End time in minutes after midnight. Must be after `start`.
    public var end: Int

    public init(
        isEnabled: Bool = false,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        start: Int = 9 * 60,
        end: Int = 18 * 60
    ) {
        self.isEnabled = isEnabled
        self.weekdays = weekdays
        self.start = start
        self.end = end
    }

    /// Whether reminders are allowed at `date`. Always `true` when disabled.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard isEnabled else { return true }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday, weekdays.contains(weekday),
              let hour = components.hour, let minute = components.minute
        else { return false }
        let minutes = hour * 60 + minute
        return minutes >= start && minutes < end
    }

    /// The next moment after `date` when ``contains(_:calendar:)`` changes, or
    /// `nil` when disabled or when it never changes.
    public func nextTransition(after date: Date, calendar: Calendar) -> Date? {
        guard isEnabled else { return nil }
        let current = contains(date, calendar: calendar)
        var day = calendar.startOfDay(for: date)
        for _ in 0 ..< 9 {
            for minutes in [start, end] {
                guard let candidate = calendar.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: day
                ) else { continue }
                if candidate > date, contains(candidate, calendar: calendar) != current {
                    return candidate
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = nextDay
        }
        return nil
    }
}
