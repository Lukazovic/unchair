import Foundation
import Testing
@testable import UnchairCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

/// Monday 2026-01-05 10:00 UTC.
private let monday10am = Date(timeIntervalSince1970: 1_767_607_200)

private func at(_ minutes: Double, from start: Date = monday10am) -> Date {
    start.addingTimeInterval(minutes * 60)
}

@Suite("WorkingHours")
struct WorkingHoursTests {
    let hours = WorkingHours(isEnabled: true, weekdays: [2, 3, 4, 5, 6], start: 9 * 60, end: 18 * 60)

    @Test("disabled working hours always allow reminders")
    func disabledAlwaysContains() {
        let disabled = WorkingHours(isEnabled: false)

        #expect(disabled.contains(at(-10 * 60), calendar: utc))
        #expect(disabled.nextTransition(after: monday10am, calendar: utc) == nil)
    }

    @Test("contains weekday hours, excluding the end minute")
    func containsHours() {
        #expect(hours.contains(monday10am, calendar: utc))
        #expect(hours.contains(at(-60), calendar: utc)) // 09:00
        #expect(!hours.contains(at(-61), calendar: utc)) // 08:59
        #expect(!hours.contains(at(8 * 60), calendar: utc)) // 18:00
    }

    @Test("weekends are excluded")
    func weekendsExcluded() {
        let saturday = at(5 * 24 * 60)

        #expect(!hours.contains(saturday, calendar: utc))
    }

    @Test("next transition is today's end during working hours")
    func transitionToEnd() {
        #expect(hours.nextTransition(after: monday10am, calendar: utc) == at(8 * 60))
    }

    @Test("next transition skips the weekend")
    func transitionSkipsWeekend() {
        let fridayEvening = at(4 * 24 * 60 + 9 * 60) // Friday 19:00
        let nextMonday9am = at(7 * 24 * 60 - 60)

        #expect(hours.nextTransition(after: fridayEvening, calendar: utc) == nextMonday9am)
    }
}

@Suite("UnchairEngine interruptions")
struct EngineInterruptionTests {
    func makeEngine(
        _ settings: UnchairSettings = UnchairSettings(),
        quietUntil: Date? = nil,
        now: Date = monday10am
    ) -> UnchairEngine {
        UnchairEngine(settings: settings, quietUntil: quietUntil, calendar: utc, now: now)
    }

    // MARK: Coalescing

