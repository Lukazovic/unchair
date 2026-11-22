import Testing
@testable import UnchairCore

@Suite("UsageProfile")
struct UsageProfileTests {
    func settings(for profile: UsageProfile) -> UnchairSettings {
        var settings = UnchairSettings()
        profile.apply(to: &settings)
        return settings
    }

    @Test("student uses the classic Pomodoro with eye breaks in breaks")
    func student() {
        let settings = settings(for: .student)

        #expect(PomodoroPreset.matching(settings.pomodoro) == .classic)
        #expect(settings.eyes.isEnabled)
        #expect(settings.eyes.mergeWithPomodoro)
    }

    @Test("office uses longer blocks and weekday working hours")
    func office() {
        let settings = settings(for: .office)

        #expect(PomodoroPreset.matching(settings.pomodoro) == .extended)
        #expect(settings.interruptions.workingHours.isEnabled)
        #expect(settings.interruptions.workingHours.weekdays == [2, 3, 4, 5, 6])
        #expect(settings.postureCheck.isEnabled)
    }

    @Test("deep work interrupts less")
    func deepWork() {
        let settings = settings(for: .deepWork)

        #expect(PomodoroPreset.matching(settings.pomodoro) == .deepWork)
        #expect(settings.interruptions.coalescingWindow == 10 * 60)
        #expect(!settings.eyes.isEnabled)
        #expect(settings.hydration.reminderInterval == 90 * 60)
    }

    @Test("profiles keep reminders the user can still change")
    func keepsRemindersOn() {
        for profile in UsageProfile.allCases {
            let settings = settings(for: profile)
            #expect(settings.posture.isEnabled)
            #expect(settings.hydration.isEnabled)
        }
    }
}
