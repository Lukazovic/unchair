import SwiftUI
import UnchairCore

/// How every alert looks and sounds, in one place.
struct AlertsSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                AlertStylePicker("Pomodoro breaks", style: model.breakAlertStyle, onPreview: model.previewBreakAlert)
                reminder("Posture", .posture)
                reminder("Posture check", .postureCheck)
                reminder("Water", .hydration)
                reminder("Eyes", .eyes)
            } header: {
                Text("Style")
            } footer: {
                Text(Copy.alertsFooter)
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
        }
        .formStyle(.grouped)
        .fitsScreenHeight()
        .task {
            await model.refreshNotificationStatus()
        }
    }

    private func reminder(_ title: LocalizedStringKey, _ kind: ReminderKind) -> some View {
        AlertStylePicker(title, style: model.alertStyle(for: kind)) {
            model.previewAlert(for: kind)
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
}
