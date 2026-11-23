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

/// Settings with only the reminders a test turns on.
private func quietSettings() -> UnchairSettings {
    var settings = UnchairSettings()
    settings.posture.isEnabled = false
    settings.hydration.isEnabled = false
    settings.summary.isEnabled = false
    return settings
}

@Suite("IntervalReminder")
struct IntervalReminderTests {
    @Test("fires at the interval and reschedules")
    func firesAndReschedules() {
        var reminder = IntervalReminder(interval: 20 * 60)
        reminder.start(now: monday10am)

        let result1 = reminder.tick(now: at(19))

        #expect(!result1)
        let result2 = reminder.tick(now: at(20))
        #expect(result2)
        #expect(reminder.nextReminderAt == at(40))
    }

    @Test("acknowledging restarts the interval; stopped reminders ignore actions")
    func acknowledgeAndStop() {
        var reminder = IntervalReminder(interval: 20 * 60)
        reminder.start(now: monday10am)

        reminder.acknowledge(now: at(15))
        #expect(reminder.nextReminderAt == at(35))

        reminder.stop()
        reminder.acknowledge(now: at(16))
        reminder.snooze(by: 60, now: at(16))
        #expect(reminder.nextReminderAt == nil)
        let result3 = reminder.tick(now: at(100))
        #expect(!result3)
    }
}

@Suite("Eye breaks and posture checks")
struct EyeBreakTests {
    @Test("snoozing a posture check brings it back after the snooze")
    func snoozePostureCheck() {
        var settings = quietSettings()
        settings.postureCheck.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        _ = engine.snoozePostureCheck(by: 10 * 60, now: at(1))

        #expect(engine.postureCheck.nextReminderAt == at(11))
    }

    @Test("eye breaks are off by default")
    func offByDefault() {
        let engine = UnchairEngine(calendar: utc, now: monday10am)

        #expect(!engine.eyes.isRunning)
        #expect(!engine.postureCheck.isRunning)
    }

    @Test("eye breaks fire every 20 minutes when enabled")
    func eyeBreaksFire() {
        var settings = quietSettings()
        settings.eyes.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        let result4 = engine.tick(now: at(20))

        #expect(result4 == [.eyeBreak])
        #expect(engine.eyes.nextReminderAt == at(40))
    }

    @Test("merged eye breaks are skipped while a Pomodoro session is active")
    func mergedWithPomodoro() {
        var settings = quietSettings()
        settings.eyes.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)
        _ = engine.startPomodoro(now: monday10am)

        #expect(engine.nextDeadline(after: monday10am) == at(25))
        let result5 = engine.tick(now: at(20))
        #expect(!result5.contains(.eyeBreak))

        _ = engine.resetPomodoro(now: at(30))
        #expect(engine.eyes.nextReminderAt == at(50))
    }

    @Test("eye breaks fire during a Pomodoro when not merged")
    func notMerged() {
        var settings = quietSettings()
        settings.eyes.isEnabled = true
        settings.eyes.mergeWithPomodoro = false
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)
        _ = engine.startPomodoro(now: monday10am)

        let result6 = engine.tick(now: at(20))

        #expect(result6 == [.eyeBreak])
    }

    @Test("a posture switch absorbs a posture check due at the same time")
    func postureSwitchAbsorbsCheck() {
        var settings = quietSettings()
        settings.posture.isEnabled = true
        settings.posture.sittingDuration = 120 * 60
        settings.postureCheck.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        let events = engine.tick(now: at(120))

        #expect(events == [.posture(.switchSuggested(to: .standing))])
        #expect(engine.postureCheck.nextReminderAt == at(240))
    }

    @Test("eye breaks coalesce with other reminders")
    func eyesCoalesce() {
        var settings = quietSettings()
        settings.hydration.isEnabled = true
        settings.hydration.reminderInterval = 18 * 60
        settings.eyes.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        let events = engine.tick(now: at(18))

        #expect(events == [.hydration(.reminder(intake: 0, goal: 2000)), .eyeBreak])
    }

    @Test("enabling through settings starts the interval")
    func enableViaSettings() {
        var engine = UnchairEngine(settings: quietSettings(), calendar: utc, now: monday10am)
        var settings = engine.settings
        settings.postureCheck.isEnabled = true
        settings.postureCheck.interval = 90 * 60

        _ = engine.apply(settings, now: at(10))

        #expect(engine.postureCheck.nextReminderAt == at(100))
    }
}

@Suite("Daily summary")
struct DailySummaryTests {
    @Test("fires at the configured time every day")
    func firesAtTime() {
        var settings = quietSettings()
        settings.summary = DailySummarySettings(isEnabled: true, time: 18 * 60)
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        #expect(engine.nextSummaryAt == at(8 * 60))
        let result7 = engine.tick(now: at(8 * 60))
        #expect(result7 == [.dayEnded])
        #expect(engine.nextSummaryAt == at(32 * 60))
    }

    @Test("uses the end of working hours on working days")
    func usesWorkingHours() {
        var settings = quietSettings()
        settings.summary.isEnabled = true
        settings.interruptions.workingHours = WorkingHours(isEnabled: true, weekdays: [2, 3, 4, 5, 6], end: 17 * 60)
        let friday = at(4 * 24 * 60)
        var engine = UnchairEngine(settings: settings, calendar: utc, now: friday)

        #expect(engine.nextSummaryAt == at(7 * 60, from: friday))

        _ = engine.tick(now: at(7 * 60, from: friday))
        let nextMonday5pm = at(7 * 60, from: at(7 * 24 * 60))
        #expect(engine.nextSummaryAt == nextMonday5pm)
    }

    @Test("a summary missed by hours is skipped")
    func lateSummarySkipped() {
        var settings = quietSettings()
        settings.summary.isEnabled = true
        var engine = UnchairEngine(settings: settings, calendar: utc, now: monday10am)

        let events = engine.tick(now: at(12 * 60)) // 22:00, four hours late

        #expect(!events.contains(.dayEnded))
        #expect(engine.nextSummaryAt == at(32 * 60))
    }

    @Test("disabled summaries are never scheduled")
    func disabled() {
        let engine = UnchairEngine(settings: quietSettings(), calendar: utc, now: monday10am)

        #expect(engine.nextSummaryAt == nil)
    }
}

@Suite("Stretch")
struct StretchTests {
    @Test("suggestions rotate through every stretch")
    func rotates() {
        let suggestions = (0 ..< Stretch.allCases.count).map(Stretch.suggestion(forBreak:))

        #expect(Set(suggestions).count == Stretch.allCases.count)
        #expect(Stretch.suggestion(forBreak: Stretch.allCases.count) == Stretch.suggestion(forBreak: 0))
        #expect(Stretch.suggestion(forBreak: -1) == Stretch.allCases.last)
    }
}
