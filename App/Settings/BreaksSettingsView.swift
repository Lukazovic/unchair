import SwiftUI

struct BreaksSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to rest my eyes (20-20-20)", isOn: $model.settings.eyes.isEnabled)
                Group {
                    DurationStepper("Every", value: $model.settings.eyes.interval, minutes: 10 ... 60, step: 5)
                    Toggle("Fold into Pomodoro breaks", isOn: $model.settings.eyes.mergeWithPomodoro)
                }
                .disabled(!model.settings.eyes.isEnabled)
            } header: {
                Text("Eyes")
            } footer: {
                Text(Copy.eyesFooter)
            }

            Section {
                Toggle("Suggest a stretch during breaks", isOn: $model.settings.breaks.suggestsStretches)
                Toggle("Cover the screen during breaks", isOn: $model.settings.breaks.showsOverlay)
            } header: {
                Text("Pomodoro Breaks")
            } footer: {
                Text(Copy.overlayFooter)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}
