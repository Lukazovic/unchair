import SwiftUI

@main
struct UnchairApp: App {
    #if DEBUG
        @State private var model = AppModel(history: .forLaunch())
    #else
        @State private var model = AppModel()
    #endif

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }

        Window("Statistics", id: "statistics") {
            StatsView(model: model)
        }
        .defaultSize(width: 620, height: 760)
    }
}
