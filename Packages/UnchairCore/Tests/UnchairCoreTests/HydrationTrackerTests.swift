import Foundation
import Testing
@testable import UnchairCore

@Suite("HydrationTracker")
struct HydrationTrackerTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// 2026-01-01 09:00 UTC
    let start = Date(timeIntervalSince1970: 1_767_258_000)
    let settings = HydrationSettings(reminderInterval: 60 * 60, dailyGoal: 2000, glassSize: 250)

    func minutes(_ value: Double) -> Date {
        start.addingTimeInterval(value * 60)
    }

    func started() -> HydrationTracker {
        var tracker = HydrationTracker(settings: settings, calendar: calendar, now: start)
        tracker.start(now: start)
        return tracker
    }

    @Test("reminds after the interval and schedules the next reminder")
    func remindsAfterInterval() {
        var tracker = started()

        let early = tracker.tick(now: minutes(59))
        let due = tracker.tick(now: minutes(60))

        #expect(early == nil)
        #expect(due == .reminder(intake: 0, goal: 2000))
        #expect(tracker.nextReminderAt == minutes(120))
    }

    @Test("logging a glass adds intake and restarts the interval")
    func logGlass() {
        var tracker = started()

        tracker.logGlass(now: minutes(30))

        #expect(tracker.intake(at: minutes(30)) == 250)
        #expect(tracker.progress(at: minutes(30)) == 0.125)
        #expect(tracker.nextReminderAt == minutes(90))
    }

    @Test("logging while stopped doesn't schedule reminders")
    func logWhileStopped() {
        var tracker = HydrationTracker(settings: settings, calendar: calendar, now: start)

        tracker.logGlass(now: start)

        #expect(tracker.intake(at: start) == 250)
        #expect(tracker.nextReminderAt == nil)
    }

    @Test("removing a glass never goes below zero")
    func removeGlass() {
        var tracker = started()
        tracker.logGlass(now: start)

        tracker.removeGlass(now: start)
        tracker.removeGlass(now: start)

        #expect(tracker.intake(at: start) == 0)
    }

    @Test("progress is capped at the goal")
    func progressCapped() {
        var tracker = started()
        for _ in 0 ..< 10 {
            tracker.logGlass(now: start)
        }

        #expect(tracker.intake(at: start) == 2500)
        #expect(tracker.progress(at: start) == 1)
    }

    @Test("intake resets on a new day")
    func dayRollover() {
        var tracker = started()
        tracker.logGlass(now: start)
        let nextDay = start.addingTimeInterval(24 * 60 * 60)

        #expect(tracker.intake(at: nextDay) == 0)

        tracker.logGlass(now: nextDay)
        #expect(tracker.intake(at: nextDay) == 250)
        #expect(tracker.log.day == calendar.startOfDay(for: nextDay))
    }

    @Test("a log from a previous day is discarded on init")
    func staleLogDiscarded() {
        let yesterday = HydrationLog(day: calendar.startOfDay(for: start.addingTimeInterval(-86400)), intake: 1500)

        let tracker = HydrationTracker(settings: settings, log: yesterday, calendar: calendar, now: start)

        #expect(tracker.log.intake == 0)
    }

    @Test("a log from today is kept on init")
    func todayLogKept() {
        let today = HydrationLog(day: calendar.startOfDay(for: start), intake: 750)

        let tracker = HydrationTracker(settings: settings, log: today, calendar: calendar, now: start)

        #expect(tracker.intake(at: start) == 750)
    }

    @Test("snooze postpones the next reminder")
    func snooze() {
        var tracker = started()
        _ = tracker.tick(now: minutes(60))

        tracker.snooze(by: 15 * 60, now: minutes(60))

        #expect(tracker.nextReminderAt == minutes(75))
    }

    @Test("a stopped tracker doesn't remind")
    func stopped() {
        var tracker = started()
        tracker.stop()

        tracker.snooze(by: 60, now: start)
        let event = tracker.tick(now: minutes(600))

        #expect(event == nil)
        #expect(tracker.nextReminderAt == nil)
    }
}
