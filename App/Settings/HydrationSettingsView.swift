import SwiftUI

struct HydrationSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to drink water", isOn: $model.settings.hydration.isEnabled)
            }

            Section {
                DurationStepper(
                    "Remind every",
                    value: $model.settings.hydration.reminderInterval,
                    minutes: 15 ... 180,
                    step: 15
                )
                VolumeStepper("Daily goal", value: $model.settings.hydration.dailyGoal, range: 500 ... 5000, step: 250)
                VolumeStepper("Glass size", value: $model.settings.hydration.glassSize, range: 100 ... 1000, step: 50)
                AlertStylePicker(style: model.alertStyle(for: .hydration)) { model.previewAlert(for: .hydration) }
            } footer: {
                Text(Copy.hydrationFooter)
            }
            .disabled(!model.settings.hydration.isEnabled)
        }
        .formStyle(.grouped)
        .fitsScreenHeight()
    }
}
