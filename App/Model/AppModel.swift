import Foundation
import Observation
import UnchairCore

/// The app's single source of truth. Owns the ``UnchairEngine``, feeds it
/// system signals, wakes it up at its next deadline, and turns its events into
/// notifications.
@Observable
final class AppModel {
    enum QuietDuration: CaseIterable {
        case thirtyMinutes
        case oneHour
        case untilTomorrow
    }

    private(set) var engine: UnchairEngine

    var settings: UnchairSettings {
        didSet {
            guard settings != oldValue else { return }
            store.settings = settings
            presence.idleThreshold = settings.interruptions.awayThreshold
            handle(engine.apply(settings, now: clock.now))
        }
    }

    var showsTimerInMenuBar: Bool {
        didSet { store.showsTimerInMenuBar = showsTimerInMenuBar }
    }

    /// The time the UI renders against. Refreshed every second while the
    /// Pomodoro runs, and less often otherwise.
    private(set) var now: Date

    var holdReason: HoldReason? {
        engine.holdReason(at: now)
    }

    @ObservationIgnored private let clock: any WallClock
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let presence = PresenceMonitor()
    @ObservationIgnored private let contextMonitor = ContextMonitor()
    @ObservationIgnored private let focusFilter = FocusFilterBridge.shared
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
        engine = UnchairEngine(
            settings: settings,
            hydrationLog: store.hydrationLog,
            quietUntil: store.quietUntil,
            now: now
        )

        notifications.onAction = { [weak self] action in
            self?.perform(action)
        }
        notifications.activate()
        startMonitoring()
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
        notifications.removeDelivered(.posture, .reminders)
    }

    func snoozePosture() {
        handle(engine.snoozePosture(by: Self.snoozeInterval, now: clock.now))
        notifications.removeDelivered(.posture, .reminders)
    }

    // MARK: - Hydration

    func logWater() {
        handle(engine.logWater(now: clock.now))
        notifications.removeDelivered(.hydration, .reminders)
    }

    func removeWater() {
        handle(engine.removeWater(now: clock.now))
    }

    func snoozeHydration() {
        handle(engine.snoozeHydration(by: Self.snoozeInterval, now: clock.now))
        notifications.removeDelivered(.hydration, .reminders)
    }

    // MARK: - Quiet mode

    func pauseReminders(for duration: QuietDuration) {
        let now = clock.now
        let until: Date = switch duration {
        case .thirtyMinutes: now.addingTimeInterval(30 * 60)
        case .oneHour: now.addingTimeInterval(60 * 60)
        case .untilTomorrow:
            Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
                ?? now.addingTimeInterval(12 * 60 * 60)
        }
        handle(engine.pauseReminders(until: until, now: now))
    }

    func resumeReminders() {
        handle(engine.pauseReminders(until: nil, now: clock.now))
    }

    // MARK: - Private

    private func startMonitoring() {
        presence.idleThreshold = settings.interruptions.awayThreshold
        presence.isIdleExcused = { [weak self] in
            self?.engine.context.isInMeeting ?? false
        }
        presence.onChange = { [weak self] change in
            guard let self else { return }
            switch change {
            case let .away(since):
                handle(engine.userBecameAway(since: since, now: clock.now))
            case .returned:
                handle(engine.userReturned(now: clock.now))
            }
        }
        presence.start()

        contextMonitor.onChange = { [weak self] _ in
            self?.updateContext()
        }
        contextMonitor.start()

        focusFilter.onChange = { [weak self] _ in
            self?.updateContext()
        }
        Task {
            await focusFilter.loadCurrent()
        }
    }

    private func updateContext() {
        let snapshot = contextMonitor.snapshot
        let context = ReminderContext(
            isInMeeting: snapshot.isInMeeting,
            isFullscreen: snapshot.isFullscreen,
            focusFilterHoldsReminders: focusFilter.holdsReminders
        )
        guard context != engine.context else { return }
        handle(engine.update(context, now: clock.now))
    }

    private func perform(_ action: NotificationAction) {
        switch action {
        case .startBreak, .startFocus: startPomodoro()
        case .skipBreak: skipPomodoroPhase()
        case .extendFocus: extendFocus()
        case .confirmPosture: confirmPostureSwitch()
        case .snoozePosture: snoozePosture()
        case .logWater: logWater()
        case .snoozeWater: snoozeHydration()
        case .completeReminders:
            handle(engine.confirmPostureSwitch(now: clock.now) + engine.logWater(now: clock.now))
        case .snoozeReminders:
            let now = clock.now
            handle(
                engine.snoozePosture(by: Self.snoozeInterval, now: now)
                    + engine.snoozeHydration(by: Self.snoozeInterval, now: now)
            )
        }
    }

    private func handle(_ events: [UnchairEvent]) {
        let now = clock.now
        let isQuiet = switch engine.holdReason(at: now) {
        case .quietMode, .focusMode, .meeting, .fullscreen: true
        case .away, .outsideWorkingHours, nil: false
        }
        notifications.post(events, quietly: isQuiet)
        stateDidChange()
    }

    private func stateDidChange() {
        now = clock.now
        store.hydrationLog = engine.hydration.log
        store.quietUntil = engine.quietUntil
        scheduleNextDeadline()
        restartDisplayUpdates()
    }

    /// Sleeps until the engine's next deadline, then ticks it.
    private func scheduleNextDeadline() {
        deadlineTask?.cancel()
        guard let deadline = engine.nextDeadline(after: clock.now) else { return }
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
