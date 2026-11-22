import Foundation

/// All settings that affect Unchair's timers and reminders.
public struct UnchairSettings: Codable, Equatable, Sendable {
    public var pomodoro: PomodoroSettings
    public var posture: PostureSettings
    public var hydration: HydrationSettings

    public init(
        pomodoro: PomodoroSettings = PomodoroSettings(),
        posture: PostureSettings = PostureSettings(),
        hydration: HydrationSettings = HydrationSettings()
    ) {
        self.pomodoro = pomodoro
        self.posture = posture
        self.hydration = hydration
    }
}
