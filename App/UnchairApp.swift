import SwiftUI
import UnchairCore

@main
struct UnchairApp: App {
    private let clock: any WallClock = SystemClock()

    var body: some Scene {
        MenuBarExtra("Unchair", systemImage: "figure.stand") {
            MenuBarContentView(clock: clock)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
