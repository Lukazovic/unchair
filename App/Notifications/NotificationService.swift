import Foundation
import UnchairCore
import UserNotifications

/// Actions offered on notifications.
enum NotificationAction: String, CaseIterable {
    case startBreak
    case skipBreak
    case extendFocus
    case startFocus
    case confirmPosture
    case snoozePosture
    case logWater
    case snoozeWater
    /// Confirms the posture switch and logs a glass of water.
    case completeReminders
    /// Snoozes both the posture and water reminders.
    case snoozeReminders
}

/// Each kind uses a fixed request identifier, so a new notification replaces
/// the previous one of the same kind instead of piling up.
enum NotificationKind: String {
    case pomodoro
    case posture
    case hydration
    /// Posture and water reminders delivered together.
    case reminders
}

/// Wraps `UNUserNotificationCenter`: registers categories, posts notifications
/// for engine events, and forwards the user's chosen action.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var onAction: ((NotificationAction) -> Void)?

    private let center = UNUserNotificationCenter.current()

    private enum Category {
        static let focusEndedAwaiting = "focus-ended.awaiting"
        static let focusEndedAutoStarted = "focus-ended.auto-started"
        static let breakEndedAwaiting = "break-ended.awaiting"
        static let breakEndedAutoStarted = "break-ended.auto-started"
        static let posture = "posture"
        static let hydration = "hydration"
        static let reminders = "reminders"
    }

    /// Sets the delegate, registers categories, and asks for permission.
    func activate() {
        center.delegate = self
        center.setNotificationCategories(makeCategories())
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    /// Posts notifications for `events`. Posture and water reminders that
    /// arrive together become a single notification.
    ///
    /// - Parameter quietly: Deliver without sound or banner, for example while
    ///   the user is in a meeting. Only Pomodoro events are posted while
    ///   reminders are held, so this mostly affects them.
    func post(_ events: [UnchairEvent], quietly: Bool = false) {
        var postureTarget: Posture?
        var water: (intake: Int, goal: Int)?

        for event in events {
            switch event {
            case let .pomodoro(.phaseCompleted(phase, next, autoStarted)):
                let content = makeContent(quietly: quietly)
                fill(content, phase: phase, next: next, autoStarted: autoStarted)
                add(content, kind: .pomodoro)
            case let .posture(.switchSuggested(posture)):
                postureTarget = posture
            case let .hydration(.reminder(intake, goal)):
                water = (intake, goal)
            }
        }

        switch (postureTarget, water) {
        case let (posture?, water?):
            let content = makeContent(quietly: quietly)
            content.categoryIdentifier = Category.reminders
            content.title = posture == .standing
                ? String(localized: "Time to stand up and drink water")
                : String(localized: "Time to sit down and drink water")
            content.body = waterProgress(water)
            add(content, kind: .reminders)
        case let (posture?, nil):
            let content = makeContent(quietly: quietly)
            content.categoryIdentifier = Category.posture
            switch posture {
            case .standing:
                content.title = String(localized: "Time to stand up")
                content.body = String(localized: "Raise your desk and work standing for a while.")
            case .sitting:
                content.title = String(localized: "Time to sit down")
                content.body = String(localized: "Nice work. Take a seat and keep going.")
            }
            add(content, kind: .posture)
        case let (nil, water?):
            let content = makeContent(quietly: quietly)
            content.categoryIdentifier = Category.hydration
            content.title = String(localized: "Time to drink water")
            content.body = waterProgress(water)
            add(content, kind: .hydration)
        case (nil, nil):
            break
        }
    }

    func removeDelivered(_ kinds: NotificationKind...) {
        center.removeDeliveredNotifications(withIdentifiers: kinds.map(\.rawValue))
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.content.interruptionLevel == .passive ? [.list] : [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let action = NotificationAction(rawValue: response.actionIdentifier) else { return }
        await MainActor.run {
            onAction?(action)
        }
    }

    // MARK: - Private

    private func makeContent(quietly: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if quietly {
            content.interruptionLevel = .passive
        } else {
            content.sound = .default
        }
        return content
    }

    private func add(_ content: UNNotificationContent, kind: NotificationKind) {
        center.add(UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: nil))
    }

    private func waterProgress(_ water: (intake: Int, goal: Int)) -> String {
        String(localized: "\(Format.volume(water.intake)) of \(Format.volume(water.goal)) today.")
    }

    private func fill(
        _ content: UNMutableNotificationContent,
        phase: PomodoroPhase,
        next: PomodoroPhase,
        autoStarted: Bool
    ) {
        if phase == .focus {
            content.title = String(localized: "Focus session complete")
            content.categoryIdentifier = autoStarted ? Category.focusEndedAutoStarted : Category.focusEndedAwaiting
            switch (next, autoStarted) {
            case (.longBreak, true): content.body = String(localized: "Your long break has started. You've earned it.")
            case (.longBreak, false): content.body = String(localized: "Time for a long break. You've earned it.")
            case (_, true): content.body = String(localized: "Your short break has started.")
            case (_, false): content.body = String(localized: "Time for a short break.")
            }
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

        let snoozeTitle = String(localized: "Snooze 10 Minutes")
        let startBreak = action(.startBreak, String(localized: "Start Break"))
        let skipBreak = action(.skipBreak, String(localized: "Skip Break"))
        let extendFocus = action(.extendFocus, String(localized: "5 More Minutes"))
        let startFocus = action(.startFocus, String(localized: "Start Focus"))

        return [
            category(Category.focusEndedAwaiting, [startBreak, skipBreak, extendFocus]),
            category(Category.focusEndedAutoStarted, [skipBreak, extendFocus]),
            category(Category.breakEndedAwaiting, [startFocus]),
            category(Category.breakEndedAutoStarted, []),
            category(Category.posture, [
                action(.confirmPosture, String(localized: "Done")),
                action(.snoozePosture, snoozeTitle),
            ]),
            category(Category.hydration, [
                action(.logWater, String(localized: "I Drank a Glass")),
                action(.snoozeWater, snoozeTitle),
            ]),
            category(Category.reminders, [
                action(.completeReminders, String(localized: "Done")),
                action(.snoozeReminders, snoozeTitle),
            ]),
        ]
    }
}
