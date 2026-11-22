import Foundation
import Testing
@testable import UnchairCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

/// Monday 2026-01-05 00:00 UTC.
private let mondayMidnight = Date(timeIntervalSince1970: 1_767_571_200)

private func hours(_ value: Double) -> Date {
    mondayMidnight.addingTimeInterval(value * 3600)
}

@Suite("Statistics")
struct StatsTests {
    let monday = DateInterval(start: mondayMidnight, duration: 86400)

    @Test("focus sessions and water count on the day they were recorded")
    func focusAndWater() {
        let history = History(
            focusSessions: [
                FocusSession(end: hours(10), duration: 1500),
                FocusSession(end: hours(11), duration: 1500),
                FocusSession(end: hours(25), duration: 1500), // Tuesday
            ],
            waterEntries: [
                WaterEntry(date: hours(9), amount: 250),
                WaterEntry(date: hours(12), amount: 500),
                WaterEntry(date: hours(13), amount: -250),
            ]
        )

        let stats = history.stats(for: monday, now: hours(30))

        #expect(stats.focusSessions == 2)
        #expect(stats.focusTime == 3000)
        #expect(stats.water == 500)
    }

    @Test("presence time is split by state and clipped to the day")
    func presenceTime() {
        let history = History(presenceChanges: [
            PresenceChange(date: hours(-1), state: .sitting), // Sunday 23:00
            PresenceChange(date: hours(1), state: .standing),
            PresenceChange(date: hours(1.5), state: .away),
            PresenceChange(date: hours(9), state: .sitting),
            PresenceChange(date: hours(10), state: .standing),
            PresenceChange(date: hours(10.25), state: .sitting),
        ])

        let stats = history.stats(for: monday, now: hours(11))

        #expect(stats.standingTime == 0.75 * 3600)
        #expect(stats.sittingTime == TimeInterval(2.75 * 3600))
    }

    @Test("a state without a following record is cut off")
    func openStateCapped() {
        let history = History(presenceChanges: [PresenceChange(date: hours(9), state: .standing)])

        let stats = history.stats(for: monday, now: hours(20))

        #expect(stats.standingTime == History.maxPresenceSpan)
    }

    @Test("daily stats cover each day, oldest first")
    func dailyStats() {
        let history = History(focusSessions: [FocusSession(end: hours(-12), duration: 600)])

        let days = history.dailyStats(days: 3, endingAt: hours(12), calendar: utc)

        #expect(days.map(\.day) == [hours(-48), hours(-24), hours(0)])
        #expect(days.map(\.focusSessions) == [0, 1, 0])
    }

    @Test("streaks count consecutive days and forgive an unfinished today")
    func streaks() {
        func day(_ water: Int) -> DayStats {
            DayStats(day: mondayMidnight, water: water)
        }
        let metGoal = { (stats: DayStats) in stats.water >= 2000 }

        #expect([day(2000), day(0), day(2000), day(2500), day(500)].streak(where: metGoal) == 2)
        #expect([day(2000), day(2000), day(2000)].streak(where: metGoal) == 3)
        #expect([day(0), day(0)].streak(where: metGoal) == 0)
    }

    @Test("CSV lists every record in date order")
    func csv() {
        let history = History(
            focusSessions: [FocusSession(end: hours(10), duration: 1500)],
            presenceChanges: [PresenceChange(date: hours(9), state: .standing)],
            waterEntries: [WaterEntry(date: hours(11), amount: 250)],
            reminderResponses: [ReminderResponse(date: hours(12), kind: .eyes, outcome: .snoozed)]
        )

        let lines = history.csv().split(separator: "\n")

        #expect(lines == [
            "type,date,value,detail",
            "presence,2026-01-05T09:00:00Z,,standing",
            "focus,2026-01-05T10:00:00Z,1500,",
            "water,2026-01-05T11:00:00Z,250,",
            "reminder,2026-01-05T12:00:00Z,,eyes:snoozed",
        ])
    }

    @Test("JSON export round-trips")
    func jsonRoundTrip() throws {
        let history = History(waterEntries: [WaterEntry(date: hours(11), amount: 250)])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(History.self, from: history.jsonData())

        #expect(decoded == history)
    }

    @Test("widget snapshot reflects the engine")
    func widgetSnapshot() {
        var engine = UnchairEngine(calendar: utc, now: hours(10))
        _ = engine.startPomodoro(now: hours(10))
        _ = engine.logWater(now: hours(10))

        let snapshot = WidgetSnapshot(
            engine: engine,
            today: DayStats(day: mondayMidnight, focusSessions: 3),
            now: hours(10)
        )

        #expect(snapshot.timer == .running(.focus, endsAt: hours(10).addingTimeInterval(1500)))
        #expect(snapshot.posture == .sitting)
        #expect(snapshot.waterToday == 250)
        #expect(snapshot.focusSessionsToday == 3)
    }
}
