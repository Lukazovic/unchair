import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Uses Carbon hot keys, which work in the
/// sandbox and don't need Accessibility permission.
final class GlobalHotKey {
    private static var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// Registers `shortcut`, replacing any previous one. Passing `nil` turns it off.
    ///
    /// - Returns: `noErr`, or the Carbon error (for example
    ///   `eventHotKeyExistsErr` when another app already uses the combination).
    @discardableResult
    func register(_ shortcut: GlobalShortcut?, action: @escaping () -> Void) -> OSStatus {
        unregister()
        guard let shortcut else { return noErr }
        Self.action = action
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: OSType(0x554E_4348), id: 1) // "UNCH"
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            Log.signals.error("Couldn't register global shortcut: \(status, privacy: .public)")
        }
        return status
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hot key events on the main thread.
            MainActor.assumeIsolated {
                GlobalHotKey.action?()
            }
            return noErr
        }, 1, &eventType, nil, &handler)
    }
}
