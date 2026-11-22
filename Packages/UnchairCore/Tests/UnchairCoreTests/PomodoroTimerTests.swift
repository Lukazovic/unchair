import Foundation
import Testing
@testable import UnchairCore

@Suite("PomodoroTimer")
struct PomodoroTimerTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let settings = PomodoroSettings(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        sessionsBeforeLongBreak: 4,
        autoStartBreaks: true,
        autoStartFocus: false
    )

    func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    @Test("starts idle with no deadline")
    func startsIdle() {
        let timer = PomodoroTimer(settings: settings)

        #expect(timer.state == .idle)
        #expect(timer.nextDeadline == nil)
        #expect(timer.remaining(at: start) == nil)
    }

    @Test("start begins a focus session")
    func startBeginsFocus() {
        var timer = PomodoroTimer(settings: settings)

        timer.start(now: start)

        #expect(timer.phase == .focus)
        #expect(timer.nextDeadline == minutes(25))
        #expect(timer.remaining(at: minutes(10)) == TimeInterval(15 * 60))
        #expect(timer.progress(at: minutes(10)) == 0.4)
    }

    @Test("tick before the deadline does nothing")
    func tickBeforeDeadline() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)

        let result1 = timer.tick(now: minutes(24))

        #expect(result1 == nil)
        #expect(timer.phase == .focus)
    }

    @Test("completing focus auto-starts a short break")
    func focusCompletesIntoShortBreak() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)

        let event = timer.tick(now: minutes(25))

        #expect(event == .phaseCompleted(.focus, next: .shortBreak, autoStarted: true))
        #expect(timer.phase == .shortBreak)
        #expect(timer.nextDeadline == minutes(30))
        #expect(timer.completedFocusSessions == 1)
    }

    @Test("without auto-start the next phase waits to be started")
    func awaitsWithoutAutoStart() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)
        _ = timer.tick(now: minutes(25))

        let event = timer.tick(now: minutes(30))

        #expect(event == .phaseCompleted(.shortBreak, next: .focus, autoStarted: false))
        #expect(timer.state == .awaiting(.focus))
        #expect(timer.nextDeadline == nil)

        timer.start(now: minutes(32))
        #expect(timer.phase == .focus)
        #expect(timer.nextDeadline == minutes(57))
    }

    @Test("a long break follows every N focus sessions")
    func longBreakAfterCycle() {
        var timer = PomodoroTimer(settings: settings)
        var now = start
        var breaks: [PomodoroPhase] = []

        for _ in 0 ..< 5 {
            timer.start(now: now)
            now = timer.nextDeadline ?? now
            if case let .phaseCompleted(_, next, _) = timer.tick(now: now) {
                breaks.append(next)
            }
            now = timer.nextDeadline ?? now
            _ = timer.tick(now: now)
        }

        #expect(breaks == [.shortBreak, .shortBreak, .shortBreak, .longBreak, .shortBreak])
        #expect(timer.completedFocusSessions == 5)
    }

    @Test("cycle position shows a full cycle during the long break")
    func cyclePosition() {
        var timer = PomodoroTimer(settings: PomodoroSettings(sessionsBeforeLongBreak: 2, autoStartFocus: true))
        timer.start(now: start)
        #expect(timer.sessionsInCurrentCycle == 0)

        _ = timer.tick(now: minutes(25)) // focus 1 done → short break
        #expect(timer.sessionsInCurrentCycle == 1)
        _ = timer.tick(now: minutes(30)) // break done → focus
        _ = timer.tick(now: minutes(55)) // focus 2 done → long break
        #expect(timer.phase == .longBreak)
        #expect(timer.sessionsInCurrentCycle == 2)
        _ = timer.tick(now: minutes(70)) // long break done → focus
        #expect(timer.sessionsInCurrentCycle == 0)
    }

    @Test("pause and resume keep the remaining time")
    func pauseResume() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)

        timer.pause(now: minutes(10))
        #expect(timer.state == .paused(.focus, remaining: 15 * 60, duration: 25 * 60))
        #expect(timer.nextDeadline == nil)
        #expect(timer.remaining(at: minutes(100)) == TimeInterval(15 * 60))
        let result2 = timer.tick(now: minutes(100))
        #expect(result2 == nil)

        timer.resume(now: minutes(20))
        #expect(timer.nextDeadline == minutes(35))
    }

    @Test("skipping focus starts a short break without counting the session")
    func skipFocus() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)

        let next = timer.skip(now: minutes(5))

        #expect(next == .shortBreak)
        #expect(timer.phase == .shortBreak)
        #expect(timer.nextDeadline == minutes(10))
        #expect(timer.completedFocusSessions == 0)
    }

    @Test("skipping a break starts focus, including a pending break")
    func skipBreak() {
        var timer = PomodoroTimer(settings: PomodoroSettings(autoStartBreaks: false))
        timer.start(now: start)
        _ = timer.tick(now: minutes(25))
        #expect(timer.state == .awaiting(.shortBreak))

        let result3 = timer.skip(now: minutes(26))

        #expect(result3 == .focus)
        #expect(timer.phase == .focus)
        #expect(timer.nextDeadline == minutes(51))
    }

    @Test("nothing to skip when idle or when focus is pending")
    func skipNoOp() {
        var timer = PomodoroTimer(settings: settings)
        let result4 = timer.skip(now: start)
        #expect(result4 == nil)

        timer.start(now: start)
        _ = timer.tick(now: minutes(25))
        _ = timer.tick(now: minutes(30))
        #expect(timer.state == .awaiting(.focus))
        let result5 = timer.skip(now: minutes(31))
        #expect(result5 == nil)
        #expect(timer.state == .awaiting(.focus))
    }

    @Test("extending focus after it ends doesn't count an extra session")
    func extendFocus() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)
        _ = timer.tick(now: minutes(25)) // short break auto-started

        let result6 = timer.extendFocus(by: 5 * 60, now: minutes(26))

        #expect(result6)
        #expect(timer.phase == .focus)
        #expect(timer.nextDeadline == minutes(31))

        let event = timer.tick(now: minutes(31))
        #expect(event == .phaseCompleted(.focus, next: .shortBreak, autoStarted: true))
        #expect(timer.completedFocusSessions == 1)
    }

    @Test("focus can't be extended during focus or after a break")
    func extendFocusInvalid() {
        var timer = PomodoroTimer(settings: settings)
        let result7 = timer.extendFocus(by: 300, now: start)
        #expect(!result7)

        timer.start(now: start)
        let result8 = timer.extendFocus(by: 300, now: minutes(1))
        #expect(!result8)

        _ = timer.tick(now: minutes(25))
        _ = timer.tick(now: minutes(30)) // break completed, focus pending
        let result9 = timer.extendFocus(by: 300, now: minutes(31))
        #expect(!result9)
    }

    @Test("reset clears state and cycle")
    func reset() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)
        _ = timer.tick(now: minutes(25))

        timer.reset()

        #expect(timer.state == .idle)
        #expect(timer.completedFocusSessions == 0)
        #expect(timer.lastCompletedPhase == nil)
    }

    @Test("new durations apply from the next phase")
    func settingsApplyToNextPhase() {
        var timer = PomodoroTimer(settings: settings)
        timer.start(now: start)

        timer.settings.shortBreakDuration = 10 * 60

        #expect(timer.nextDeadline == minutes(25))
        _ = timer.tick(now: minutes(25))
        #expect(timer.nextDeadline == minutes(35))
    }
}

@Suite("PomodoroPreset")
struct PomodoroPresetTests {
    @Test("default settings match the classic preset")
    func defaultIsClassic() {
        #expect(PomodoroPreset.matching(PomodoroSettings()) == .classic)
    }

    @Test("applying a preset keeps other options")
    func applyKeepsOptions() {
        var settings = PomodoroSettings(sessionsBeforeLongBreak: 3, autoStartBreaks: false)

        PomodoroPreset.deepWork.apply(to: &settings)

        #expect(settings.focusDuration == 90 * 60)
        #expect(settings.sessionsBeforeLongBreak == 3)
        #expect(!settings.autoStartBreaks)
        #expect(PomodoroPreset.matching(settings) == .deepWork)
    }

    @Test("custom durations match no preset")
    func customMatchesNothing() {
        #expect(PomodoroPreset.matching(PomodoroSettings(focusDuration: 30 * 60)) == nil)
    }
}
