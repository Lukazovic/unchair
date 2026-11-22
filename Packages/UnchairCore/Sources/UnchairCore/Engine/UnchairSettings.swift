import Foundation

/// All settings that affect Unchair's timers and reminders.
public struct UnchairSettings: Codable, Equatable, Sendable {
    public var pomodoro: PomodoroSettings
    public var posture: PostureSettings
    public var hydration: HydrationSettings
    public var interruptions: InterruptionSettings

    public init(
        pomodoro: PomodoroSettings = PomodoroSettings(),
        posture: PostureSettings = PostureSettings(),
        hydration: HydrationSettings = HydrationSettings(),
        interruptions: InterruptionSettings = InterruptionSettings()
    ) {
        self.pomodoro = pomodoro
        self.posture = posture
        self.hydration = hydration
        self.interruptions = interruptions
    }

    private enum CodingKeys: String, CodingKey {
        case pomodoro, posture, hydration, interruptions
    }

    /// Missing sections fall back to defaults, so adding settings never discards saved ones.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pomodoro = try container.decodeIfPresent(PomodoroSettings.self, forKey: .pomodoro) ?? PomodoroSettings()
        posture = try container.decodeIfPresent(PostureSettings.self, forKey: .posture) ?? PostureSettings()
        hydration = try container.decodeIfPresent(HydrationSettings.self, forKey: .hydration) ?? HydrationSettings()
        interruptions = try container.decodeIfPresent(InterruptionSettings.self, forKey: .interruptions)
            ?? InterruptionSettings()
    }
}
