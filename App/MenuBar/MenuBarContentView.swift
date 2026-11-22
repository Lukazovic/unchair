import SwiftUI
import UnchairCore

/// The panel shown when clicking the menu bar item.
struct MenuBarContentView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PomodoroSection(model: model)

            if model.settings.posture.isEnabled || model.settings.hydration.isEnabled {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    if model.settings.posture.isEnabled {
                        PostureRow(model: model)
                    }
                    if model.settings.hydration.isEnabled {
                        HydrationRow(model: model)
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

#Preview {
    MenuBarContentView(model: AppModel())
}
