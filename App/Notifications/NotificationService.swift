import Foundation
import UnchairCore
import UserNotifications

/// Actions offered on notifications.
enum NotificationAction: String, CaseIterable {
    case startBreak
    case skipBreak
    case extendFocus
    case startFocus
    /// Marks every reminder in the notification as done.
    case completeReminders
    /// Snoozes every reminder in the notification.
    case snoozeReminders
    /// Logs a glass of water (only offered when water is the sole reminder).
    case logWater
}

/// Each kind uses a fixed request identifier, so a new notification replaces
/// the previous one of the same kind instead of piling up.
enum NotificationKind: String {
    case pomodoro
    case reminders
    case summary
    /// A sample shown from Settings. Its actions do nothing.
    case preview
}

/// Extra information for notification text that the engine events don't carry.
struct NotificationExtras {
    var water: (intake: Int, goal: Int) = (0, 0)
    /// Stretch to suggest in break notifications.
    var stretch: Stretch?
    /// Mention resting the eyes in break notifications.
    var mentionsEyes = false
    /// Body of the end-of-day summary.
    var summary: String?
}

/// Wraps `UNUserNotificationCenter`: registers categories, posts notifications
/// for engine events, and forwards the user's chosen action.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    /// Called with the chosen action and the reminders the notification covered.
    var onAction: ((NotificationAction, Set<ReminderKind>) -> Void)?
    var sound: NotificationSoundOption = .chime

    private let center = UNUserNotificationCenter.current()
    private nonisolated static let kindsKey = "reminderKinds"
    private nonisolated static let previewKey = "isPreview"

    private enum Category {
        static let focusEndedAwaiting = "focus-ended.awaiting"
        static let focusEndedAutoStarted = "focus-ended.auto-started"
        static let breakEndedAwaiting = "break-ended.awaiting"
        static let breakEndedAutoStarted = "break-ended.auto-started"
        static let reminders = "reminders"
        static let water = "water"
        static let gentle = "gentle"
        static let summary = "summary"
    }

    /// Sets the delegate and registers categories.
    func activate() {
        center.delegate = self
        center.setNotificationCategories(makeCategories())
    }

    /// Asks for permission. Shows the system prompt only the first time.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Log.signals.info("Notification permission granted: \(granted, privacy: .public)")
            return granted
        } catch {
            Log.signals.error("Notification permission request failed: \(error, privacy: .public)")
            return false
        }
    }

    /// Posts notifications for `events`. All wellbeing reminders that arrive
    /// together become a single notification.
    ///
    /// - Parameter quietly: Deliver without sound or banner, for example while
    ///   the user is in a meeting.
    func post(_ events: [UnchairEvent], extras: NotificationExtras, quietly: Bool = false) {
        var reminders: [ReminderKind] = []
        var postureTarget: Posture?

        for event in events {
            switch event {
            case let .pomodoro(.phaseCompleted(phase, next, autoStarted)):
                let content = makeContent(quietly: quietly)
                fill(content, phase: phase, next: next, autoStarted: autoStarted, extras: extras)
                add(content, kind: .pomodoro)
            case let .posture(.switchSuggested(posture)):
                postureTarget = posture
                reminders.append(.posture)
            case .hydration:
                reminders.append(.hydration)
            case .eyeBreak:
                reminders.append(.eyes)
            case .postureCheck:
                reminders.append(.postureCheck)
            case .dayEnded:
                guard let summary = extras.summary else { continue }
                let content = makeContent(quietly: true)
                content.categoryIdentifier = Category.summary
                content.title = String(localized: "Your day with Unchair")
                content.body = summary
                add(content, kind: .summary)
            }
        }

        guard !reminders.isEmpty else { return }
        // A lone posture check is gentle: no sound.
        let content = makeContent(quietly: quietly || reminders == [.postureCheck])
        content.userInfo = [Self.kindsKey: reminders.map(\.rawValue)]
        fillReminders(content, kinds: reminders, postureTarget: postureTarget, extras: extras)
        add(content, kind: .reminders)
    }

    /// Moves a full-screen reminder to Notification Center without interrupting.
    func postQuietly(_ alert: FullScreenReminder) {
        let content = makeContent(quietly: true)
        content.userInfo = [Self.kindsKey: alert.kinds.map(\.rawValue)]
        content.categoryIdentifier = category(for: alert.kinds)
        content.title = alert.message.title
        content.body = alert.message.body
        add(content, kind: .reminders)
    }

    /// Posts a sample reminder notification, as the real one would look.
    func postPreview(of kind: ReminderKind, postureTarget: Posture?, extras: NotificationExtras) {
        let content = makeContent(quietly: kind == .postureCheck)
        fillReminders(content, kinds: [kind], postureTarget: postureTarget, extras: extras)
        content.userInfo = [Self.previewKey: true]
        add(content, kind: .preview)
    }

    /// Posts a sample end-of-focus notification.
    func postBreakPreview(extras: NotificationExtras) {
        let content = makeContent(quietly: false)
        fill(content, phase: .focus, next: .shortBreak, autoStarted: false, extras: extras)
        content.userInfo = [Self.previewKey: true]
        add(content, kind: .preview)
    }

    func removeDelivered(_ kinds: NotificationKind...) {
        center.removeDeliveredNotifications(withIdentifiers: kinds.map(\.rawValue))
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let content = notification.request.content
        if content.interruptionLevel == .passive {
            return [.list]
        }
        return content.sound == nil ? [.banner, .list] : [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let action = NotificationAction(rawValue: response.actionIdentifier),
              userInfo[Self.previewKey] as? Bool != true
        else { return }
        let rawKinds = response.notification.request.content.userInfo[Self.kindsKey] as? [String] ?? []
        let kinds = Set(rawKinds.compactMap(ReminderKind.init))
        await MainActor.run {
            onAction?(action, kinds)
        }
    }

    // MARK: - Content

    private func makeContent(quietly: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if quietly {
            content.interruptionLevel = .passive
        } else {
            content.sound = sound.notificationSound
        }
        return content
    }

    private func add(_ content: UNNotificationContent, kind: NotificationKind) {
        center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: nil))
    }

    private func category(for kinds: [ReminderKind]) -> String {
        kinds == [.hydration] ? Category.water
            : kinds == [.postureCheck] ? Category.gentle
            : Category.reminders
    }

    private func fillReminders(
        _ content: UNMutableNotificationContent,
        kinds: [ReminderKind],
        postureTarget: Posture?,
        extras: NotificationExtras
    ) {
        content.categoryIdentifier = category(for: kinds)
        let message = ReminderMessage(kinds: kinds, postureTarget: postureTarget, water: extras.water)
        content.title = message.title
        content.body = message.body
    }

    private func fill(
        _ content: UNMutableNotificationContent,
        phase: PomodoroPhase,
        next: PomodoroPhase,
        autoStarted: Bool,
        extras: NotificationExtras
    ) {
        if phase == .focus {
            content.title = String(localized: "Focus session complete")
            content.categoryIdentifier = autoStarted ? Category.focusEndedAutoStarted : Category.focusEndedAwaiting
            var sentences: [String] = switch (next, autoStarted) {
            case (.longBreak, true): [String(localized: "Your long break has started. You've earned it.")]
            case (.longBreak, false): [String(localized: "Time for a long break. You've earned it.")]
            case (_, true): [String(localized: "Your short break has started.")]
            case (_, false): [String(localized: "Time for a short break.")]
            }
            if let stretch = extras.stretch {
                sentences.append(String(localized: "Try this: \(stretch.title)."))
            }
            if extras.mentionsEyes {
                sentences.append(String(localized: "Rest your eyes on something far away."))
            }
            content.body = sentences.joined(separator: " ")
        } else {
            content.title = String(localized: "Break's over")
            content.categoryIdentifier = autoStarted ? Category.breakEndedAutoStarted : Category.breakEndedAwaiting
            content.body = autoStarted
                ? String(localized: "A new focus session has started.")
                : String(localized: "Ready to focus again?")
        }
    }

    private func makeCategories() -> Set<UNNotificationCategory> {
        func action(_ action: NotificationAction, _ title: String) -> UNNotificationAction {
            UNNotificationAction(identifier: action.rawValue, title: title)
        }

        func category(_ identifier: String, _ actions: [UNNotificationAction]) -> UNNotificationCategory {
            UNNotificationCategory(identifier: identifier, actions: actions, intentIdentifiers: [])
        }

        let done = action(.completeReminders, String(localized: "Done"))
        let snooze = action(.snoozeReminders, String(localized: "Snooze 10 Minutes"))
        let skipBreak = action(.skipBreak, String(localized: "Skip Break"))
        let extendFocus = action(.extendFocus, String(localized: "5 More Minutes"))

        return [
            category(Category.focusEndedAwaiting, [
                action(.startBreak, String(localized: "Start Break")), skipBreak, extendFocus,
            ]),
            category(Category.focusEndedAutoStarted, [skipBreak, extendFocus]),
            category(Category.breakEndedAwaiting, [action(.startFocus, String(localized: "Start Focus"))]),
            category(Category.breakEndedAutoStarted, []),
            category(Category.reminders, [done, snooze]),
            category(Category.water, [action(.logWater, String(localized: "I Drank a Glass")), snooze]),
            category(Category.gentle, [done]),
            category(Category.summary, []),
        ]
    }
}
