import Foundation
import UnchairCore

extension AppModel {
    func todayStats() -> DayStats {
        recentStats(days: 1).last ?? DayStats(day: Calendar.current.startOfDay(for: clock.now))
    }

    /// Daily totals for the last `days` days, oldest first.
    func recentStats(days: Int) -> [DayStats] {
        let calendar = Calendar.current
        let now = clock.now
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        return history.history(since: start).dailyStats(days: days, endingAt: now, calendar: calendar)
    }

    /// A one-line summary of today, for the end-of-day notification and Shortcuts.
    func todaySummary() -> String {
        let today = todayStats()
        let focus = Format.minutes(max(60, today.focusTime))
        let standing = Format.minutes(max(60, today.standingTime))
        let water = Format.volume(engine.hydration.intake(at: clock.now))
        if today.focusSessions == 0 {
            return String(localized: "Stood \(standing) · Drank \(water)")
        }
        return String(localized: "Focused \(focus) · Stood \(standing) · Drank \(water)")
    }
}
