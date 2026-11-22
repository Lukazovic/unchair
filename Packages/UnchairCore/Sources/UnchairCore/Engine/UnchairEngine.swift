import Foundation

public enum UnchairEvent: Equatable, Sendable {
    case pomodoro(PomodoroEvent)
    case posture(PostureEvent)
    case hydration(HydrationEvent)
}

/// Coordinates the Pomodoro timer and the posture and hydration reminders,
/// and decides when reminders should be held.
///
/// The app owns one engine, calls ``tick(now:)`` when ``nextDeadline(after:)``
/// is reached, and turns the returned events into notifications. Every action
/// also returns events, because it can release a held reminder (for example,
/// a meeting ending or a focus session being paused).
///
/// Holding only affects posture and hydration reminders. The Pomodoro timer
/// keeps running because the user started it, except that a focus session is
/// paused while the user is away.
public struct UnchairEngine: Equatable, Sendable {
    public private(set) var settings: UnchairSettings
    public private(set) var pomodoro: PomodoroTimer
    public private(set) var posture: PostureReminder
    public private(set) var hydration: HydrationTracker
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
        wasWithinWorkingHours = settings.interruptions.workingHours.contains(now, calendar: calendar)

        if settings.posture.isEnabled {
            posture.start(now: now)
        }
        if settings.hydration.isEnabled {
            hydration.start(now: now)
        }
    }

    // MARK: - Queries

    /// Whether a focus session is running right now.
    public var isFocusing: Bool {
        pomodoro.isRunning && pomodoro.phase == .focus
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
        var candidates: [Date?] = [pomodoro.nextDeadline]
        if holdReason(at: now) == nil {
            candidates += [posture.nextDeadline, hydration.nextReminderAt]
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
        return events + tickReminders(now: now)
    }

    // MARK: - Settings and context

    /// Applies new settings, starting, stopping, or rescheduling reminders as needed.
    public mutating func apply(_ newSettings: UnchairSettings, now: Date) -> [UnchairEvent] {
        let old = settings
        settings = newSettings

        pomodoro.settings = newSettings.pomodoro

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

        if absence >= settings.interruptions.awayThreshold, posture.state != .stopped {
            posture.start(now: now)
        }
        if absence >= hydration.settings.reminderInterval, hydration.nextReminderAt != nil {
            hydration.start(now: now)
        }
        return tickReminders(now: now)
    }

    // MARK: - Pomodoro

    public mutating func startPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.start(now: now)
        return tickReminders(now: now)
    }

    public mutating func pausePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.pause(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    public mutating func resumePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.resume(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    public mutating func skipPomodoroPhase(now: Date) -> [UnchairEvent] {
        pomodoro.skip(now: now)
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    public mutating func extendFocus(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        pomodoro.extendFocus(by: interval, now: now)
        return tickReminders(now: now)
    }

    public mutating func resetPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.reset()
        pomodoroPausedForAway = false
        return tickReminders(now: now)
    }

    // MARK: - Posture

    public mutating func confirmPostureSwitch(now: Date) -> [UnchairEvent] {
        posture.confirmSwitch(now: now)
        return tickReminders(now: now)
    }

    public mutating func snoozePosture(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        posture.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }

    // MARK: - Hydration

    public mutating func logWater(now: Date) -> [UnchairEvent] {
        hydration.logGlass(now: now)
        return tickReminders(now: now)
    }

    public mutating func removeWater(now: Date) -> [UnchairEvent] {
        hydration.removeGlass(now: now)
        return tickReminders(now: now)
    }

    public mutating func snoozeHydration(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        hydration.snooze(by: interval, now: now)
        return tickReminders(now: now)
    }

    // MARK: - Private

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

        // Coalescing: when one reminder fires, bring forward any other that is
        // due soon, so the user is interrupted once instead of twice.
        if postureEvent != nil || hydrationEvent != nil {
            let dueBy = now.addingTimeInterval(settings.interruptions.coalescingWindow)
            if postureEvent == nil {
                postureEvent = posture.tick(now: now, isFocusing: isFocusing, dueBy: dueBy)
            }
            if hydrationEvent == nil {
                hydrationEvent = hydration.tick(now: now, dueBy: dueBy)
            }
        }

        return [postureEvent.map(UnchairEvent.posture), hydrationEvent.map(UnchairEvent.hydration)]
            .compactMap(\.self)
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
    }
}
