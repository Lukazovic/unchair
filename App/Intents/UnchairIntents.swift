import AppIntents

enum UnchairIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notReady

    var localizedStringResource: LocalizedStringResource {
        "Unchair isn't ready yet. Try again in a moment."
    }
}

@MainActor
private func runningModel() throws -> AppModel {
    guard let model = AppModel.shared else { throw UnchairIntentError.notReady }
    return model
}

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Starts a focus session, or resumes the paused one.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try runningModel().startFocus()
        return .result(dialog: "Focus session started.")
    }
}

struct StartBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Break"
    static let description = IntentDescription("Ends the current focus session and starts a break.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try runningModel().startBreak()
        return .result(dialog: "Break started.")
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Logs a glass of water.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let model = try runningModel()
        model.logWater()
        let intake = model.engine.hydration.intake(at: .now)
        let progress = String(
            localized: "\(Format.volume(intake)) of \(Format.volume(model.settings.hydration.dailyGoal)) today."
        )
        return .result(value: intake, dialog: "\(progress)")
    }
}

enum ReminderPauseDuration: String, AppEnum {
    case thirtyMinutes
    case oneHour
    case untilTomorrow

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Duration"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .thirtyMinutes: "30 Minutes",
        .oneHour: "1 Hour",
        .untilTomorrow: "Until Tomorrow",
    ]
}

struct PauseRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Reminders"
    static let description = IntentDescription("Pauses posture, water, and eye reminders for a while.")

    @Parameter(title: "Duration", default: .oneHour)
    var duration: ReminderPauseDuration

    static var parameterSummary: some ParameterSummary {
        Summary("Pause reminders for \(\.$duration)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let quietDuration = AppModel.QuietDuration(rawValue: duration.rawValue) ?? .oneHour
        try runningModel().pauseReminders(for: quietDuration)
        return .result(dialog: "Reminders paused.")
    }
}

struct GetTodayStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Today's Stats"
    static let description = IntentDescription("Returns today's focus time, standing time, and water.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try runningModel().todaySummary()
        return .result(value: summary, dialog: "\(summary)")
    }
}

struct UnchairShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: ["Start focus in \(.applicationName)", "Start a \(.applicationName) focus session"],
            shortTitle: "Start Focus",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: StartBreakIntent(),
            phrases: ["Start a break in \(.applicationName)"],
            shortTitle: "Start Break",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: ["Log water in \(.applicationName)", "I drank water \(.applicationName)"],
            shortTitle: "Log Water",
            systemImageName: "drop"
        )
        AppShortcut(
            intent: PauseRemindersIntent(),
            phrases: ["Pause \(.applicationName) reminders"],
            shortTitle: "Pause Reminders",
            systemImageName: "moon.zzz"
        )
        AppShortcut(
            intent: GetTodayStatsIntent(),
            phrases: ["How is my day in \(.applicationName)", "Get my \(.applicationName) stats"],
            shortTitle: "Today's Stats",
            systemImageName: "chart.bar"
        )
    }
}
