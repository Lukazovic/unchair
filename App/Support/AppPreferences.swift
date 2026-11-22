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

/// A system-wide key combination that starts or pauses focus.
struct GlobalShortcut: Codable, Equatable {
    /// Virtual key code (`kVK_*`).
    var keyCode: UInt32
    /// Carbon modifier mask (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`).
    var modifiers: UInt32
    /// The key as shown to the user, captured when recording (layout-aware).
    var keyLabel: String

    static let `default` = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "P"
    )

    /// The combination as macOS shows it, for example "⌃⌥⌘P".
    var symbols: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        return result + keyLabel
    }

    /// A shortcut from a key press, or `nil` if it would get in the way of
    /// normal typing: it needs ⌘, ⌃, or ⌥, unless it's a function key.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        let keyCode = Int(event.keyCode)
        let functionKey = Self.functionKeys[keyCode]
        let hasRequiredModifier = modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasRequiredModifier || functionKey != nil else { return nil }

        let label = functionKey
            ?? Self.specialKeys[keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
        guard let label, !label.isEmpty else { return nil }
        self.init(keyCode: UInt32(keyCode), modifiers: modifiers, keyLabel: label)
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// Shortcuts saved by earlier versions, which offered a fixed list.
    init?(legacyValue: String) {
        let commandControlOption = UInt32(controlKey | optionKey | cmdKey)
        switch legacyValue {
        case "controlOptionCommandP": self = .default
        case "controlOptionCommandF":
            self.init(keyCode: UInt32(kVK_ANSI_F), modifiers: commandControlOption, keyLabel: "F")
        case "controlOptionSpace":
            self.init(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), keyLabel: "Space")
        default: return nil
        }
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]
}
