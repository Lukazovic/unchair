import SwiftUI
import UnchairCore

/// The panel shown when clicking the menu bar item.
struct MenuBarContentView: View {
    let model: AppModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PomodoroSection(model: model)

            if hasReminders {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    RemindersHeader(model: model)
                    if model.settings.posture.isEnabled {
                        PostureRow(model: model)
                    }
                    if model.settings.hydration.isEnabled {
                        HydrationRow(model: model)
                    }
                    if model.settings.eyes.isEnabled {
                        EyeBreakRow(model: model)
                    }
                    if model.settings.postureCheck.isEnabled {
                        PostureCheckRow(model: model)
                    }
                }
            }

            Divider()

            HStack {
                SettingsLink {
                    Text("Settings…")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    NSApplication.shared.activate()
                })
                Button("Statistics") {
                    openWindow(id: "statistics")
                    NSApplication.shared.activate()
                }
                Spacer()
                Button("Quit Unchair") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
    }
}

private extension MenuBarContentView {
    var hasReminders: Bool {
        let settings = model.settings
        return settings.posture.isEnabled || settings.hydration.isEnabled
            || settings.eyes.isEnabled || settings.postureCheck.isEnabled
    }
}

#Preview {
    MenuBarContentView(model: AppModel())
}
