import SwiftUI
import UnchairCore

struct BreakOverlayView: View {
    let model: AppModel
    let onHide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAwaiting: Bool {
        if case .awaiting = model.engine.pomodoro.state {
            return true
        }
        return false
    }

    private var title: LocalizedStringKey {
        if case let .awaiting(phase) = model.engine.pomodoro.state {
            return phase.title
        }
        return model.engine.pomodoro.phase?.title ?? "Break"
    }

    var body: some View {
        let pomodoro = model.engine.pomodoro

        OverlayContainer {
            VStack(spacing: 28) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))

                if isAwaiting {
                    Text("Step away from the screen for a few minutes.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else if let remaining = pomodoro.remaining(at: model.now) {
                    Text(Format.countdown(remaining))
                        .font(.system(size: 96, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .accessibilityLabel(Text("Time remaining"))
                        .accessibilityValue(Text(Format.minutes(remaining)))
                }

                if let stretch = model.currentStretch {
                    StretchCard(stretch: stretch)
                        .frame(maxWidth: 420)
                }

                if model.settings.eyes.isEnabled {
                    Label("Rest your eyes on something far away.", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }

                if let alert = model.fullScreenReminder {
                    BreakReminderCard(
                        message: alert.message,
                        onDone: { model.respondToFullScreen(.completeReminders) },
                        onSnooze: { model.respondToFullScreen(.snoozeReminders) }
                    )
                    .frame(maxWidth: 420)
                }

                HStack(spacing: 12) {
                    Button("Skip Break", action: model.skipBreakFromOverlay)
                        .secondaryActionStyle()
                    if isAwaiting {
                        Button("Hide", action: onHide)
                            .keyboardShortcut(.cancelAction)
                            .secondaryActionStyle()
                        Button("Start Break", action: model.startPomodoro)
                            .keyboardShortcut(.defaultAction)
                            .prominentActionStyle()
                    } else {
                        Button("Hide", action: onHide)
                            .keyboardShortcut(.cancelAction)
                            .prominentActionStyle()
                    }
                }
                .controlSize(.large)
            }
        }
    }
}

/// Reminders that came due together with the break.
private struct BreakReminderCard: View {
    let message: ReminderMessage
    let onDone: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.title)
                .font(.headline)
            if !message.body.isEmpty {
                Text(message.body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Done", action: onDone)
                Button("Snooze 10 Minutes", action: onSnooze)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// A stretch suggestion with its symbol and instructions.
struct StretchCard: View {
    let stretch: Stretch

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: stretch.symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(stretch.title)
                    .font(.headline)
                Text(stretch.instructions)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

/// A sample of the full-screen break, shown from Settings.
struct BreakPreviewView: View {
    let duration: TimeInterval
    let stretch: Stretch?
    let mentionsEyes: Bool
    let onHide: () -> Void

    var body: some View {
        OverlayContainer {
            VStack(spacing: 28) {
                Text(PomodoroPhase.shortBreak.title)
                    .font(.largeTitle.weight(.semibold))
                Text(Format.countdown(duration))
                    .font(.system(size: 96, weight: .light, design: .rounded))
                    .monospacedDigit()
                if let stretch {
                    StretchCard(stretch: stretch)
                        .frame(maxWidth: 420)
                }
                if mentionsEyes {
                    Label("Rest your eyes on something far away.", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button("Skip Break", action: onHide)
                        .secondaryActionStyle()
                    Button("Hide", action: onHide)
                        .keyboardShortcut(.cancelAction)
                        .prominentActionStyle()
                }
                .controlSize(.large)
            }
        }
    }
}
