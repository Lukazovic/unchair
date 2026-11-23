import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            FocusSettingsView(model: model)
                .tabItem { Label("Focus", systemImage: "timer") }
            PostureSettingsView(model: model)
                .tabItem { Label("Posture", systemImage: "figure.stand") }
            HydrationSettingsView(model: model)
                .tabItem { Label("Hydration", systemImage: "drop") }
            BreaksSettingsView(model: model)
                .tabItem { Label("Breaks", systemImage: "eye") }
            AlertsSettingsView(model: model)
                .tabItem { Label("Alerts", systemImage: "bell") }
            InterruptionSettingsView(model: model)
                .tabItem { Label("Interruptions", systemImage: "bell.slash") }
        }
        .frame(width: 580)
        .alert("Notifications are off", isPresented: $model.showsNotificationsBlockedAlert) {
            Button("Open Notification Settings…", action: NotificationSettings.open)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Unchair to see this sample, or choose Full Screen.")
        }
    }
}

#Preview {
    SettingsView(model: AppModel())
}
