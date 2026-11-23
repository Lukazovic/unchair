import SwiftUI
import UnchairCore

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

/// A time picker bound to minutes after midnight.
struct TimeOfDayPicker: View {
    let title: LocalizedStringKey
    @Binding var minutes: Int
    let range: ClosedRange<Int>

    init(_ title: LocalizedStringKey, minutes: Binding<Int>, range: ClosedRange<Int>) {
        self.title = title
        _minutes = minutes
        self.range = range
    }

    var body: some View {
        DatePicker(title, selection: date, in: dateRange, displayedComponents: .hourAndMinute)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private func toDate(_ minutes: Int) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private var dateRange: ClosedRange<Date> {
        toDate(range.lowerBound) ... toDate(range.upperBound)
    }

    private var date: Binding<Date> {
        Binding {
            toDate(minutes)
        } set: { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }
}

/// Chooses between a notification and a full-screen alert, with a button
/// that shows a sample of the chosen style.
struct AlertStylePicker: View {
    let title: LocalizedStringKey
    @Binding var style: AlertStyle
    let onPreview: () -> Void

    init(_ title: LocalizedStringKey, style: Binding<AlertStyle>, onPreview: @escaping () -> Void) {
        self.title = title
        _style = style
        self.onPreview = onPreview
    }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Picker(title, selection: $style) {
                    Text("Notification").tag(AlertStyle.notification)
                    Text("Full Screen").tag(AlertStyle.fullScreen)
                }
                .labelsHidden()
                .fixedSize()
                Button("Test", action: onPreview)
                    .help(Text("Show a sample of this alert"))
            }
        }
    }
}

extension AppModel {
    /// The alert style of a reminder, for settings controls.
    func alertStyle(for kind: ReminderKind) -> Binding<AlertStyle> {
        Binding {
            self.settings.alerts.style(for: kind)
        } set: {
            self.settings.alerts.setStyle($0, for: kind)
        }
    }

    /// The Pomodoro break alert: a notification, or the full-screen break timer.
    var breakAlertStyle: Binding<AlertStyle> {
        Binding {
            self.settings.breaks.showsOverlay ? .fullScreen : .notification
        } set: {
            self.settings.breaks.showsOverlay = $0 == .fullScreen
        }
    }
}
