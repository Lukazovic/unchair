import SwiftUI

struct SettingsView: View {
    let model: AppModel

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
            InterruptionSettingsView(model: model)
                .tabItem { Label("Interruptions", systemImage: "bell.badge") }
        }
        .frame(width: 520)
    }
}

#Preview {
    SettingsView(model: AppModel())
}
