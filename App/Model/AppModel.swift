import Foundation
import Observation
import UnchairCore

/// The app's single source of truth. Owns the ``UnchairEngine``, wakes it up
/// when its next deadline is reached, and turns its events into notifications.
@Observable
final class AppModel {
    private(set) var engine: UnchairEngine

    var settings: UnchairSettings {
        didSet {
            guard settings != oldValue else { return }
            store.settings = settings
            handle(engine.apply(settings, now: clock.now))
        }
    }

    var showsTimerInMenuBar: Bool {
        didSet { store.showsTimerInMenuBar = showsTimerInMenuBar }
    }

    /// The time the UI renders against. Refreshed every second while the
    /// Pomodoro runs, and less often otherwise.
    private(set) var now: Date

    @ObservationIgnored private let clock: any WallClock
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var displayTask: Task<Void, Never>?

    static let snoozeInterval: TimeInterval = 10 * 60
    static let focusExtension: TimeInterval = 5 * 60

    init(
        clock: any WallClock = SystemClock(),
        store: SettingsStore = SettingsStore(),
        notifications: NotificationService = NotificationService()
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications

        let now = clock.now
        let settings = store.settings
        self.now = now
        self.settings = settings
        showsTimerInMenuBar = store.showsTimerInMenuBar
        engine = UnchairEngine(settings: settings, hydrationLog: store.hydrationLog, now: now)

        notifications.onAction = { [weak self] action in
            self?.perform(action)
        }
        notifications.activate()
        stateDidChange()
    }

    // MARK: - Pomodoro

    func startPomodoro() {
        handle(engine.startPomodoro(now: clock.now))
        notifications.removeDelivered(.pomodoro)
    }

    func pausePomodoro() {
        handle(engine.pausePomodoro(now: clock.now))
    }

    func resumePomodoro() {
        handle(engine.resumePomodoro(now: clock.now))
    }

    func skipPomodoroPhase() {
        handle(engine.skipPomodoroPhase(now: clock.now))
        notifications.removeDelivered(.pomodoro)
    }

    func extendFocus() {
        handle(engine.extendFocus(by: Self.focusExtension, now: clock.now))
        notifications.removeDelivered(.pomodoro)
    }

    func resetPomodoro() {
        handle(engine.resetPomodoro(now: clock.now))
        notifications.removeDelivered(.pomodoro)
    }

    // MARK: - Posture

    func confirmPostureSwitch() {
        handle(engine.confirmPostureSwitch(now: clock.now))
        notifications.removeDelivered(.posture)
    }

    func snoozePosture() {
        handle(engine.snoozePosture(by: Self.snoozeInterval, now: clock.now))
        notifications.removeDelivered(.posture)
    }

    // MARK: - Hydration

    func logWater() {
        handle(engine.logWater(now: clock.now))
        notifications.removeDelivered(.hydration)
    }

    func removeWater() {
        handle(engine.removeWater(now: clock.now))
    }

    func snoozeHydration() {
        handle(engine.snoozeHydration(by: Self.snoozeInterval, now: clock.now))
        notifications.removeDelivered(.hydration)
    }

    // MARK: - Private

    private func perform(_ action: NotificationAction) {
        switch action {
        case .startBreak, .startFocus: startPomodoro()
        case .skipBreak: skipPomodoroPhase()
        case .extendFocus: extendFocus()
        case .confirmPosture: confirmPostureSwitch()
        case .snoozePosture: snoozePosture()
        case .logWater: logWater()
        case .snoozeWater: snoozeHydration()
        }
    }

    private func handle(_ events: [UnchairEvent]) {
        for event in events {
            notifications.post(event)
        }
        stateDidChange()
    }

    private func stateDidChange() {
        now = clock.now
        store.hydrationLog = engine.hydration.log
        scheduleNextDeadline()
        restartDisplayUpdates()
    }

    /// Sleeps until the engine's next deadline, then ticks it.
    private func scheduleNextDeadline() {
        deadlineTask?.cancel()
        guard let deadline = engine.nextDeadline else { return }
        deadlineTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(until: deadline)
            } catch {
                return
            }
            guard let self else { return }
            handle(engine.tick(now: clock.now))
        }
    }

    private func restartDisplayUpdates() {
        displayTask?.cancel()
        displayTask = Task { [weak self, clock] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval: TimeInterval = engine.pomodoro.isRunning ? 1 : 30
                do {
                    try await clock.sleep(for: interval)
                } catch {
                    return
                }
                now = clock.now
            }
        }
    }
}
