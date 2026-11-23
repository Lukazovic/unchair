import Foundation

public enum UnchairEvent: Equatable, Sendable {
    case pomodoro(PomodoroEvent)
    case posture(PostureEvent)
    case hydration(HydrationEvent)
    /// Time for a 20-20-20 eye break.
    case eyeBreak
    /// A gentle reminder to check posture.
    case postureCheck
    /// The workday ended: time for the daily summary.
    case dayEnded
}

/// Coordinates the Pomodoro timer and the posture and hydration reminders,
/// and decides when reminders should be held.
///
/// The app owns one engine, calls ``tick(now:)`` when ``nextDeadline(after:)``
/// is reached, and turns the returned events into notifications. Every action
/// also returns events, because it can release a held reminder (for example,
/// a meeting ending or a focus session being paused).
///
/// Holding only affects wellbeing reminders (posture, water, eyes, posture
/// check). The Pomodoro timer
/// keeps running because the user started it, except that a focus session is
/// paused while the user is away.
public struct UnchairEngine: Equatable, Sendable {
    public private(set) var settings: UnchairSettings
    public private(set) var pomodoro: PomodoroTimer
    public private(set) var posture: PostureReminder
    public private(set) var hydration: HydrationTracker
    public private(set) var eyes: IntervalReminder
    public private(set) var postureCheck: IntervalReminder
    /// When the next end-of-day summary is due.
    public private(set) var nextSummaryAt: Date?
    public private(set) var context = ReminderContext()
    /// Reminders are paused by the user until this date.
    public private(set) var quietUntil: Date?
    /// When the user went away, or `nil` while they are present.
    public private(set) var awaySince: Date?

    private let calendar: Calendar
    private var pomodoroPausedForAway = false
    private var wasWithinWorkingHours: Bool

    public init(
        settings: UnchairSettings = UnchairSettings(),
        hydrationLog: HydrationLog? = nil,
        quietUntil: Date? = nil,
        calendar: Calendar = .current,
        now: Date
    ) {
        self.settings = settings
        self.calendar = calendar
        self.quietUntil = quietUntil.flatMap { $0 > now ? $0 : nil }
        pomodoro = PomodoroTimer(settings: settings.pomodoro)
        posture = PostureReminder(settings: settings.posture)
        hydration = HydrationTracker(settings: settings.hydration, log: hydrationLog, calendar: calendar, now: now)
        eyes = IntervalReminder(interval: settings.eyes.interval)
        postureCheck = IntervalReminder(interval: settings.postureCheck.interval)
        wasWithinWorkingHours = settings.interruptions.workingHours.contains(now, calendar: calendar)

        if settings.posture.isEnabled {
            posture.start(now: now)
        }
        if settings.hydration.isEnabled {
            hydration.start(now: now)
        }
        if settings.eyes.isEnabled {
            eyes.start(now: now)
        }
        if settings.postureCheck.isEnabled {
            postureCheck.start(now: now)
        }
        nextSummaryAt = nextSummary(after: now)
    }

    /// A summary that fires more than this late (for example, because the Mac
    /// was asleep) is skipped.
    static let summaryGracePeriod: TimeInterval = 3 * 60 * 60

    // MARK: - Queries

    /// Whether a focus session is running right now.
    public var isFocusing: Bool {
        pomodoro.isRunning && pomodoro.phase == .focus
    }

    /// While a Pomodoro session is active and eye breaks are merged into it,
    /// separate eye reminders are skipped.
    public var eyesMergedIntoPomodoro: Bool {
        settings.eyes.mergeWithPomodoro && pomodoro.state != .idle
    }

