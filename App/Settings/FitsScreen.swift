import AppKit
import SwiftUI

extension View {
    /// Sizes a settings form to its content, up to the height available on the
    /// window's display. Past that, the form scrolls.
    func fitsScreenHeight() -> some View {
        modifier(FitsScreenHeight())
    }
}

private struct FitsScreenHeight: ViewModifier {
    @State private var maxHeight: CGFloat = 560

    func body(content: Content) -> some View {
        CappedHeightLayout(maxHeight: maxHeight) {
            content
        }
        .background(WindowHeightReader(maxHeight: $maxHeight))
    }
}

/// Gives its child its ideal height, but never more than `maxHeight`.
struct CappedHeightLayout: Layout {
    let maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, maxHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

/// Reports how tall the window's content can be on its current display, and
/// keeps the window's bottom edge on screen.
private struct WindowHeightReader: NSViewRepresentable {
    @Binding var maxHeight: CGFloat

    func makeNSView(context _: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = { height in
            if abs(height - maxHeight) > 1 {
                maxHeight = height
            }
        }
        return view
    }

    func updateNSView(_: ReaderView, context _: Context) {}

    final class ReaderView: NSView {
        var onChange: ((CGFloat) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // The view may move to another window, so it stops observing the old one.
            // swiftlint:disable:next notification_center_detachment
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            for name in [NSWindow.didChangeScreenNotification, NSWindow.didResizeNotification] {
                NotificationCenter.default.addObserver(
                    self, selector: #selector(refresh), name: name, object: window
                )
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refresh),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            scheduleUpdate()
        }

        @objc private func refresh(_: Notification) {
            scheduleUpdate()
        }

        /// Waits for the current layout pass, which may still be resizing the window.
        private func scheduleUpdate() {
            Task { [weak self] in
                self?.update()
            }
        }

        private func update() {
            guard let window, let visible = window.screen?.visibleFrame else { return }
            let chrome = window.frame.height - window.contentLayoutRect.height
            onChange?(max(200, visible.height - chrome - 16))
            if window.frame.minY < visible.minY, window.frame.height <= visible.height {
                window.setFrameOrigin(NSPoint(x: window.frame.minX, y: visible.minY))
            }
        }
    }
}
