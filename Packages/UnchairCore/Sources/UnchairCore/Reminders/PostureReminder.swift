import Foundation

public enum Posture: String, Codable, Sendable {
    case sitting
    case standing

    public var toggled: Posture {
        self == .sitting ? .standing : .sitting
    }
}

public struct PostureSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var sittingDuration: TimeInterval
    public var standingDuration: TimeInterval
    /// When on, a switch that comes due during a focus session waits for the
    /// next break so it doesn't interrupt focus.
    public var syncWithPomodoro: Bool

    public init(
        isEnabled: Bool = true,
        sittingDuration: TimeInterval = 45 * 60,
        standingDuration: TimeInterval = 15 * 60,
        syncWithPomodoro: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.sittingDuration = sittingDuration
        self.standingDuration = standingDuration
        self.syncWithPomodoro = syncWithPomodoro
    }

    public func duration(for posture: Posture) -> TimeInterval {
        posture == .sitting ? sittingDuration : standingDuration
    }
}

public enum PostureEvent: Equatable, Sendable {
    case switchSuggested(to: Posture)
}

/// Alternates between sitting and standing.
///
/// Like ``PomodoroTimer``, it never reads the clock itself.
public struct PostureReminder: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case stopped
        /// Counting down to the next switch.
        case counting(until: Date)
        /// The switch is due but held until the current focus session ends.
        case waitingForBreak
        /// The switch was suggested and is waiting for confirmation.
        case suggested
    }

    public var settings: PostureSettings
    public private(set) var posture: Posture = .sitting
    public private(set) var state: State = .stopped

    public init(settings: PostureSettings = PostureSettings()) {
        self.settings = settings
    }

    public var nextDeadline: Date? {
        if case let .counting(until) = state {
            until
        } else {
            nil
        }
    }

    /// Starts counting, assuming the user is sitting.
    public mutating func start(now: Date) {
        posture = .sitting
        restartCountdown(now: now)
    }

    public mutating func stop() {
        state = .stopped
    }

    /// Restarts the countdown for the current posture, for example after its
    /// duration changed.
    public mutating func restartCountdown(now: Date) {
        state = .counting(until: now.addingTimeInterval(settings.duration(for: posture)))
    }

    /// Records that the user switched posture and starts the next countdown.
    /// Works at any time, not only after a suggestion.
    public mutating func confirmSwitch(now: Date) {
        guard state != .stopped else { return }
        posture = posture.toggled
        restartCountdown(now: now)
    }

    /// Postpones the suggestion by `interval` seconds.
    public mutating func snooze(by interval: TimeInterval, now: Date) {
        guard state != .stopped else { return }
        state = .counting(until: now.addingTimeInterval(interval))
    }

    /// Suggests a switch when it's due.
    ///
    /// - Parameter isFocusing: Whether a focus session is running. With
    ///   ``PostureSettings/syncWithPomodoro`` on, the suggestion waits until
    ///   this is `false`.
    public mutating func tick(now: Date, isFocusing: Bool) -> PostureEvent? {
        let shouldHold = isFocusing && settings.syncWithPomodoro
        switch state {
        case let .counting(until) where now >= until:
            if shouldHold {
                state = .waitingForBreak
                return nil
            }
            return suggest()
        case .waitingForBreak where !shouldHold:
            return suggest()
        default:
            return nil
        }
    }

    private mutating func suggest() -> PostureEvent {
        state = .suggested
        return .switchSuggested(to: posture.toggled)
    }
}
