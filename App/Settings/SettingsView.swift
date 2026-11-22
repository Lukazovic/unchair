import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Bundle.main.marketingVersion)
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 200)
    }
}

private extension Bundle {
    var marketingVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}

#Preview {
    SettingsView()
}
