import Foundation

/// A ``WallClock`` backed by the real system time.
public struct SystemClock: WallClock {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(until deadline: Date) async throws {
        let interval = deadline.timeIntervalSince(now)
        guard interval > 0 else {
            try Task.checkCancellation()
            return
        }
        try await Task.sleep(for: .seconds(interval))
    }
}
