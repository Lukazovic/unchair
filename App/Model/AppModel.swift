import AppKit
import Carbon.HIToolbox
import Foundation
import Observation
import UnchairCore
import UserNotifications

/// The app's single source of truth. Owns the ``UnchairEngine``, feeds it
/// system signals, wakes it up at its next deadline, records history, and
/// turns events into notifications.
@Observable
final class AppModel {
    enum QuietDuration: String, CaseIterable {
        case thirtyMinutes
        case oneHour
        case untilTomorrow
    }

    /// The running app's model, for App Intents.
    private(set) static var shared: AppModel?

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

    var notificationSound: NotificationSoundOption {
        didSet {
            store.notificationSound = notificationSound
            notifications.sound = notificationSound
        }
    }

    var globalShortcut: GlobalShortcut? {
        didSet {
            store.globalShortcut = globalShortcut
            registerGlobalShortcut()
        }
    }

    private(set) var hasCompletedOnboarding: Bool

    /// Whether Unchair may post notifications. `nil` until first checked.
    internal(set) var notificationStatus: UNAuthorizationStatus?

    /// The reminders currently covering the screen.
    internal(set) var fullScreenReminder: FullScreenReminder?

    /// Set when the global shortcut couldn't be registered.
    private(set) var globalShortcutError: String?

    /// The time the UI renders against. Refreshed every second while the
    /// Pomodoro runs, and less often otherwise.
    private(set) var now: Date

    var holdReason: HoldReason? {
        engine.holdReason(at: now)
    }

    /// The stretch to suggest during the current or upcoming break.
    var currentStretch: Stretch? {
        guard settings.breaks.suggestsStretches else { return nil }
        let pomodoro = engine.pomodoro
        let isBreak = switch pomodoro.state {
        case let .running(phase, _, _), let .paused(phase, _, _), let .awaiting(phase): phase.isBreak
        case .idle: false
        }
        return isBreak ? Stretch.suggestion(forBreak: pomodoro.completedFocusSessions) : nil
    }

    @ObservationIgnored let history: HistoryStore
    @ObservationIgnored let updates = UpdateController()
    @ObservationIgnored let clock: any WallClock
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored let notifications: NotificationService
    @ObservationIgnored private let presence = PresenceMonitor()
    @ObservationIgnored private let contextMonitor = ContextMonitor()
    @ObservationIgnored private let focusFilter = FocusFilterBridge.shared
    @ObservationIgnored let breakOverlay = FullScreenOverlay()
    @ObservationIgnored let reminderOverlay = FullScreenOverlay()
    @ObservationIgnored private let hotKey = GlobalHotKey()
    @ObservationIgnored private let widgets = WidgetPublisher()
    @ObservationIgnored private var deadlineTask: Task<Void, Never>?
    @ObservationIgnored private var displayTask: Task<Void, Never>?
    @ObservationIgnored private var lastPresence: PresenceState?
    /// The break whose overlay the user hid.
    @ObservationIgnored var hiddenBreakOverlay: BreakOverlayKey?

    static let snoozeInterval: TimeInterval = 10 * 60
    static let focusExtension: TimeInterval = 5 * 60

