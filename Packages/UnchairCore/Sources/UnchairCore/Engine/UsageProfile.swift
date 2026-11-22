import Foundation

/// Starting points offered during onboarding. Each sets sensible defaults for
/// a way of working; everything stays adjustable afterwards.
public enum UsageProfile: String, CaseIterable, Identifiable, Sendable {
    /// Classic Pomodoro, eye breaks folded into breaks, frequent water.
    case student
    /// Longer focus blocks, working hours on weekdays, posture checks.
    case office
    /// Long focus blocks, fewer and combined interruptions.
    case deepWork

    public var id: String {
        rawValue
    }

    public func apply(to settings: inout UnchairSettings) {
        switch self {
        case .student:
            PomodoroPreset.classic.apply(to: &settings.pomodoro)
            settings.posture.sittingDuration = 45 * 60
            settings.posture.standingDuration = 15 * 60
            settings.hydration.reminderInterval = 45 * 60
            settings.eyes.isEnabled = true
            settings.eyes.mergeWithPomodoro = true
            settings.interruptions.workingHours.isEnabled = false
        case .office:
            PomodoroPreset.extended.apply(to: &settings.pomodoro)
            settings.posture.sittingDuration = 45 * 60
            settings.posture.standingDuration = 15 * 60
            settings.hydration.reminderInterval = 60 * 60
            settings.postureCheck.isEnabled = true
            settings.interruptions.workingHours = WorkingHours(isEnabled: true)
        case .deepWork:
            PomodoroPreset.deepWork.apply(to: &settings.pomodoro)
            settings.posture.sittingDuration = 60 * 60
            settings.posture.standingDuration = 15 * 60
            settings.posture.syncWithPomodoro = true
            settings.hydration.reminderInterval = 90 * 60
            settings.eyes.isEnabled = false
            settings.interruptions.coalescingWindow = 10 * 60
        }
    }
}