    @Test("a reminder due within the window is delivered with the one that fired")
    func coalescesNearbyReminders() {
        // Posture at 45 min, hydration at 48 min, window 5 min.
        let settings = UnchairSettings(hydration: HydrationSettings(reminderInterval: 48 * 60))
        var engine = makeEngine(settings)

        let events = engine.tick(now: at(45))

        #expect(events == [
            .posture(.switchSuggested(to: .standing)),
            .hydration(.reminder(intake: 0, goal: 2000)),
        ])
        #expect(engine.hydration.nextReminderAt == at(45 + 48))
    }

    @Test("a reminder outside the window waits for its own time")
    func doesNotCoalesceDistantReminders() {
        var engine = makeEngine() // posture 45, hydration 60

        let events = engine.tick(now: at(45))

        #expect(events == [.posture(.switchSuggested(to: .standing))])
        #expect(engine.hydration.nextReminderAt == at(60))
    }

    // MARK: Quiet mode

    @Test("quiet mode holds reminders and delivers them when it ends")
    func quietModeHoldsReminders() {
        var engine = makeEngine()
        _ = engine.pauseReminders(until: at(70), now: at(40))

        #expect(engine.holdReason(at: at(50)) == .quietMode(until: at(70)))
        #expect(engine.tick(now: at(50)).isEmpty)
        #expect(engine.nextDeadline(after: at(50)) == at(70))

        let events = engine.tick(now: at(70))
        #expect(events == [
            .posture(.switchSuggested(to: .standing)),
            .hydration(.reminder(intake: 0, goal: 2000)),
        ])
        #expect(engine.quietUntil == nil)
    }

    @Test("resuming quiet mode early delivers overdue reminders")
    func resumeQuietMode() {
        var engine = makeEngine()
        _ = engine.pauseReminders(until: at(120), now: at(0))

        let events = engine.pauseReminders(until: nil, now: at(50))

        #expect(events == [.posture(.switchSuggested(to: .standing))])
    }

    @Test("an expired quiet date from storage is ignored")
    func expiredQuietIgnored() {
        let engine = makeEngine(quietUntil: at(-5))

        #expect(engine.quietUntil == nil)
        #expect(engine.holdReason(at: monday10am) == nil)
    }

    @Test("the Pomodoro keeps running in quiet mode")
    func pomodoroIgnoresQuietMode() {
        var engine = makeEngine()
        _ = engine.pauseReminders(until: at(120), now: monday10am)
        _ = engine.startPomodoro(now: monday10am)

        let events = engine.tick(now: at(25))

        #expect(events == [.pomodoro(.phaseCompleted(.focus, next: .shortBreak, autoStarted: true))])
    }

    // MARK: Context

    @Test("meetings hold reminders until they end")
    func meetingHoldsReminders() {
        var engine = makeEngine()
        _ = engine.update(ReminderContext(isInMeeting: true), now: at(30))

        #expect(engine.tick(now: at(45)).isEmpty)
        #expect(engine.holdReason(at: at(45)) == .meeting)
        #expect(engine.nextDeadline(after: at(45)) == nil)

        let events = engine.update(ReminderContext(isInMeeting: false), now: at(56))
        #expect(events == [
            .posture(.switchSuggested(to: .standing)),
            .hydration(.reminder(intake: 0, goal: 2000)),
        ])
    }

    @Test("context holds respect their settings")
    func contextHoldsRespectSettings() {
        var settings = UnchairSettings()
        settings.interruptions.holdDuringMeetings = false
        settings.interruptions.holdDuringFullscreen = false
        var engine = makeEngine(settings)

        _ = engine.update(ReminderContext(isInMeeting: true, isFullscreen: true), now: monday10am)
        #expect(engine.holdReason(at: monday10am) == nil)

        _ = engine.update(ReminderContext(focusFilterHoldsReminders: true), now: monday10am)
        #expect(engine.holdReason(at: monday10am) == .focusMode)
    }

    @Test("full screen holds reminders by default")
    func fullscreenHolds() {
        var engine = makeEngine()

        _ = engine.update(ReminderContext(isFullscreen: true), now: monday10am)

        #expect(engine.holdReason(at: monday10am) == .fullscreen)
    }

    // MARK: Working hours

    @Test("reminders are held outside working hours and start fresh when the day begins")
    func workingHours() {
        var settings = UnchairSettings()
        settings.interruptions.workingHours = WorkingHours(isEnabled: true, start: 9 * 60, end: 18 * 60)
        let evening = at(9 * 60) // Monday 19:00
        var engine = makeEngine(settings, now: evening)

        #expect(engine.holdReason(at: evening) == .outsideWorkingHours)
        let nextMorning = at(23 * 60) // Tuesday 09:00
        #expect(engine.nextDeadline(after: evening) == nextMorning)

        let events = engine.tick(now: nextMorning)
        #expect(events.isEmpty)
        #expect(engine.posture.nextDeadline == at(45, from: nextMorning))
        #expect(engine.hydration.nextReminderAt == at(60, from: nextMorning))
    }

    // MARK: Away

    @Test("going away pauses focus at the moment the user left")
    func awayPausesFocus() {
        var engine = makeEngine()
        _ = engine.startPomodoro(now: monday10am)

        _ = engine.userBecameAway(since: at(10), now: at(15))

        #expect(engine.pomodoro.state == .paused(.focus, remaining: 15 * 60, duration: 25 * 60))
        #expect(engine.holdReason(at: at(15)) == .away)
    }

    @Test("a short absence resumes the paused focus")
    func shortAbsenceResumes() {
        var engine = makeEngine()
        _ = engine.startPomodoro(now: monday10am)
        _ = engine.userBecameAway(since: at(10), now: at(12))

        _ = engine.userReturned(now: at(13))

        #expect(engine.pomodoro.phase == .focus)
        #expect(engine.pomodoro.nextDeadline == at(28))
    }

    @Test("an absence longer than a short break discards the focus session")
    func longAbsenceDiscardsFocus() {
        var engine = makeEngine()
        _ = engine.startPomodoro(now: monday10am)
        _ = engine.userBecameAway(since: at(10), now: at(15))

        _ = engine.userReturned(now: at(40))

        #expect(engine.pomodoro.state == .awaiting(.focus))
        #expect(engine.pomodoro.completedFocusSessions == 0)
    }

    @Test("focus isn't paused when the setting is off")
    func awayPauseSettingOff() {
        var settings = UnchairSettings()
        settings.interruptions.pauseFocusWhenAway = false
        var engine = makeEngine(settings)
        _ = engine.startPomodoro(now: monday10am)

        _ = engine.userBecameAway(since: at(10), now: at(15))

        #expect(engine.pomodoro.isRunning)
    }

    @Test("an absence counts as a natural posture break")
    func absenceResetsPosture() {
        var engine = makeEngine()
        _ = engine.confirmPostureSwitch(now: at(5)) // standing until 20
        _ = engine.userBecameAway(since: at(10), now: at(15))

        _ = engine.userReturned(now: at(30))

        #expect(engine.posture.posture == .sitting)
        #expect(engine.posture.nextDeadline == at(75))
    }

    @Test("a very short absence keeps the posture countdown")
    func briefAbsenceKeepsPosture() {
        var engine = makeEngine()
        _ = engine.userBecameAway(since: at(10), now: at(10))

        _ = engine.userReturned(now: at(11))

        #expect(engine.posture.nextDeadline == at(45))
    }

    @Test("the water interval restarts after an absence longer than it")
    func longAbsenceRestartsHydration() {
        var engine = makeEngine()
        _ = engine.userBecameAway(since: at(10), now: at(15))

        let events = engine.userReturned(now: at(90))

        #expect(events.isEmpty)
        #expect(engine.hydration.nextReminderAt == at(150))
    }

    @Test("a focus session that auto-starts while away is paused")
    func autoStartedFocusPausedWhileAway() {
        var settings = UnchairSettings()
        settings.pomodoro.autoStartFocus = true
        var engine = makeEngine(settings)
        _ = engine.startPomodoro(now: monday10am)
        _ = engine.tick(now: at(25)) // break until 30
        _ = engine.userBecameAway(since: at(27), now: at(28))

        _ = engine.tick(now: at(30))

        #expect(engine.pomodoro.state == .paused(.focus, remaining: 25 * 60, duration: 25 * 60))
    }

    @Test("a manual pause isn't resumed on return")
    func manualPauseKept() {
        var engine = makeEngine()
        _ = engine.startPomodoro(now: monday10am)
        _ = engine.pausePomodoro(now: at(5))
        _ = engine.userBecameAway(since: at(10), now: at(15))

        _ = engine.userReturned(now: at(16))

        #expect(engine.pomodoro.state == .paused(.focus, remaining: 20 * 60, duration: 25 * 60))
    }
}

@Suite("Settings decoding")
struct SettingsDecodingTests {
    @Test("settings saved before interruptions existed still decode")
    func decodesOlderSettings() throws {
        var old = UnchairSettings()
        old.pomodoro.focusDuration = 50 * 60
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any]
        )
        json.removeValue(forKey: "interruptions")
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(UnchairSettings.self, from: data)

        #expect(decoded.pomodoro.focusDuration == 50 * 60)
        #expect(decoded.interruptions == InterruptionSettings())
    }
}
