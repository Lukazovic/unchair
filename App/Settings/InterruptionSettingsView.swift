import SwiftUI
import UnchairCore

struct InterruptionSettingsView: View {
    @Bindable var model: AppModel

    private var interruptions: Binding<InterruptionSettings> {
        $model.settings.interruptions
    }

    var body: some View {
        Form {
            Section {
                Toggle("Hold reminders during calls", isOn: interruptions.holdDuringMeetings)
                Toggle("Hold reminders when an app is full screen", isOn: interruptions.holdDuringFullscreen)
                DurationStepper(
                    "Combine reminders due within",
                    value: interruptions.coalescingWindow,
                    minutes: 0 ... 15
                )
            } header: {
                Text("Interruptions")
            } footer: {
                Text(Copy.interruptionsFooter)
            }

            Section {
                Toggle("Pause focus when I'm away", isOn: interruptions.pauseFocusWhenAway)
                DurationStepper("Away after", value: interruptions.awayThreshold, minutes: 2 ... 15)
            } header: {
                Text("Away")
            } footer: {
                Text(Copy.awayFooter)
            }

            Section {
                Toggle("Only remind me during working hours", isOn: interruptions.workingHours.isEnabled)
                Group {
                    WeekdayPicker(selection: interruptions.workingHours.weekdays)
                    TimeOfDayPicker("Start", minutes: interruptions.workingHours.start, range: 0 ... (24 * 60 - 1))
                    TimeOfDayPicker(
                        "End",
                        minutes: interruptions.workingHours.end,
                        range: (model.settings.interruptions.workingHours.start + 15) ... (24 * 60 - 1)
                    )
                }
                .disabled(!model.settings.interruptions.workingHours.isEnabled)
            } header: {
                Text("Working Hours")
            }

            Section {
                Button("Open Focus Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } header: {
                Text("Focus")
            } footer: {
                Text(Copy.focusFilterFooter)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: model.settings.interruptions.workingHours.start) { _, start in
            if model.settings.interruptions.workingHours.end <= start {
                model.settings.interruptions.workingHours.end = min(start + 60, 24 * 60 - 1)
            }
        }
    }
}

/// Toggle buttons for days of the week, in the user's locale order.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let names = calendar.standaloneWeekdaySymbols
        let order = (0 ..< 7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }

        LabeledContent("Days") {
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { weekday in
                    Toggle(isOn: binding(for: weekday)) {
                        Text(verbatim: symbols[weekday - 1])
                            .frame(minWidth: 14)
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(Text(verbatim: names[weekday - 1]))
                }
            }
        }
    }

    private func binding(for weekday: Int) -> Binding<Bool> {
        Binding {
            selection.contains(weekday)
        } set: { isOn in
            if isOn {
                selection.insert(weekday)
            } else {
                selection.remove(weekday)
            }
        }
    }
}
