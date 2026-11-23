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

    /// True when notifications can't be shown. The end of a break always uses
    /// one, even with every other alert full screen.
    var needsNotificationPermission: Bool {
        notificationStatus == .notDetermined || notificationStatus == .denied
    }
}
