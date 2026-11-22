import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Uses Carbon hot keys, which work in the
/// sandbox and don't need Accessibility permission.
final class GlobalHotKey {
    private static var action: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func register(_ shortcut: GlobalShortcut, action: @escaping () -> Void) {
        unregister()
        guard let keyCode = shortcut.keyCode else { return }
        Self.action = action
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: OSType(0x554E_4348), id: 1) // "UNCH"
        let status = RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if status != noErr {
            Log.signals.error("Couldn't register global shortcut: \(status, privacy: .public)")
        }
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
