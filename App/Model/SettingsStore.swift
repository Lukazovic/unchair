import Foundation
import UnchairCore

/// Persists settings and today's water log in `UserDefaults`.
struct SettingsStore {
    private enum Key {
        static let settings = "settings.v1"
        static let hydrationLog = "hydrationLog.v1"
        static let legacyShowsTimerInMenuBar = "showsTimerInMenuBar"
        static let menuBarTimer = "menuBarTimer"
        static let menuBarIcon = "menuBarIcon"
        static let quietUntil = "quietUntil"
        static let notificationSound = "notificationSound"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let legacyGlobalShortcut = "globalShortcut"
        static let globalShortcut = "globalShortcut.v2"
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

    /// The global shortcut, or `nil` when the user turned it off.
    var globalShortcut: GlobalShortcut? {
        get {
            if let data = defaults.data(forKey: Key.globalShortcut) {
                return try? decoder.decode(GlobalShortcut?.self, from: data)
            }
            if let legacy = defaults.string(forKey: Key.legacyGlobalShortcut) {
                return GlobalShortcut(legacyValue: legacy)
            }
            return .default
        }
        nonmutating set {
            // `null` is stored for "off", so it isn't mistaken for "never set".
            defaults.set(try? encoder.encode(newValue), forKey: Key.globalShortcut)
        }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        nonmutating set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var menuBarTimer: MenuBarTimerStyle {
        get {
            if let style = defaults.string(forKey: Key.menuBarTimer).flatMap(MenuBarTimerStyle.init) {
                return style
            }
            // Before the style choice, the timer was either off or a live countdown.
            let showedTimer = defaults.object(forKey: Key.legacyShowsTimerInMenuBar) as? Bool
            return showedTimer == false ? .hidden : .minutesAndSeconds
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.menuBarTimer) }
    }

    var menuBarIcon: MenuBarIconStyle {
        get { defaults.string(forKey: Key.menuBarIcon).flatMap(MenuBarIconStyle.init) ?? .figure }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.menuBarIcon) }
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
