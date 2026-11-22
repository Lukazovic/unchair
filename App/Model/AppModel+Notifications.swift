import Foundation
import UnchairCore
import UserNotifications

/// Notification permission.
extension AppModel {
    @discardableResult
    func requestNotificationPermission() async -> Bool {
        let granted = await notifications.requestAuthorization()
        await refreshNotificationStatus()
        return granted
    }

    func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// True when some enabled reminder relies on notifications that can't be shown.
    var needsNotificationPermission: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral, nil: return false
        case .notDetermined, .denied: break
        @unknown default: return false
        }
        let enabled: [(Bool, ReminderKind)] = [
            (settings.posture.isEnabled, .posture),
            (settings.hydration.isEnabled, .hydration),
            (settings.eyes.isEnabled, .eyes),
            (settings.postureCheck.isEnabled, .postureCheck),
        ]
        return !settings.breaks.showsOverlay
            || enabled.contains { $0.0 && settings.alerts.style(for: $0.1) == .notification }
    }
}
