import Foundation
import Testing
@testable import UnchairCore

@Suite("PostureReminder")
struct PostureReminderTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let settings = PostureSettings(sittingDuration: 45 * 60, standingDuration: 15 * 60)

    func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    func started() -> PostureReminder {
        var reminder = PostureReminder(settings: settings)
        reminder.start(now: start)
        return reminder
    }

    @Test("starts sitting and counts down the sitting duration")
    func startsSitting() {
        let reminder = started()

        #expect(reminder.posture == .sitting)
        #expect(reminder.nextDeadline == minutes(45))
    }

    @Test("suggests standing when sitting time is up")
    func suggestsStanding() {
        var reminder = started()

        let early = reminder.tick(now: minutes(44), isFocusing: false)
        let due = reminder.tick(now: minutes(45), isFocusing: false)

        #expect(early == nil)
        #expect(due == .switchSuggested(to: .standing))
        #expect(reminder.state == .suggested)
        #expect(reminder.nextDeadline == nil)
    }

    @Test("confirming switches posture and counts down the new duration")
    func confirmSwitch() {
        var reminder = started()
        _ = reminder.tick(now: minutes(45), isFocusing: false)

        reminder.confirmSwitch(now: minutes(46))

        #expect(reminder.posture == .standing)
        #expect(reminder.nextDeadline == minutes(61))

        let event = reminder.tick(now: minutes(61), isFocusing: false)
        #expect(event == .switchSuggested(to: .sitting))
    }

    @Test("holds the suggestion during focus until the break")
    func holdsDuringFocus() {
        var reminder = started()

        let duringFocus = reminder.tick(now: minutes(45), isFocusing: true)
        #expect(duringFocus == nil)
        #expect(reminder.state == .waitingForBreak)

        let stillFocusing = reminder.tick(now: minutes(50), isFocusing: true)
        #expect(stillFocusing == nil)

        let atBreak = reminder.tick(now: minutes(55), isFocusing: false)
        #expect(atBreak == .switchSuggested(to: .standing))
    }

    @Test("doesn't hold during focus when sync is off")
    func noHoldWhenSyncOff() {
        var reminder = started()
        reminder.settings.syncWithPomodoro = false

        let event = reminder.tick(now: minutes(45), isFocusing: true)

        #expect(event == .switchSuggested(to: .standing))
    }

    @Test("snooze postpones the suggestion without switching")
    func snooze() {
        var reminder = started()
        _ = reminder.tick(now: minutes(45), isFocusing: false)

        reminder.snooze(by: 10 * 60, now: minutes(45))

        #expect(reminder.posture == .sitting)
        #expect(reminder.nextDeadline == minutes(55))
    }

    @Test("a stopped reminder ignores actions")
    func stopped() {
        var reminder = started()
        reminder.stop()

        reminder.confirmSwitch(now: minutes(1))
        reminder.snooze(by: 60, now: minutes(1))
        let event = reminder.tick(now: minutes(100), isFocusing: false)

        #expect(reminder.state == .stopped)
        #expect(reminder.posture == .sitting)
        #expect(event == nil)
    }
}
