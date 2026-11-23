import AppKit
import SwiftUI

/// Covers every screen, for users who want to be made to stop: breaks and
/// full-screen reminders. Always dismissible: a button, or Escape.
final class FullScreenOverlay {
    private var panels: [OverlayPanel] = []
    private var screenObserver: (any NSObjectProtocol)?
    private var rebuildPanels: (() -> Void)?
    private var keyFocusTask: Task<Void, Never>?

    /// How long the keyboard must be quiet before an alert takes it over.
    private static let typingPause: TimeInterval = 1.5

    var isVisible: Bool {
        !panels.isEmpty
    }

    func show(onCancel: @escaping () -> Void, @ViewBuilder content: () -> some View) {
        guard panels.isEmpty else { return }
        let view = AnyView(content())
        rebuildPanels = { [weak self] in
            self?.closePanels()
            self?.makePanels(view, onCancel: onCancel)
        }
        rebuildPanels?()
        // Resolution, scaling, or connected displays may change while visible.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildPanels?()
            }
        }
    }

    func hide() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        rebuildPanels = nil
        closePanels()
    }

    private func closePanels() {
        keyFocusTask?.cancel()
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }

    private func makePanels(_ view: AnyView, onCancel: @escaping () -> Void) {
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
            let hostingView = NSHostingView(rootView: view)
            // The display sets the size, never the content.
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        takeKeyFocusAfterTyping()
    }

    /// Non-activating panels take keyboard focus (Escape, Return) without
    /// needing the app to be active, which macOS may refuse for background apps.
    /// Waits for a pause in typing, so a Return meant for another app never
    /// answers the alert.
    private func takeKeyFocusAfterTyping() {
        keyFocusTask = Task { [weak self] in
            let shownAt = Date.now
            repeat {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            } while Self.secondsSinceLastKey < Self.typingPause || Date.now.timeIntervalSince(shownAt) < 1
            self?.panels.first?.makeKey()
        }
    }

    private static var secondsSinceLastKey: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }
}

/// A borderless panel that can take keyboard focus so Escape and Tab work.
private final class OverlayPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    /// Keeps the panel over the menu bar and notch, where AppKit may push it down.
    override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect {
        frameRect
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }
}