    /// Why reminders are held at `now`, or `nil` if they can be delivered.
    /// When several reasons apply, the one listed first wins.
    public func holdReason(at now: Date) -> HoldReason? {
        let interruptions = settings.interruptions
        if let quietUntil, now < quietUntil {
            return .quietMode(until: quietUntil)
        }
        if awaySince != nil {
            return .away
        }
        if !interruptions.workingHours.contains(now, calendar: calendar) {
            return .outsideWorkingHours
        }
        if context.focusFilterHoldsReminders {
            return .focusMode
        }
        if interruptions.holdDuringMeetings, context.isInMeeting {
            return .meeting
        }
        if interruptions.holdDuringFullscreen, context.isFullscreen {
            return .fullscreen
        }
        return nil
    }

    /// The earliest moment after `now` when ``tick(now:)`` should run, or `nil`
    /// if nothing is scheduled. Held reminders are left out: the app reports
    /// context changes through actions, which release them.
    public func nextDeadline(after now: Date) -> Date? {
        var candidates: [Date?] = [pomodoro.nextDeadline, nextSummaryAt]
        if holdReason(at: now) == nil {
            candidates += [posture.nextDeadline, hydration.nextReminderAt, postureCheck.nextReminderAt]
            if !eyesMergedIntoPomodoro {
                candidates.append(eyes.nextReminderAt)
            }
        }
        if let quietUntil, quietUntil > now {
            candidates.append(quietUntil)
        }
        candidates.append(settings.interruptions.workingHours.nextTransition(after: now, calendar: calendar))
        return candidates.compactMap(\.self).min()
    }

    // MARK: - Ticking

    /// Processes everything that is due at `now`.
    public mutating func tick(now: Date) -> [UnchairEvent] {
        var events: [UnchairEvent] = []
        if let event = pomodoro.tick(now: now) {
            events.append(.pomodoro(event))
        }
        pauseFocusIfAway(now: now)
        if let nextSummaryAt, now >= nextSummaryAt {
            if now.timeIntervalSince(nextSummaryAt) <= Self.summaryGracePeriod {
                events.append(.dayEnded)
            }
            self.nextSummaryAt = nextSummary(after: now)
        }
        return events + tickReminders(now: now)
    }

    // MARK: - Settings and context

    /// Applies new settings, starting, stopping, or rescheduling reminders as needed.
    public mutating func apply(_ newSettings: UnchairSettings, now: Date) -> [UnchairEvent] {
        let old = settings
        settings = newSettings

        pomodoro.settings = newSettings.pomodoro

        applyPostureAndHydration(old: old, new: newSettings, now: now)

        eyes.interval = newSettings.eyes.interval
        Self.update(
            &eyes,
            enabled: (old.eyes.isEnabled, newSettings.eyes.isEnabled),
            intervalChanged: old.eyes.interval != newSettings.eyes.interval,
            now: now
        )
        postureCheck.interval = newSettings.postureCheck.interval
        Self.update(
            &postureCheck,
            enabled: (old.postureCheck.isEnabled, newSettings.postureCheck.isEnabled),
            intervalChanged: old.postureCheck.interval != newSettings.postureCheck.interval,
            now: now
        )

        if old.summary != newSettings.summary || old.interruptions.workingHours != newSettings.interruptions
            .workingHours
        {
            nextSummaryAt = nextSummary(after: now)
        }

        return tickReminders(now: now)
    }

    /// Updates what the system reports about the user's situation.
    public mutating func update(_ newContext: ReminderContext, now: Date) -> [UnchairEvent] {
        context = newContext
        return tickReminders(now: now)
    }

    /// Pauses reminders until `date`, or resumes them when `date` is `nil`.
    public mutating func pauseReminders(until date: Date?, now: Date) -> [UnchairEvent] {
        quietUntil = date.flatMap { $0 > now ? $0 : nil }
        return tickReminders(now: now)
    }

    // MARK: - Presence

    /// Records that the user has been away since `since` (for example, idle,
    /// asleep, or locked). Pauses focus at `since` so the absence doesn't
    /// count against it.
    public mutating func userBecameAway(since: Date, now: Date) -> [UnchairEvent] {
        guard awaySince == nil else { return [] }
        awaySince = min(since, now)
        pauseFocusIfAway(now: awaySince ?? now)
        return tickReminders(now: now)
    }

