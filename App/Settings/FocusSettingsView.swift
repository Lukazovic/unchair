import SwiftUI
import UnchairCore

struct FocusSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("Preset", selection: preset) {
                    ForEach(PomodoroPreset.allCases) { preset in
                        Text(preset.title).tag(PomodoroPreset?.some(preset))
                    }
                    Text("Custom").tag(PomodoroPreset?.none)
                }
            } footer: {
                Text(Copy.focusPresetFooter)
            }

            Section("Durations") {
                DurationStepper("Focus", value: $model.settings.pomodoro.focusDuration, minutes: 5 ... 180, step: 5)
                DurationStepper("Short break", value: $model.settings.pomodoro.shortBreakDuration, minutes: 1 ... 30)
                DurationStepper(
                    "Long break",
                    value: $model.settings.pomodoro.longBreakDuration,
                    minutes: 5 ... 60,
                    step: 5
                )
                LabeledContent("Long break after") {
                    HStack {
                        Text("\(model.settings.pomodoro.sessionsBeforeLongBreak) sessions")
                            .monospacedDigit()
                        Stepper(
                            "Long break after",
                            value: $model.settings.pomodoro.sessionsBeforeLongBreak,
                            in: 2 ... 8
                        )
                        .labelsHidden()
                    }
                }
            }

            Section("Automation") {
                Toggle("Start breaks automatically", isOn: $model.settings.pomodoro.autoStartBreaks)
                Toggle("Start focus sessions automatically", isOn: $model.settings.pomodoro.autoStartFocus)
            }

            Section {
                AlertStylePicker("Break alert", style: model.breakAlertStyle, onPreview: model.previewBreakAlert)
            } footer: {
                Text(Copy.overlayFooter)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var preset: Binding<PomodoroPreset?> {
        Binding {
            PomodoroPreset.matching(model.settings.pomodoro)
        } set: { preset in
            preset?.apply(to: &model.settings.pomodoro)
        }
    }
}
