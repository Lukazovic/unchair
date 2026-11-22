import Foundation
import Testing
@testable import UnchairCore

@Suite("TestClock")
struct TestClockTests {
    @Test("starts at the given date")
    func startsAtGivenDate() {
        let start = Date(timeIntervalSince1970: 1_000)
        let clock = TestClock(now: start)

        #expect(clock.now == start)
    }

    @Test("advance moves time forward")
    func advanceMovesTimeForward() {
        let clock = TestClock()
        let start = clock.now

        clock.advance(by: 90)

        #expect(clock.now == start.addingTimeInterval(90))
    }

    @Test("sleeper resumes only once its deadline is reached")
    func sleeperResumesAtDeadline() async throws {
        let clock = TestClock()
        let task = Task { try await clock.sleep(for: 60) }
        await clock.waitForSleepers(count: 1)

        clock.advance(by: 59)
        #expect(clock.sleeperCount == 1)

        clock.advance(by: 1)
        try await task.value
        #expect(clock.sleeperCount == 0)
    }

    @Test("sleeping until a past deadline returns immediately")
    func pastDeadlineReturnsImmediately() async throws {
        let clock = TestClock()
        clock.advance(by: 10)

        try await clock.sleep(until: Date(timeIntervalSinceReferenceDate: 5))

        #expect(clock.sleeperCount == 0)
    }

    @Test("only due sleepers are woken")
    func onlyDueSleepersWake() async throws {
        let clock = TestClock()
        let short = Task { try await clock.sleep(for: 10) }
        let long = Task { try await clock.sleep(for: 100) }
        await clock.waitForSleepers(count: 2)

        clock.advance(by: 10)
        try await short.value
        #expect(clock.sleeperCount == 1)

        clock.advance(by: 90)
        try await long.value
        #expect(clock.sleeperCount == 0)
    }

    @Test("cancelling a sleeping task throws CancellationError")
    func cancellationThrows() async {
        let clock = TestClock()
        let task = Task { try await clock.sleep(for: 60) }
        await clock.waitForSleepers(count: 1)

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(clock.sleeperCount == 0)
    }
}

@Suite("SystemClock")
struct SystemClockTests {
    @Test("now tracks the real date")
    func nowTracksRealDate() {
        let clock = SystemClock()
        let difference = abs(clock.now.timeIntervalSinceNow)

        #expect(difference < 1)
    }

    @Test("sleeping until a past deadline returns immediately")
    func pastDeadlineReturnsImmediately() async throws {
        let clock = SystemClock()

        try await clock.sleep(until: .distantPast)
    }
}
