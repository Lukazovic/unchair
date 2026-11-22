import Foundation

/// A source of wall-clock time that can be injected into timers and schedulers.
///
/// Production code uses ``SystemClock``. Tests use ``TestClock`` to control time
/// deterministically instead of waiting for real seconds to pass.
///
/// This is named `WallClock` to avoid clashing with the standard library's
/// `Clock` protocol. Unchair works with calendar dates (working hours, day
/// rollover), so it needs `Date` rather than monotonic instants.
public protocol WallClock: Sendable {
    /// The current date and time.
    var now: Date { get }

    /// Suspends the current task until `deadline` is reached.
    ///
    /// Returns immediately if `deadline` is not in the future.
    /// Throws `CancellationError` if the task is cancelled while waiting.
    func sleep(until deadline: Date) async throws
}

public extension WallClock {
    /// Suspends the current task for `duration` seconds from ``now``.
    func sleep(for duration: TimeInterval) async throws {
        try await sleep(until: now.addingTimeInterval(duration))
    }
}