    init(
        clock: any WallClock = SystemClock(),
        store: SettingsStore = SettingsStore(),
        history: HistoryStore = HistoryStore(),
        notifications: NotificationService = NotificationService()
    ) {
        self.clock = clock
        self.store = store
        self.history = history
        self.notifications = notifications

        let now = clock.now
        let settings = store.settings
        self.now = now
        self.settings = settings
        showsTimerInMenuBar = store.showsTimerInMenuBar
        hasCompletedOnboarding = store.hasCompletedOnboarding
        notificationSound = store.notificationSound
        globalShortcut = store.globalShortcut
        engine = UnchairEngine(
            settings: settings,
            hydrationLog: store.hydrationLog,
            quietUntil: store.quietUntil,
            now: now
        )

        Self.shared = self
        notifications.sound = notificationSound
        notifications.onAction = { [weak self] action, kinds in
            self?.perform(action, kinds: kinds)
        }
        notifications.activate()
        Task {
            if hasCompletedOnboarding {
                await notifications.requestAuthorization()
            }
            await refreshNotificationStatus()
        }
        startMonitoring()
        registerGlobalShortcut()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.recordPresence(.away)
            }
        }
        stateDidChange()
        #if DEBUG
            // Pass `-UnchairDemoFullScreen` to see a full-screen reminder at launch.
            if CommandLine.arguments.contains("-UnchairDemoFullScreen") {
                Task {
                    try? await clock.sleep(for: 1)
                    presentFullScreen([.posture, .hydration], postureTarget: .standing)
                }
            }
        #endif
    }

    // MARK: - Onboarding

    func completeOnboarding(profile: UsageProfile) {
        var newSettings = settings
        profile.apply(to: &newSettings)
        settings = newSettings
        store.hasCompletedOnboarding = true
        hasCompletedOnboarding = true
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

    // MARK: - Reminders

    func confirmPostureSwitch() {
        record(.posture, .completed)
        clearFullScreen(.posture)
        handle(engine.confirmPostureSwitch(now: clock.now))
        notifications.removeDelivered(.reminders)
    }

    func logWater() {
        let before = engine.hydration.intake(at: clock.now)
        clearFullScreen(.hydration)
        handle(engine.logWater(now: clock.now))
        history.recordWater(engine.hydration.intake(at: clock.now) - before, at: clock.now)
        notifications.removeDelivered(.reminders)
    }

    func removeWater() {
        let before = engine.hydration.intake(at: clock.now)
        handle(engine.removeWater(now: clock.now))
        history.recordWater(engine.hydration.intake(at: clock.now) - before, at: clock.now)
    }

    func completeEyeBreak() {
        record(.eyes, .completed)
        clearFullScreen(.eyes)
        handle(engine.completeEyeBreak(now: clock.now))
        notifications.removeDelivered(.reminders)
    }

    func completePostureCheck() {
        record(.postureCheck, .completed)
        clearFullScreen(.postureCheck)
        handle(engine.completePostureCheck(now: clock.now))
        notifications.removeDelivered(.reminders)
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

    /// Turns the global shortcut off while the user records a new one, so
    /// pressing the current combination records it instead of triggering it.
    func setRecordingShortcut(_ isRecording: Bool) {
        if isRecording {
            hotKey.unregister()
        } else {
            registerGlobalShortcut()
        }
    }

    private func registerGlobalShortcut() {
        let status = hotKey.register(globalShortcut) { [weak self] in
            self?.toggleFocus()
        }
        globalShortcutError = switch status {
        case noErr: nil
        case OSStatus(eventHotKeyExistsErr): String(localized: "Another app already uses this shortcut.")
        default: String(localized: "This shortcut can't be used. Try another one.")
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

    func perform(_ action: NotificationAction, kinds: Set<ReminderKind>) {
        switch action {
        case .startBreak, .startFocus: startPomodoro()
        case .skipBreak: skipPomodoroPhase()
        case .extendFocus: extendFocus()
        case .logWater: logWater()
        case .completeReminders:
            if kinds.contains(.posture) {
                confirmPostureSwitch()
            }
            if kinds.contains(.hydration) {
                logWater()
            }
            if kinds.contains(.eyes) {
                completeEyeBreak()
            }
            if kinds.contains(.postureCheck) {
                completePostureCheck()
            }
        case .snoozeReminders:
            snooze(kinds)
        }
    }

    private func snooze(_ kinds: Set<ReminderKind>) {
        let now = clock.now
        var events: [UnchairEvent] = []
        for kind in kinds {
            record(kind, .snoozed)
            clearFullScreen(kind)
            switch kind {
            case .posture: events += engine.snoozePosture(by: Self.snoozeInterval, now: now)
            case .hydration: events += engine.snoozeHydration(by: Self.snoozeInterval, now: now)
            case .eyes: events += engine.snoozeEyeBreak(by: Self.snoozeInterval, now: now)
            case .postureCheck: events += engine.completePostureCheck(now: now)
            }
        }
        handle(events)
    }

    private func handle(_ events: [UnchairEvent]) {
        let now = clock.now
        recordHistory(for: events, at: now)

        let isQuiet = switch engine.holdReason(at: now) {
        case .quietMode, .focusMode, .meeting, .fullscreen: true
        case .away, .outsideWorkingHours, nil: false
        }
        var extras = NotificationExtras(
            water: (engine.hydration.intake(at: now), engine.settings.hydration.dailyGoal),
            stretch: currentStretch,
            mentionsEyes: settings.eyes.isEnabled && settings.eyes.mergeWithPomodoro
        )
        if events.contains(.dayEnded) {
            extras.summary = todaySummary()
        }
        // Full screen never interrupts calls, presentations, or quiet time.
        let fullScreenKinds = isQuiet ? [] : events.compactMap(ReminderKind.init)
            .filter { settings.alerts.style(for: $0) == .fullScreen }
        let notified = events.filter { event in
            ReminderKind(event).map { !fullScreenKinds.contains($0) } ?? true
        }
        notifications.post(notified, extras: extras, quietly: isQuiet)
        presentFullScreen(fullScreenKinds, postureTarget: postureTarget(in: events))
        stateDidChange()
    }

    private func recordHistory(for events: [UnchairEvent], at now: Date) {
        for event in events {
            switch event {
            case .pomodoro(.phaseCompleted(.focus, _, _)):
                let duration = engine.pomodoro.lastCompletedPhaseDuration ?? settings.pomodoro.focusDuration
                history.recordFocusSession(FocusSession(end: now, duration: duration))
            case .pomodoro, .dayEnded:
                break
            case .posture: record(.posture, .delivered)
            case .hydration: record(.hydration, .delivered)
            case .eyeBreak: record(.eyes, .delivered)
            case .postureCheck: record(.postureCheck, .delivered)
            }
        }
    }

    private func record(_ kind: ReminderKind, _ outcome: ReminderOutcome) {
        history.recordReminder(kind, outcome, at: clock.now)
    }

    private func recordPresence(_ state: PresenceState?) {
        guard let state, state != lastPresence else { return }
        lastPresence = state
        history.recordPresence(state, at: clock.now)
    }

    private var currentPresence: PresenceState? {
        if engine.awaySince != nil {
            return .away
        }
        guard engine.posture.state != .stopped else { return nil }
        return engine.posture.posture == .standing ? .standing : .sitting
    }

    private func stateDidChange() {
        now = clock.now
        store.hydrationLog = engine.hydration.log
        store.quietUntil = engine.quietUntil
        recordPresence(currentPresence)
        updateOverlay()
        widgets.publish(WidgetSnapshot(engine: engine, today: todayStats(), now: now))
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
