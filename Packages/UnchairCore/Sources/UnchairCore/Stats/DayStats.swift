import Foundation

/// Totals for one calendar day.
public struct DayStats: Equatable, Sendable, Identifiable {
    /// Start of the day.
    public var day: Date
    public var focusTime: TimeInterval
    public var focusSessions: Int
    public var standingTime: TimeInterval
    public var sittingTime: TimeInterval
    /// Milliliters.
    public var water: Int

    public var id: Date {
        day
    }

    /// Whether anything was recorded on this day.
    public var hasActivity: Bool {
        focusSessions > 0 || water > 0 || standingTime > 0 || sittingTime > 0
    }

    public init(
        day: Date,
        focusTime: TimeInterval = 0,
        focusSessions: Int = 0,
        standingTime: TimeInterval = 0,
        sittingTime: TimeInterval = 0,
        water: Int = 0
    ) {
        self.day = day
        self.focusTime = focusTime
        self.focusSessions = focusSessions
        self.standingTime = standingTime
        self.sittingTime = sittingTime
        self.water = water
    }
}

public extension History {
    /// A presence state that lasts longer than this without a new record is
    /// cut off, in case the app quit without recording that the user left.
    static let maxPresenceSpan: TimeInterval = 3 * 60 * 60

    /// Daily totals for the `count` days ending with the day containing `now`,
    /// oldest first.
    func dailyStats(days count: Int, endingAt now: Date, calendar: Calendar) -> [DayStats] {
        let today = calendar.startOfDay(for: now)
        return (0 ..< count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: day)
            else { return nil }
            return stats(for: DateInterval(start: day, end: next), now: now)
        }
    }

    /// Totals for `interval`. Focus sessions and water count on the day they
    /// were recorded; presence time is split exactly at the interval's edges.
    func stats(for interval: DateInterval, now: Date) -> DayStats {
        let sessions = focusSessions.filter { interval.contains($0.end) && $0.end < interval.end }
        let water = waterEntries
            .filter { interval.contains($0.date) && $0.date < interval.end }
            .reduce(0) { $0 + $1.amount }
        return DayStats(
            day: interval.start,
            focusTime: sessions.reduce(0) { $0 + $1.duration },
            focusSessions: sessions.count,
            standingTime: time(in: .standing, during: interval, now: now),
            sittingTime: time(in: .sitting, during: interval, now: now),
            water: max(0, water)
        )
    }

    /// How long the user was in `state` during `interval`, never counting past `now`.
    func time(in state: PresenceState, during interval: DateInterval, now: Date) -> TimeInterval {
        let changes = presenceChanges.sorted { $0.date < $1.date }
        var total: TimeInterval = 0
        for (index, change) in changes.enumerated() where change.state == state {
            let nextDate = index + 1 < changes.count ? changes[index + 1].date : now
            let end = min(nextDate, now, change.date.addingTimeInterval(Self.maxPresenceSpan))
            let start = max(change.date, interval.start)
            let clippedEnd = min(end, interval.end)
            if clippedEnd > start {
                total += clippedEnd.timeIntervalSince(start)
            }
        }
        return total
    }
}

public extension [DayStats] {
    /// The average of `value` over finished days with activity, or `nil` if
    /// there are none. Today, the last day, isn't over yet.
    func dailyAverage(of value: (DayStats) -> Double) -> Double? {
        let finished = dropLast().filter(\.hasActivity)
        guard !finished.isEmpty else { return nil }
        return finished.map(value).reduce(0, +) / Double(finished.count)
    }

    /// Consecutive days, ending today, that meet `goal`. Today only breaks the
    /// streak once it's over, so an unfinished day counts from yesterday.
    func streak(where goal: (DayStats) -> Bool) -> Int {
        var count = 0
        for (index, day) in reversed().enumerated() {
            if goal(day) {
                count += 1
            } else if index == 0 {
                continue
            } else {
                break
            }
        }
        return count
    }
}
