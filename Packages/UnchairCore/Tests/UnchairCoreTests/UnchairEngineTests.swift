import Foundation
import Testing
@testable import UnchairCore

@Suite("UnchairEngine")
struct UnchairEngineTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    func makeEngine(_ settings: UnchairSettings = UnchairSettings()) -> UnchairEngine {
        UnchairEngine(settings: settings, calendar: calendar, now: start)
    }

    @Test("starts enabled reminders on init")
    func startsReminders() {
        let engine = makeEngine()

        #expect(engine.posture.nextDeadline == minutes(45))
        #expect(engine.hydration.nextReminderAt == minutes(60))
        #expect(engine.nextDeadline == minutes(45))
    }

    @Test("disabled reminders don't start")
    func disabledReminders() {
        let settings = UnchairSettings(
            posture: PostureSettings(isEnabled: false),
            hydration: HydrationSettings(isEnabled: false)
        )

        let engine = makeEngine(settings)

        #expect(engine.nextDeadline == nil)
    }

    @Test("next deadline includes the running Pomodoro")
    func deadlineIncludesPomodoro() {
        var engine = makeEngine()

        _ = engine.startPomodoro(now: start)

        #expect(engine.nextDeadline == minutes(25))
    }

    @Test("posture switch waits for the end of the focus session")
    func postureWaitsForBreak() {
        var engine = makeEngine()
        // Focus from minute 30 to 55; sitting time ends at minute 45.
        _ = engine.startPomodoro(now: minutes(30))

        let atSittingEnd = engine.tick(now: minutes(45))
        #expect(!atSittingEnd.contains(.posture(.switchSuggested(to: .standing))))
        #expect(engine.posture.state == .waitingForBreak)

        let atFocusEnd = engine.tick(now: minutes(55))
        #expect(atFocusEnd.contains(.pomodoro(.phaseCompleted(.focus, next: .shortBreak, autoStarted: true))))
        #expect(atFocusEnd.contains(.posture(.switchSuggested(to: .standing))))
    }

    @Test("pausing focus releases a held posture switch")
    func pauseReleasesPosture() {
        var engine = makeEngine()
        _ = engine.startPomodoro(now: minutes(30))
        _ = engine.tick(now: minutes(45))

        let events = engine.pausePomodoro(now: minutes(46))

        #expect(events == [.posture(.switchSuggested(to: .standing))])
    }

    @Test("reminders due at the same time are all returned")
    func simultaneousReminders() {
        let settings = UnchairSettings(
            posture: PostureSettings(sittingDuration: 60 * 60),
            hydration: HydrationSettings(reminderInterval: 60 * 60)
        )
        var engine = makeEngine(settings)

        let events = engine.tick(now: minutes(60))

        #expect(events == [
            .posture(.switchSuggested(to: .standing)),
            .hydration(.reminder(intake: 0, goal: 2000)),
        ])
    }

    @Test("disabling and enabling reminders through settings")
    func toggleRemindersViaSettings() {
        var engine = makeEngine()
        var settings = engine.settings

        settings.posture.isEnabled = false
        settings.hydration.isEnabled = false
        _ = engine.apply(settings, now: minutes(10))
        #expect(engine.nextDeadline == nil)

        settings.posture.isEnabled = true
        _ = engine.apply(settings, now: minutes(20))
        #expect(engine.posture.nextDeadline == minutes(65))
        #expect(engine.hydration.nextReminderAt == nil)
    }

    @Test("changing the current posture duration restarts its countdown")
    func changingDurationRestarts() {
        var engine = makeEngine()
        var settings = engine.settings

        settings.posture.sittingDuration = 30 * 60
        _ = engine.apply(settings, now: minutes(10))

        #expect(engine.posture.nextDeadline == minutes(40))
    }

    @Test("changing the hydration interval reschedules the reminder")
    func changingIntervalReschedules() {
        var engine = makeEngine()
        var settings = engine.settings

        settings.hydration.reminderInterval = 30 * 60
        _ = engine.apply(settings, now: minutes(10))

        #expect(engine.hydration.nextReminderAt == minutes(40))
    }

    @Test("unrelated setting changes keep existing schedules")
    func unrelatedChangesKeepSchedules() {
        var engine = makeEngine()
        var settings = engine.settings

        settings.hydration.dailyGoal = 3000
        settings.pomodoro.focusDuration = 50 * 60
        _ = engine.apply(settings, now: minutes(10))

        #expect(engine.posture.nextDeadline == minutes(45))
        #expect(engine.hydration.nextReminderAt == minutes(60))
        #expect(engine.pomodoro.settings.focusDuration == 50 * 60)
    }
}
