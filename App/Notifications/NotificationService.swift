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
}

/// Each kind uses a fixed request identifier, so a new notification replaces
/// the previous one of the same kind instead of piling up.
enum NotificationKind: String {
    case pomodoro
    case posture
    case hydration
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
    }

    /// Sets the delegate, registers categories, and asks for permission.
    func activate() {
        center.delegate = self
        center.setNotificationCategories(makeCategories())
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func post(_ event: UnchairEvent) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        let kind: NotificationKind

        switch event {
        case let .pomodoro(.phaseCompleted(phase, next, autoStarted)):
            kind = .pomodoro
            fill(content, phase: phase, next: next, autoStarted: autoStarted)
        case let .posture(.switchSuggested(posture)):
            kind = .posture
            content.categoryIdentifier = Category.posture
            switch posture {
            case .standing:
                content.title = String(localized: "Time to stand up")
                content.body = String(localized: "Raise your desk and work standing for a while.")
            case .sitting:
                content.title = String(localized: "Time to sit down")
                content.body = String(localized: "Nice work. Take a seat and keep going.")
            }
        case let .hydration(.reminder(intake, goal)):
            kind = .hydration
            content.categoryIdentifier = Category.hydration
            content.title = String(localized: "Time to drink water")
            content.body = String(localized: "\(Format.volume(intake)) of \(Format.volume(goal)) today.")
        }

        let request = UNNotificationRequest(identifier: kind.rawValue, content: content, trigger: nil)
        center.add(request)
    }

    func removeDelivered(_ kind: NotificationKind) {
        center.removeDeliveredNotifications(withIdentifiers: [kind.rawValue])
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
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

        let startBreak = action(.startBreak, String(localized: "Start Break"))
        let skipBreak = action(.skipBreak, String(localized: "Skip Break"))
        let extendFocus = action(.extendFocus, String(localized: "5 More Minutes"))
        let startFocus = action(.startFocus, String(localized: "Start Focus"))
        let confirmPosture = action(.confirmPosture, String(localized: "Done"))
        let snoozePosture = action(.snoozePosture, String(localized: "Snooze 10 Minutes"))
        let logWater = action(.logWater, String(localized: "I Drank a Glass"))
        let snoozeWater = action(.snoozeWater, String(localized: "Snooze 10 Minutes"))

        return [
            UNNotificationCategory(
                identifier: Category.focusEndedAwaiting,
                actions: [startBreak, skipBreak, extendFocus],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.focusEndedAutoStarted,
                actions: [skipBreak, extendFocus],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.breakEndedAwaiting,
                actions: [startFocus],
                intentIdentifiers: []
            ),
            UNNotificationCategory(identifier: Category.breakEndedAutoStarted, actions: [], intentIdentifiers: []),
            UNNotificationCategory(
                identifier: Category.posture,
                actions: [confirmPosture, snoozePosture],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Category.hydration,
                actions: [logWater, snoozeWater],
                intentIdentifiers: []
            ),
        ]
    }
}
