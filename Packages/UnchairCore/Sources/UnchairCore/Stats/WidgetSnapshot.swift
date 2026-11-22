import Foundation

/// What widgets show, written by the app and read by the widget extension.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// App Group shared by the app and the widget extension.
    public static let appGroupIdentifier = "group.com.lukazovic.Unchair"
    private static let defaultsKey = "widgetSnapshot.v1"

    /// The last snapshot the app saved, or `nil` if there is none.
    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)) -> Self? {
        guard let data = defaults?.data(forKey: defaultsKey) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Self.self, from: data)
    }

    public func save(to defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.defaultsKey)
    }

    public enum TimerState: Codable, Equatable, Sendable {
        case idle
        case running(PomodoroPhase, endsAt: Date)
        case paused(PomodoroPhase, remaining: TimeInterval)
        case awaiting(PomodoroPhase)
    }

    public var updatedAt: Date
    public var timer: TimerState
    public var posture: Posture?
    public var focusSessionsToday: Int
    public var focusTimeToday: TimeInterval
    public var standingTimeToday: TimeInterval
    public var waterToday: Int
    public var waterGoal: Int

    public init(
        updatedAt: Date,
        timer: TimerState = .idle,
        posture: Posture? = nil,
        focusSessionsToday: Int = 0,
        focusTimeToday: TimeInterval = 0,
        standingTimeToday: TimeInterval = 0,
        waterToday: Int = 0,
        waterGoal: Int = 2000
    ) {
        self.updatedAt = updatedAt
        self.timer = timer
        self.posture = posture
        self.focusSessionsToday = focusSessionsToday
        self.focusTimeToday = focusTimeToday
        self.standingTimeToday = standingTimeToday
        self.waterToday = waterToday
        self.waterGoal = waterGoal
    }

    /// Builds a snapshot from the engine and today's totals.
    public init(engine: UnchairEngine, today: DayStats, now: Date) {
        let timer: TimerState = switch engine.pomodoro.state {
        case .idle: .idle
        case let .running(phase, endsAt, _): .running(phase, endsAt: endsAt)
        case let .paused(phase, remaining, _): .paused(phase, remaining: remaining)
        case let .awaiting(phase): .awaiting(phase)
        }
        self.init(
            updatedAt: now,
            timer: timer,
            posture: engine.posture.state == .stopped ? nil : engine.posture.posture,
            focusSessionsToday: today.focusSessions,
            focusTimeToday: today.focusTime,
            standingTimeToday: today.standingTime,
            waterToday: engine.hydration.intake(at: now),
            waterGoal: engine.settings.hydration.dailyGoal
        )
    }
}
