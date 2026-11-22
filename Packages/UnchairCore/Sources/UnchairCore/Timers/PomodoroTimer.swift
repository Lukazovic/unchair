import Foundation

/// Something notable that happened to a ``PomodoroTimer``.
public enum PomodoroEvent: Equatable, Sendable {
    /// `phase` ran to completion. `next` is the following phase, and
    /// `autoStarted` tells whether it has already started.
    case phaseCompleted(PomodoroPhase, next: PomodoroPhase, autoStarted: Bool)
}

/// A Pomodoro state machine.
///
/// The timer never reads the clock itself: every method takes `now`. Call
/// ``tick(now:)`` when ``nextDeadline`` is reached to complete the phase.
public struct PomodoroTimer: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case running(PomodoroPhase, endsAt: Date, duration: TimeInterval)
        case paused(PomodoroPhase, remaining: TimeInterval, duration: TimeInterval)
        /// The previous phase ended and `PomodoroPhase` is waiting to be started.
        case awaiting(PomodoroPhase)
    }

    public var settings: PomodoroSettings
    public private(set) var state: State = .idle
    /// Focus sessions completed since the last reset. Skipped and extended
    /// sessions don't count.
    public private(set) var completedFocusSessions = 0
    public private(set) var lastCompletedPhase: PomodoroPhase?
    /// How long the last completed phase lasted, for history.
    public private(set) var lastCompletedPhaseDuration: TimeInterval?
    private var currentPhaseCounts = true

    public init(settings: PomodoroSettings = PomodoroSettings()) {
        self.settings = settings
    }

    // MARK: - Queries

    /// The phase that is running or paused.
    public var phase: PomodoroPhase? {
        switch state {
        case let .running(phase, _, _), let .paused(phase, _, _): phase
        case .idle, .awaiting: nil
        }
    }

    public var isRunning: Bool {
        if case .running = state {
            true
        } else {
            false
        }
    }

    /// When the running phase ends.
    public var nextDeadline: Date? {
        if case let .running(_, endsAt, _) = state {
            endsAt
        } else {
            nil
        }
    }

    /// Time left in the running or paused phase.
    public func remaining(at now: Date) -> TimeInterval? {
        switch state {
        case let .running(_, endsAt, _): max(0, endsAt.timeIntervalSince(now))
        case let .paused(_, remaining, _): remaining
        case .idle, .awaiting: nil
        }
    }

    /// Fraction of the running or paused phase that has elapsed, from 0 to 1.
    public func progress(at now: Date) -> Double? {
        let duration: TimeInterval
        switch state {
        case let .running(_, _, phaseDuration), let .paused(_, _, phaseDuration): duration = phaseDuration
        case .idle, .awaiting: return nil
        }
        guard duration > 0, let remaining = remaining(at: now) else { return nil }
        return min(1, max(0, 1 - remaining / duration))
    }

    /// Focus sessions completed in the current cycle, from 0 to
    /// `sessionsBeforeLongBreak`. Shows a full cycle until the long break ends.
    public var sessionsInCurrentCycle: Int {
        let length = cycleLength
        let position = completedFocusSessions % length
        if position == 0, completedFocusSessions > 0, lastCompletedPhase == .focus {
            return length
        }
        return position
    }

    public var cycleLength: Int {
        max(1, settings.sessionsBeforeLongBreak)
    }

    // MARK: - Actions

    /// Starts a focus session when idle, or the pending phase when awaiting.
    public mutating func start(now: Date) {
        switch state {
        case .idle: begin(.focus, now: now)
        case let .awaiting(next): begin(next, now: now)
        case .running, .paused: break
        }
    }

    public mutating func pause(now: Date) {
        guard case let .running(phase, endsAt, duration) = state else { return }
        let remaining = min(duration, max(0, endsAt.timeIntervalSince(now)))
        state = .paused(phase, remaining: remaining, duration: duration)
    }

    public mutating func resume(now: Date) {
        guard case let .paused(phase, remaining, duration) = state else { return }
        state = .running(phase, endsAt: now.addingTimeInterval(remaining), duration: duration)
    }

    /// Ends the current phase early and immediately starts the next one.
    ///
    /// A skipped focus session doesn't count toward the cycle and is followed
    /// by a short break. Skipping a break (running, paused, or pending) starts
    /// a focus session.
    ///
    /// - Returns: The phase that started, or `nil` if there was nothing to skip.
    @discardableResult
    public mutating func skip(now: Date) -> PomodoroPhase? {
        let next: PomodoroPhase
        switch state {
        case .idle, .awaiting(.focus):
            return nil
        case let .running(phase, _, _), let .paused(phase, _, _):
            next = phase == .focus ? .shortBreak : .focus
        case .awaiting:
            next = .focus
        }
        begin(next, now: now)
        return next
    }

    /// Returns to focus for `interval` more seconds right after a focus
    /// session ended (for example, a "+5 min" action).
    ///
    /// Only valid while the following break is pending or underway. The
    /// extension doesn't count as another session.
    ///
    /// - Returns: Whether the focus session was extended.
    @discardableResult
    public mutating func extendFocus(by interval: TimeInterval, now: Date) -> Bool {
        guard lastCompletedPhase == .focus else { return false }
        switch state {
        case let .awaiting(phase) where phase.isBreak,
             let .running(phase, _, _) where phase.isBreak,
             let .paused(phase, _, _) where phase.isBreak:
            begin(.focus, duration: interval, now: now, counts: false)
            return true
        default:
            return false
        }
    }

    /// Abandons a running or paused focus session without counting it, leaving
    /// a fresh focus session waiting to be started. The cycle is kept.
    public mutating func discardFocus() {
        guard phase == .focus else { return }
        currentPhaseCounts = true
        state = .awaiting(.focus)
    }

    /// Stops the timer and clears the cycle.
    public mutating func reset() {
        state = .idle
        completedFocusSessions = 0
        lastCompletedPhase = nil
        currentPhaseCounts = true
    }

    /// Completes the running phase if its deadline has passed.
    public mutating func tick(now: Date) -> PomodoroEvent? {
        guard case let .running(phase, endsAt, duration) = state, now >= endsAt else { return nil }

        if phase == .focus, currentPhaseCounts {
            completedFocusSessions += 1
        }
        lastCompletedPhase = phase
        lastCompletedPhaseDuration = duration

        let next = phaseAfter(phase)
        let autoStart = next.isBreak ? settings.autoStartBreaks : settings.autoStartFocus
        if autoStart {
            begin(next, now: now)
        } else {
            state = .awaiting(next)
        }
        return .phaseCompleted(phase, next: next, autoStarted: autoStart)
    }

    // MARK: - Private

    private func phaseAfter(_ phase: PomodoroPhase) -> PomodoroPhase {
        guard phase == .focus else { return .focus }
        let isCycleComplete = completedFocusSessions > 0 && completedFocusSessions % cycleLength == 0
        return isCycleComplete ? .longBreak : .shortBreak
    }

    private mutating func begin(
        _ phase: PomodoroPhase,
        duration: TimeInterval? = nil,
        now: Date,
        counts: Bool = true
    ) {
        let duration = duration ?? settings.duration(for: phase)
        currentPhaseCounts = counts
        state = .running(phase, endsAt: now.addingTimeInterval(duration), duration: duration)
    }
}