    /// Records that the user is back.
    ///
    /// The absence is treated as a natural break: the sitting countdown starts
    /// over, a focus session paused for longer than a short break is discarded,
    /// and the water interval restarts if the absence was longer than it.
    public mutating func userReturned(now: Date) -> [UnchairEvent] {
        guard let awaySince else { return [] }
        self.awaySince = nil
        let absence = now.timeIntervalSince(awaySince)

        if pomodoroPausedForAway {
            pomodoroPausedForAway = false
            if case .paused(.focus, _, _) = pomodoro.state {
                if absence >= pomodoro.settings.shortBreakDuration {
                    pomodoro.discardFocus()
                } else {
                    pomodoro.resume(now: now)
                }
            }
        }

        if absence >= settings.interruptions.awayThreshold {
            if posture.state != .stopped {
                posture.start(now: now)
            }
            eyes.acknowledge(now: now)
            postureCheck.acknowledge(now: now)
        }
        if absence >= hydration.settings.reminderInterval, hydration.nextReminderAt != nil {
            hydration.start(now: now)
        }
        return tickReminders(now: now)
    }

    // MARK: - Private

    private mutating func applyPostureAndHydration(old: UnchairSettings, new newSettings: UnchairSettings, now: Date) {
        posture.settings = newSettings.posture
        switch (old.posture.isEnabled, newSettings.posture.isEnabled) {
        case (false, true):
            posture.start(now: now)
        case (true, false):
            posture.stop()
        case (true, true):
            let current = posture.posture
            if old.posture.duration(for: current) != newSettings.posture.duration(for: current),
               posture.nextDeadline != nil
            {
                posture.restartCountdown(now: now)
            }
        case (false, false):
            break
        }

        hydration.settings = newSettings.hydration
        switch (old.hydration.isEnabled, newSettings.hydration.isEnabled) {
        case (false, true):
            hydration.start(now: now)
        case (true, false):
            hydration.stop()
        case (true, true):
            if old.hydration.reminderInterval != newSettings.hydration.reminderInterval {
                hydration.start(now: now)
            }
        case (false, false):
            break
        }
    }

    private static func update(
        _ reminder: inout IntervalReminder,
        enabled: (old: Bool, new: Bool),
        intervalChanged: Bool,
        now: Date
    ) {
        switch enabled {
        case (false, true): reminder.start(now: now)
        case (true, false): reminder.stop()
        case (true, true) where intervalChanged: reminder.start(now: now)
        default: break
        }
    }

