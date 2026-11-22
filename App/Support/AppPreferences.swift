import AppKit
import Carbon.HIToolbox
import SwiftUI
import UserNotifications

/// Sound used for notifications.
enum NotificationSoundOption: String, CaseIterable, Identifiable {
    case system
    case chime
    case bell
    case droplet
    case none

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System Default"
        case .chime: "Chime"
        case .bell: "Soft Bell"
        case .droplet: "Droplet"
        case .none: "None"
        }
    }

    private var fileName: String? {
        switch self {
        case .chime: "Unchair Chime.caf"
        case .bell: "Unchair Bell.caf"
        case .droplet: "Unchair Droplet.caf"
        case .system, .none: nil
        }
    }

    var notificationSound: UNNotificationSound? {
        switch self {
        case .system: .default
        case .none: nil
        case .chime, .bell, .droplet: fileName.map { UNNotificationSound(named: UNNotificationSoundName($0)) }
        }
    }

    func preview() {
        switch self {
        case .system:
            NSSound.beep()
        case .none:
            break
        case .chime, .bell, .droplet:
            guard let fileName, let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
            NSSound(contentsOf: url, byReference: true)?.play()
        }
    }
}

/// Keyboard shortcut that starts or pauses focus from any app.
enum GlobalShortcut: String, CaseIterable, Identifiable {
    case off
    case controlOptionCommandP
    case controlOptionCommandF
    case controlOptionSpace

    var id: String {
        rawValue
    }

    /// The key combination as macOS shows it, for example "⌃⌥⌘P".
    var symbols: String? {
        switch self {
        case .off: nil
        case .controlOptionCommandP: "⌃⌥⌘P"
        case .controlOptionCommandF: "⌃⌥⌘F"
        case .controlOptionSpace: "⌃⌥Space"
        }
    }

    var keyCode: UInt32? {
        switch self {
        case .off: nil
        case .controlOptionCommandP: UInt32(kVK_ANSI_P)
        case .controlOptionCommandF: UInt32(kVK_ANSI_F)
        case .controlOptionSpace: UInt32(kVK_Space)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .off: 0
        case .controlOptionCommandP, .controlOptionCommandF: UInt32(controlKey | optionKey | cmdKey)
        case .controlOptionSpace: UInt32(controlKey | optionKey)
        }
    }
}
