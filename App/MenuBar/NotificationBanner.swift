import SwiftUI

/// Shown in the panel when reminders can't reach the user because
/// notifications were never allowed or were turned off.
struct NotificationBanner: View {
    let model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications are off")
                    .font(.headline)
                Text("Unchair can't remind you until you allow them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.notificationStatus == .denied {
                    Button("Open Notification Settings…", action: NotificationSettings.open)
                } else {
                    Button("Allow Notifications") {
                        Task { await model.requestNotificationPermission() }
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}
