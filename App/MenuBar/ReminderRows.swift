import SwiftUI
import UnchairCore

struct PostureRow: View {
    let model: AppModel

    private var reminder: PostureReminder {
        model.engine.posture
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: reminder.posture.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.posture.title)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(reminder.state == .suggested ? .orange : .secondary)
            }

            Spacer()

            Button(reminder.posture == .sitting ? "Stand Up" : "Sit Down", action: model.confirmPostureSwitch)
                .controlSize(.small)
        }
    }

    private var status: String {
        let standingNext = reminder.posture == .sitting
        switch reminder.state {
        case .stopped:
            return ""
        case let .counting(until):
            let time = Format.minutes(until.timeIntervalSince(model.now))
            return standingNext ? String(localized: "Stand up in \(time)") : String(localized: "Sit down in \(time)")
        case .waitingForBreak:
            return standingNext
                ? String(localized: "Stand up at the next break")
                : String(localized: "Sit down at the next break")
        case .suggested:
            return standingNext ? String(localized: "Time to stand up") : String(localized: "Time to sit down")
        }
    }
}

struct HydrationRow: View {
    let model: AppModel

    var body: some View {
        let hydration = model.engine.hydration
        let intake = hydration.intake(at: model.now)

        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Water")
                    Spacer()
                    Text(verbatim: "\(Format.volume(intake)) / \(Format.volume(hydration.settings.dailyGoal))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: hydration.progress(at: model.now))
                    .tint(.cyan)
            }

            HStack(spacing: 2) {
                Button(action: model.removeWater) {
                    Label("Remove a Glass", systemImage: "minus")
                        .labelStyle(.iconOnly)
                }
                .disabled(intake == 0)
                .help(Text("Remove a Glass"))

                Button(action: model.logWater) {
                    Label("Add a Glass", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .help(Text("Add a Glass"))
            }
            .controlSize(.small)
        }
    }
}
