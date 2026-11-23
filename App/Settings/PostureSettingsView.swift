import SwiftUI

struct PostureSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to alternate sitting and standing", isOn: $model.settings.posture.isEnabled)
            } footer: {
                Text(Copy.postureFooter)
            }

            Section {
                DurationStepper("Sit for", value: $model.settings.posture.sittingDuration, minutes: 15 ... 120, step: 5)
                DurationStepper(
                    "Stand for",
                    value: $model.settings.posture.standingDuration,
                    minutes: 5 ... 60,
                    step: 5
                )
                Toggle("Wait for a break to switch", isOn: $model.settings.posture.syncWithPomodoro)
            } footer: {
                Text(Copy.postureSyncFooter)
            }
            .disabled(!model.settings.posture.isEnabled)

            Section {
                Toggle("Remind me to check my posture", isOn: $model.settings.postureCheck.isEnabled)
                Group {
                    DurationStepper(
                        "Every",
                        value: $model.settings.postureCheck.interval,
                        minutes: 30 ... 240,
                        step: 15
                    )
                }
                .disabled(!model.settings.postureCheck.isEnabled)
            } header: {
                Text("Posture Check")
            } footer: {
                Text("A quiet nudge, without sound, to relax your shoulders and sit back.")
            }
        }
        .formStyle(.grouped)
        .fitsScreenHeight()
    }
}
