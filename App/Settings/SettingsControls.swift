import SwiftUI

/// A row with a title, a formatted duration, and a stepper that edits it in minutes.
struct DurationStepper: View {
    let title: LocalizedStringKey
    @Binding var value: TimeInterval
    let minutes: ClosedRange<Int>
    let step: Int

    init(_ title: LocalizedStringKey, value: Binding<TimeInterval>, minutes: ClosedRange<Int>, step: Int = 1) {
        self.title = title
        _value = value
        self.minutes = minutes
        self.step = step
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(Format.minutes(value))
                    .monospacedDigit()
                Stepper(title, value: minutesBinding, in: minutes, step: step)
                    .labelsHidden()
            }
        }
    }

    private var minutesBinding: Binding<Int> {
        Binding {
            Int((value / 60).rounded())
        } set: {
            value = TimeInterval($0 * 60)
        }
    }
}

/// A row with a title, a formatted volume, and a stepper that edits it in milliliters.
struct VolumeStepper: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    init(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, step: Int) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(Format.volume(value))
                    .monospacedDigit()
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
    }
}
