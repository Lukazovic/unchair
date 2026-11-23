import SwiftUI
import UnchairCore

/// A full-screen reminder. Done marks every reminder in it as done; Snooze
/// (or Escape) brings them back in 10 minutes.
struct ReminderOverlayView: View {
    let alert: FullScreenReminder
    let onDone: () -> Void
    let onSnooze: () -> Void
    /// Called when the eye countdown ends.
    let onEyesRested: () -> Void

    var body: some View {
        OverlayContainer {
            VStack(spacing: 24) {
                HStack(spacing: 20) {
                    ForEach(alert.kinds, id: \.self) { kind in
                        Image(systemName: symbol(for: kind))
                            .foregroundStyle(kind == .hydration ? AnyShapeStyle(.cyan) : AnyShapeStyle(.tint))
                    }
                }
                .font(.system(size: 64, weight: .light))
                .accessibilityHidden(true)

                Text(alert.message.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)

                if !alert.message.body.isEmpty {
                    Text(alert.message.body)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if alert.kinds.contains(.eyes) {
                    EyeCountdown(onFinish: onEyesRested)
                }

                HStack(spacing: 12) {
                    Button("Snooze 10 Minutes", action: onSnooze)
                        .keyboardShortcut(.cancelAction)
                        .secondaryActionStyle()
                    Button(doneTitle, action: onDone)
                        .keyboardShortcut(.defaultAction)
                        .prominentActionStyle()
                }
                .controlSize(.large)
                .padding(.top, 8)
            }
            .frame(maxWidth: 560)
        }
    }

    private var doneTitle: LocalizedStringKey {
        alert.kinds == [.hydration] ? "I Drank a Glass" : "Done"
    }

    private func symbol(for kind: ReminderKind) -> String {
        switch kind {
        case .posture: (alert.postureTarget ?? .standing).symbolName
        case .hydration: "drop.fill"
        case .eyes: "eye"
        case .postureCheck: "figure.seated.side.right"
        }
    }
}

/// The reminders currently shown full screen.
struct FullScreenReminder {
    var kinds: [ReminderKind]
    var postureTarget: Posture?
    var message: ReminderMessage
}
