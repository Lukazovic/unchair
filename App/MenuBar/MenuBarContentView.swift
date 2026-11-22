import SwiftUI
import UnchairCore

struct MenuBarContentView: View {
    let clock: any WallClock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unchair")
                    .font(.headline)
                Text("Focus, move, and hydrate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                SettingsLink {
                    Text("Settings…")
                }
                Spacer()
                Button("Quit Unchair") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContentView(clock: SystemClock())
}
