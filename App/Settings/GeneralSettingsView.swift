import SwiftUI
import UnchairCore

struct GeneralSettingsView: View {
    @Bindable var model: AppModel

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var exportDocument: HistoryDocument?
    @State private var exportError: String?
    @State private var confirmsDeletingHistory = false

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
                LabeledContent("Start or pause focus from anywhere") {
                    ShortcutRecorder(shortcut: $model.globalShortcut, onRecordingChange: model.setRecordingShortcut)
                }
                if let error = model.globalShortcutError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
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
                if model.notificationStatus == .notDetermined {
                    Button("Allow Notifications…") {
                        Task { await model.requestNotificationPermission() }
                    }
                } else {
                    Button("Open Notification Settings…", action: NotificationSettings.open)
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
                    HStack {
                        Button("Export…", action: export)
                        Button("Delete…", role: .destructive) { confirmsDeletingHistory = true }
                    }
                }
                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                LabeledContent("Version", value: Bundle.main.marketingVersion)
                if model.updates.isAvailable {
                    Toggle("Check for updates automatically", isOn: automaticUpdates)
                }
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
        .confirmationDialog(
            "Delete all history?",
            isPresented: $confirmsDeletingHistory
        ) {
            Button("Delete History", role: .destructive) { model.history.deleteAll() }
        } message: {
            Text(Copy.deleteHistoryMessage)
        }
        .task {
            await model.refreshNotificationStatus()
        }
    }

    private var automaticUpdates: Binding<Bool> {
        Binding {
            model.updates.automaticallyChecksForUpdates
        } set: {
            model.updates.automaticallyChecksForUpdates = $0
        }
    }

    private var notificationStatusText: LocalizedStringKey {
        switch model.notificationStatus {
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
