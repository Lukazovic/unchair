import Foundation

/// Locale-aware formatting shared by the UI and notifications.
enum Format {
    /// A countdown such as "24:59" or "1:29:59".
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let pattern: Duration.TimeFormatStyle.Pattern = total >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(total).formatted(.time(pattern: pattern))
    }

    /// A rounded-up duration such as "25 min" or "1 hr, 30 min".
    static func minutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// Rounded-up minutes for the menu bar, such as "25m" or "1h 30m".
    static func roundedMinutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 60 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .narrow))
    }

    /// A total such as "0 min", "45 min", or "2 hr, 5 min", rounded down to the minute.
    static func total(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 60 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }

    /// A compact total for chart axes, such as "45m" or "2h 30m".
    static func compactTotal(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 60 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .narrow))
    }

    /// A volume such as "250 mL".
    static func volume(_ milliliters: Int) -> String {
        Measurement(value: Double(milliliters), unit: UnitVolume.milliliters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }
}
