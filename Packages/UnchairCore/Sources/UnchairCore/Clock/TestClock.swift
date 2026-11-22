import Foundation

/// A manually controlled ``WallClock`` for tests.
///
/// Time only moves when ``advance(by:)`` or ``advance(to:)`` is called. Tasks
/// sleeping on this clock resume once the clock reaches their deadline.
///
/// ```swift
/// let clock = TestClock()
/// let task = Task { try await clock.sleep(for: 60) }
/// await clock.waitForSleepers(count: 1)
/// clock.advance(by: 60) // `task` resumes
/// ```
public final class TestClock: WallClock, @unchecked Sendable {
    private struct Sleeper {
        let deadline: Date
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current: Date
    private var sleepers: [UUID: Sleeper] = [:]

    /// Creates a clock starting at `now`.
    public init(now: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        current = now
    }

    public var now: Date {
        lock.withLock { current }
    }

    /// The number of tasks currently sleeping on this clock.
    public var sleeperCount: Int {
        lock.withLock { sleepers.count }
    }

    public func sleep(until deadline: Date) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                enum Outcome { case wait, resume, cancel }

                let outcome: Outcome = lock.withLock {
                    if Task.isCancelled {
                        return .cancel
                    }
                    if deadline <= current {
                        return .resume
                    }
                    sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return .wait
                }

                switch outcome {
                case .wait:
                    break
                case .resume:
                    continuation.resume()
                case .cancel:
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper = lock.withLock { sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock forward by `interval` seconds and wakes every sleeper
    /// whose deadline has been reached.
    public func advance(by interval: TimeInterval) {
        precondition(interval >= 0, "TestClock cannot move backwards")
        advance(to: now.addingTimeInterval(interval))
    }

    /// Moves the clock to `date` and wakes every sleeper whose deadline has
    /// been reached.
    public func advance(to date: Date) {
        let due: [Sleeper] = lock.withLock {
            precondition(date >= current, "TestClock cannot move backwards")
            current = date
            let dueIDs = sleepers.filter { $0.value.deadline <= date }.map(\.key)
            return dueIDs.compactMap { sleepers.removeValue(forKey: $0) }
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Waits until at least `count` tasks are sleeping on this clock.
    ///
    /// Use this in tests before calling ``advance(by:)`` so the code under test
    /// has had a chance to start sleeping.
    public func waitForSleepers(count: Int) async {
        while sleeperCount < count {
            await Task.yield()
        }
    }
}
