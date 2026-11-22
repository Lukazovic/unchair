import SwiftUI

@main
struct UnchairApp: App {
    @State private var model = AppModel()

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
