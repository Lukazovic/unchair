import Foundation
import UnchairCore

/// Persists settings and today's water log in `UserDefaults`.
struct SettingsStore {
    private enum Key {
        static let settings = "settings.v1"
        static let hydrationLog = "hydrationLog.v1"
        static let showsTimerInMenuBar = "showsTimerInMenuBar"
        static let quietUntil = "quietUntil"
        static let notificationSound = "notificationSound"
        static let globalShortcut = "globalShortcut"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: UnchairSettings {
        get { decode(UnchairSettings.self, forKey: Key.settings) ?? UnchairSettings() }
        nonmutating set { encode(newValue, forKey: Key.settings) }
    }

    var hydrationLog: HydrationLog? {
        get { decode(HydrationLog.self, forKey: Key.hydrationLog) }
        nonmutating set { encode(newValue, forKey: Key.hydrationLog) }
    }

    /// End of the user's "pause reminders" period.
    var quietUntil: Date? {
        get { defaults.object(forKey: Key.quietUntil) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.quietUntil) }
    }

    var notificationSound: NotificationSoundOption {
        get { defaults.string(forKey: Key.notificationSound).flatMap(NotificationSoundOption.init) ?? .chime }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.notificationSound) }
    }

    var globalShortcut: GlobalShortcut {
        get { defaults.string(forKey: Key.globalShortcut).flatMap(GlobalShortcut.init) ?? .controlOptionCommandP }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.globalShortcut) }
    }

    var showsTimerInMenuBar: Bool {
        get { defaults.object(forKey: Key.showsTimerInMenuBar) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.showsTimerInMenuBar) }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func encode(_ value: (some Encodable)?, forKey key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
