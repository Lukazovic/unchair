import AppKit
import SwiftUI

/// Covers every screen, for users who want to be made to stop: breaks and
/// full-screen reminders. Always dismissible: a button, or Escape.
final class FullScreenOverlay {
    private var panels: [OverlayPanel] = []

    var isVisible: Bool {
        !panels.isEmpty
    }

    func show(onCancel: @escaping () -> Void, @ViewBuilder content: () -> some View) {
        guard panels.isEmpty else { return }
        for screen in NSScreen.screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            // Alerts fire while another app is active; panels hide on deactivate by default.
            panel.hidesOnDeactivate = false
            panel.onCancel = onCancel
            panel.contentView = NSHostingView(rootView: content())
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        // Non-activating panels take keyboard focus (Escape, Return) without
        // needing the app to be active, which macOS may refuse for background apps.
        panels.first?.makeKey()
    }

    func hide() {
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }
}

/// A borderless panel that can take keyboard focus so Escape and Tab work.
private final class OverlayPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }
}
