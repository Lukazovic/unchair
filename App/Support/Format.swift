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

    /// A volume such as "250 mL".
    static func volume(_ milliliters: Int) -> String {
        Measurement(value: Double(milliliters), unit: UnitVolume.milliliters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }
}
