import SwiftUI
import UnchairCore
import UserNotifications

struct GeneralSettingsView: View {
    @Bindable var model: AppModel

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var exportDocument: HistoryDocument?
    @State private var exportError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Toggle("Show timer in menu bar", isOn: $model.showsTimerInMenuBar)
                Picker("Start or pause focus from anywhere", selection: $model.globalShortcut) {
                    ForEach(GlobalShortcut.allCases) { shortcut in
                        if let symbols = shortcut.symbols {
                            Text(verbatim: symbols).tag(shortcut)
                        } else {
                            Text("Off").tag(shortcut)
                        }
                    }
                }
            }

            Section("Notifications") {
                LabeledContent("Status") {
                    Text(notificationStatusText)
                }
                LabeledContent("Sound") {
                    HStack {
                        Picker("Sound", selection: $model.notificationSound) {
                            ForEach(NotificationSoundOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button {
                            model.notificationSound.preview()
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .labelStyle(.iconOnly)
                        }
                        .help(Text("Play"))
                        .disabled(model.notificationSound == .none)
                    }
                }
                Button("Open Notification Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section {
                Toggle("Summarize my day", isOn: $model.settings.summary.isEnabled)
                if !model.settings.interruptions.workingHours.isEnabled {
                    TimeOfDayPicker("At", minutes: $model.settings.summary.time, range: 0 ... (24 * 60 - 1))
                        .disabled(!model.settings.summary.isEnabled)
                }
            } header: {
                Text("Daily Summary")
            } footer: {
                Text(Copy.summaryFooter)
            }

            Section {
                LabeledContent("History") {
                    Button("Export…", action: export)
                }
                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                LabeledContent("Version", value: Bundle.main.marketingVersion)
            } footer: {
                Text("Your history stays on this Mac.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .fileExporter(
            isPresented: Binding { exportDocument != nil } set: {
                if !$0 {
                    exportDocument = nil
                }
            },
            document: exportDocument,
            contentTypes: HistoryDocument.readableContentTypes,
            defaultFilename: "Unchair History"
        ) { result in
            if case let .failure(error) = result {
                exportError = error.localizedDescription
            }
        }
        .task {
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private var notificationStatusText: LocalizedStringKey {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Turned off"
        case .notDetermined: "Not set up"
        case nil: "…"
        @unknown default: "Unknown"
        }
    }

    /// The save panel lets the user pick JSON or CSV as the file format.
    private func export() {
        exportError = nil
        exportDocument = HistoryDocument(history: model.history.history())
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}

private extension Bundle {
    var marketingVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}
