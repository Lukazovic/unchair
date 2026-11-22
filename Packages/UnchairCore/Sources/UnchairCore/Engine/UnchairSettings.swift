import Foundation

/// All settings that affect Unchair's timers and reminders.
public struct UnchairSettings: Codable, Equatable, Sendable {
    public var pomodoro: PomodoroSettings
    public var posture: PostureSettings
    public var hydration: HydrationSettings
    public var interruptions: InterruptionSettings
    public var eyes: EyeBreakSettings
    public var postureCheck: PostureCheckSettings
    public var breaks: BreakSettings
    public var summary: DailySummarySettings
    public var alerts: AlertSettings

    public init(
        pomodoro: PomodoroSettings = PomodoroSettings(),
        posture: PostureSettings = PostureSettings(),
        hydration: HydrationSettings = HydrationSettings(),
        interruptions: InterruptionSettings = InterruptionSettings(),
        eyes: EyeBreakSettings = EyeBreakSettings(),
        postureCheck: PostureCheckSettings = PostureCheckSettings(),
        breaks: BreakSettings = BreakSettings(),
        summary: DailySummarySettings = DailySummarySettings(),
        alerts: AlertSettings = AlertSettings()
    ) {
        self.pomodoro = pomodoro
        self.posture = posture
        self.hydration = hydration
        self.interruptions = interruptions
        self.eyes = eyes
        self.postureCheck = postureCheck
        self.breaks = breaks
        self.summary = summary
        self.alerts = alerts
    }

    private enum CodingKeys: String, CodingKey {
        case pomodoro, posture, hydration, interruptions, eyes, postureCheck, breaks, summary, alerts
    }

    /// Missing sections fall back to defaults, so adding settings never discards saved ones.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pomodoro = try container.decodeIfPresent(PomodoroSettings.self, forKey: .pomodoro) ?? PomodoroSettings()
        posture = try container.decodeIfPresent(PostureSettings.self, forKey: .posture) ?? PostureSettings()
        hydration = try container.decodeIfPresent(HydrationSettings.self, forKey: .hydration) ?? HydrationSettings()
        interruptions = try container.decodeIfPresent(InterruptionSettings.self, forKey: .interruptions)
            ?? InterruptionSettings()
        eyes = try container.decodeIfPresent(EyeBreakSettings.self, forKey: .eyes) ?? EyeBreakSettings()
        postureCheck = try container.decodeIfPresent(PostureCheckSettings.self, forKey: .postureCheck)
            ?? PostureCheckSettings()
        breaks = try container.decodeIfPresent(BreakSettings.self, forKey: .breaks) ?? BreakSettings()
        summary = try container.decodeIfPresent(DailySummarySettings.self, forKey: .summary) ?? DailySummarySettings()
        alerts = try container.decodeIfPresent(AlertSettings.self, forKey: .alerts) ?? AlertSettings()
    }
}