    /// The next end-of-day summary after `now`: the end of working hours on a
    /// working day when they're on, otherwise the configured time every day.
    private func nextSummary(after now: Date) -> Date? {
        guard settings.summary.isEnabled else { return nil }
        let workingHours = settings.interruptions.workingHours
        let minutes = workingHours.isEnabled ? workingHours.end : settings.summary.time
        var day = calendar.startOfDay(for: now)
        for _ in 0 ..< 8 {
            if let candidate = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
               candidate > now,
               !workingHours.isEnabled || workingHours.weekdays.contains(calendar.component(
                   .weekday,
                   from: candidate
               ))
            {
                return candidate
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = nextDay
        }
        return nil
    }

    private mutating func tickEyes(now: Date, dueBy: Date? = nil) -> Bool {
        guard !eyesMergedIntoPomodoro else { return false }
        return eyes.tick(now: now, dueBy: dueBy)
    }

    private mutating func pauseFocusIfAway(now: Date) {
        guard awaySince != nil, settings.interruptions.pauseFocusWhenAway, isFocusing else { return }
        pomodoro.pause(now: now)
        pomodoroPausedForAway = true
    }

    private mutating func tickReminders(now: Date) -> [UnchairEvent] {
        if let quietUntil, now >= quietUntil {
            self.quietUntil = nil
        }
        restartRemindersIfWorkdayStarted(now: now)

        guard holdReason(at: now) == nil else { return [] }

        var postureEvent = posture.tick(now: now, isFocusing: isFocusing)
        var hydrationEvent = hydration.tick(now: now)
        var eyesFired = tickEyes(now: now)
        var checkFired = postureCheck.tick(now: now)

        // Coalescing: when one reminder fires, bring forward any other that is
        // due soon, so the user is interrupted once instead of several times.
        if postureEvent != nil || hydrationEvent != nil || eyesFired || checkFired {
            let dueBy = now.addingTimeInterval(settings.interruptions.coalescingWindow)
            if postureEvent == nil {
                postureEvent = posture.tick(now: now, isFocusing: isFocusing, dueBy: dueBy)
            }
            if hydrationEvent == nil {
                hydrationEvent = hydration.tick(now: now, dueBy: dueBy)
            }
            if !eyesFired {
                eyesFired = tickEyes(now: now, dueBy: dueBy)
            }
            if !checkFired {
                checkFired = postureCheck.tick(now: now, dueBy: dueBy)
            }
        }
        // A posture switch already makes the user think about posture.
        if postureEvent != nil {
            checkFired = false
        }

        var events: [UnchairEvent] = [
            postureEvent.map(UnchairEvent.posture),
            hydrationEvent.map(UnchairEvent.hydration),
        ]
        .compactMap(\.self)
        if eyesFired {
            events.append(.eyeBreak)
        }
        if checkFired {
            events.append(.postureCheck)
        }
        return events
    }

    /// Reminders overdue from outside working hours start fresh instead of
    /// all firing the moment the workday begins.
    private mutating func restartRemindersIfWorkdayStarted(now: Date) {
        let isWithin = settings.interruptions.workingHours.contains(now, calendar: calendar)
        defer { wasWithinWorkingHours = isWithin }
        guard isWithin, !wasWithinWorkingHours else { return }
        if posture.state != .stopped {
            posture.start(now: now)
        }
        if hydration.nextReminderAt != nil {
            hydration.start(now: now)
        }
        eyes.acknowledge(now: now)
        postureCheck.acknowledge(now: now)
    }
}

// MARK: - Actions

public extension UnchairEngine {
    // MARK: - Pomodoro

    mutating func startPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.start(now: now)
        return tickReminders(now: now)
    }

    mutating func pausePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.pause(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    mutating func resumePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.resume(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    mutating func skipPomodoroPhase(now: Date) -> [UnchairEvent] {
        pomodoro.skip(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    mutating func extendFocus(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        pomodoro.extendFocus(by: interval, now: now)
        return tickReminders(now: now)
    }

    mutating func resetPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.reset()
        pomodoroPausedForAway = false
        // Eye breaks were folded into the Pomodoro; start their own interval again.
        eyes.acknowledge(now: now)
        return tickReminders(now: now)
    }

    // MARK: - Posture

    mutating func confirmPostureSwitch(now: Date) -> [UnchairEvent] {
        posture.confirmSwitch(now: now)
        return tickReminders(now: now)
    }

    mutating func snoozePosture(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        posture.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }

    // MARK: - Hydration

    mutating func logWater(now: Date) -> [UnchairEvent] {
        hydration.logGlass(now: now)
        return tickReminders(now: now)
    }

    mutating func removeWater(now: Date) -> [UnchairEvent] {
        hydration.removeGlass(now: now)
        return tickReminders(now: now)
    }

    mutating func snoozeHydration(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        hydration.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }

    // MARK: - Eyes and posture check

    mutating func completeEyeBreak(now: Date) -> [UnchairEvent] {
        eyes.acknowledge(now: now)
        return tickReminders(now: now)
    }

    mutating func snoozeEyeBreak(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        eyes.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }

    mutating func completePostureCheck(now: Date) -> [UnchairEvent] {
        postureCheck.acknowledge(now: now)
        return tickReminders(now: now)
    }

    mutating func snoozePostureCheck(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        postureCheck.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }
}
