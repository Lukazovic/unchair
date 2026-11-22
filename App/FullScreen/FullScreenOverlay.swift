import AppKit
import SwiftUI

/// Covers every screen during a break, for users who want to be made to stop.
/// Always skippable: a button, or Escape.
final class BreakOverlayController {
    private var panels: [OverlayPanel] = []

    var isVisible: Bool {
        !panels.isEmpty
    }

    func show(model: AppModel, onHide: @escaping () -> Void) {
        guard panels.isEmpty else { return }
        for screen in NSScreen.screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.onCancel = onHide
            panel.contentView = NSHostingView(rootView: BreakOverlayView(model: model, onHide: onHide))
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        NSApplication.shared.activate()
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
