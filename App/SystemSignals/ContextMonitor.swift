import AppKit

/// Periodically checks for meetings and full screen apps and reports changes.
final class ContextMonitor {
    struct Snapshot: Equatable {
        var isInMeeting = false
        var isFullscreen = false
    }

    var onChange: ((Snapshot) -> Void)?
    private(set) var snapshot = Snapshot()

    private static let pollInterval: Duration = .seconds(15)
    private var pollTask: Task<Void, Never>?
    private var tokens: [NSObjectProtocol] = []

    func start() {
        Log.signals.info("Meeting detector: \(MeetingDetector.diagnostics(), privacy: .public)")

        // Re-check right away when the frontmost app or Space changes.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            tokens.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.check()
                }
            })
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.check()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func check() {
        let new = Snapshot(
            isInMeeting: MeetingDetector.isInMeeting(),
            isFullscreen: FullscreenDetector.isFrontmostAppFullscreen()
        )
        guard new != snapshot else { return }
        Log.signals.info(
            "Context: meeting=\(new.isInMeeting, privacy: .public) fullscreen=\(new.isFullscreen, privacy: .public)"
        )
        snapshot = new
        onChange?(new)
    }
}
