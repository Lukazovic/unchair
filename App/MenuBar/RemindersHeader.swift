import SwiftUI
import UnchairCore

/// Title row for the reminders section: shows why reminders are held and
/// offers to pause them.
struct RemindersHeader: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                Spacer()
                if case .quietMode = model.holdReason {
                    Button("Resume", action: model.resumeReminders)
                        .controlSize(.small)
                } else {
                    Menu {
                        Button("For 30 Minutes") { model.pauseReminders(for: .thirtyMinutes) }
                        Button("For 1 Hour") { model.pauseReminders(for: .oneHour) }
                        Button("Until Tomorrow") { model.pauseReminders(for: .untilTomorrow) }
                    } label: {
                        Label("Pause Reminders", systemImage: "moon.zzz")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .controlSize(.small)
                }
            }

            if let reason = model.holdReason {
                Label {
                    Text(description(of: reason))
                } icon: {
                    Image(systemName: symbol(for: reason))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func description(of reason: HoldReason) -> String {
        switch reason {
        case let .quietMode(until):
            if Calendar.current.isDateInToday(until) {
                let time = until.formatted(date: .omitted, time: .shortened)
                return String(localized: "Paused until \(time)")
            }
            return String(localized: "Paused until tomorrow")
        case .away:
            return String(localized: "Held while you're away")
        case .outsideWorkingHours:
            return String(localized: "Held outside working hours")
        case .focusMode:
            return String(localized: "Held during your Focus")
        case .meeting:
            return String(localized: "Held while you're in a call")
        case .fullscreen:
            return String(localized: "Held while an app is full screen")
        }
    }

    private func symbol(for reason: HoldReason) -> String {
        switch reason {
        case .quietMode: "moon.zzz.fill"
        case .away: "figure.walk"
        case .outsideWorkingHours: "clock"
        case .focusMode: "moon.fill"
        case .meeting: "video.fill"
        case .fullscreen: "arrow.up.left.and.arrow.down.right"
        }
    }
}
