import Foundation

/// How a reminder gets the user's attention.
public enum AlertStyle: String, Codable, Sendable, CaseIterable {
    /// A regular notification banner.
    case notification
    /// A window that covers every screen until the user responds.
    case fullScreen
}

/// The alert style of each wellbeing reminder.
public struct AlertSettings: Codable, Equatable, Sendable {
    /// Reminders shown full screen. All others use notifications.
    public var fullScreenReminders: Set<ReminderKind>

    public init(fullScreenReminders: Set<ReminderKind> = []) {
        self.fullScreenReminders = fullScreenReminders
    }

    public func style(for kind: ReminderKind) -> AlertStyle {
        fullScreenReminders.contains(kind) ? .fullScreen : .notification
    }

    public mutating func setStyle(_ style: AlertStyle, for kind: ReminderKind) {
        switch style {
        case .notification: fullScreenReminders.remove(kind)
        case .fullScreen: fullScreenReminders.insert(kind)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case fullScreenReminders
    }

    /// Unknown reminder kinds are dropped instead of failing the whole section.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent([String].self, forKey: .fullScreenReminders) ?? []
        fullScreenReminders = Set(raw.compactMap(ReminderKind.init(rawValue:)))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullScreenReminders.map(\.rawValue).sorted(), forKey: .fullScreenReminders)
    }
}
