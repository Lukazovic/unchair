import Foundation

public enum UnchairEvent: Equatable, Sendable {
    case pomodoro(PomodoroEvent)
    case posture(PostureEvent)
    case hydration(HydrationEvent)
}

/// Coordinates the Pomodoro timer and the posture and hydration reminders.
///
/// The app owns one engine, calls ``tick(now:)`` when ``nextDeadline`` is
/// reached, and turns the returned events into notifications. Every action
/// also returns events, because it can make a held reminder due (for example,
/// a posture switch held until a focus session ends).
public struct UnchairEngine: Equatable, Sendable {
    public private(set) var settings: UnchairSettings
    public private(set) var pomodoro: PomodoroTimer
    public private(set) var posture: PostureReminder
    public private(set) var hydration: HydrationTracker

    public init(
        settings: UnchairSettings = UnchairSettings(),
        hydrationLog: HydrationLog? = nil,
        calendar: Calendar = .current,
        now: Date
    ) {
        self.settings = settings
        pomodoro = PomodoroTimer(settings: settings.pomodoro)
        posture = PostureReminder(settings: settings.posture)
        hydration = HydrationTracker(settings: settings.hydration, log: hydrationLog, calendar: calendar, now: now)

        if settings.posture.isEnabled {
            posture.start(now: now)
        }
        if settings.hydration.isEnabled {
            hydration.start(now: now)
        }
    }

    /// The earliest moment something needs to happen, or `nil` if nothing is scheduled.
    public var nextDeadline: Date? {
        [pomodoro.nextDeadline, posture.nextDeadline, hydration.nextReminderAt]
            .compactMap(\.self)
            .min()
    }

    /// Whether a focus session is running right now.
    public var isFocusing: Bool {
        pomodoro.isRunning && pomodoro.phase == .focus
    }

    /// Processes everything that is due at `now`.
    public mutating func tick(now: Date) -> [UnchairEvent] {
        var events: [UnchairEvent] = []
        if let event = pomodoro.tick(now: now) {
            events.append(.pomodoro(event))
        }
        return events + tickReminders(now: now)
    }

    // MARK: - Settings

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

    // MARK: - Pomodoro

    public mutating func startPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.start(now: now)
        return tickReminders(now: now)
    }

    public mutating func pausePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.pause(now: now)
        return tickReminders(now: now)
    }

    public mutating func resumePomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.resume(now: now)
        return tickReminders(now: now)
    }

    public mutating func skipPomodoroPhase(now: Date) -> [UnchairEvent] {
        pomodoro.skip(now: now)
        return tickReminders(now: now)
    }

    public mutating func extendFocus(by interval: TimeInterval, now: Date) -> [UnchairEvent] {
        pomodoro.extendFocus(by: interval, now: now)
        return tickReminders(now: now)
    }

    public mutating func resetPomodoro(now: Date) -> [UnchairEvent] {
        pomodoro.reset()
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

    private mutating func tickReminders(now: Date) -> [UnchairEvent] {
        var events: [UnchairEvent] = []
        if let event = posture.tick(now: now, isFocusing: isFocusing) {
            events.append(.posture(event))
        }
        if let event = hydration.tick(now: now) {
            events.append(.hydration(event))
        }
        return events
    }
}
