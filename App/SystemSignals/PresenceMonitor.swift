import AppKit
import CoreGraphics

/// Reports when the user goes away (idle, asleep, or screen locked) and comes back.
final class PresenceMonitor {
    enum Change: Equatable {
        case away(since: Date)
        case returned
    }

    var onChange: ((Change) -> Void)?
    /// Inactivity after which the user counts as away.
    var idleThreshold: TimeInterval = 5 * 60
    /// While this returns `true`, inactivity doesn't count as away (for
    /// example, listening in a meeting without touching the keyboard).
    var isIdleExcused: () -> Bool = { false }

    private enum Reason: Hashable {
        case idle
        case asleep
        case locked
    }

    private static let pollInterval: Duration = .seconds(10)
    private var reasons: [Reason: Date] = [:]
    private var pollTask: Task<Void, Never>?
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.begin(.asleep) }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.end(.asleep) }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.begin(.asleep) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.end(.asleep) }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.begin(.locked) }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.end(.locked) }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkIdle()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    private func checkIdle() {
        guard let anyInput = CGEventType(rawValue: ~0) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        Log.signals.debug("Idle for \(Int(idle), privacy: .public)s")
        if idle >= idleThreshold, !isIdleExcused() {
            begin(.idle, since: Date().addingTimeInterval(-idle))
        } else if idle < idleThreshold {
            end(.idle)
        }
    }

    private func begin(_ reason: Reason, since: Date = Date()) {
        guard reasons[reason] == nil else { return }
        let wasAway = !reasons.isEmpty
        reasons[reason] = since
        Log.signals.info("Away: \(String(describing: reason), privacy: .public)")
        if !wasAway {
            onChange?(.away(since: since))
        }
    }

    private func end(_ reason: Reason) {
        guard reasons.removeValue(forKey: reason) != nil else { return }
        Log.signals.info("No longer away: \(String(describing: reason), privacy: .public)")
        if reasons.isEmpty {
            onChange?(.returned)
        }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        handler: @escaping @MainActor (PresenceMonitor) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        tokens.append((center, token))
    }
}
