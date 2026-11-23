import SwiftUI
import UnchairCore

struct PomodoroSection: View {
    let model: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pomodoro: PomodoroTimer {
        model.engine.pomodoro
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline)
                    .font(.headline)
                Spacer()
                CycleIndicator(completed: pomodoro.sessionsInCurrentCycle, total: pomodoro.cycleLength)
            }

            Text(Format.countdown(displayedTime))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pomodoro.isRunning ? .primary : .secondary)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("Time remaining"))
                .accessibilityValue(Text(Format.minutes(displayedTime)))

            ProgressView(value: pomodoro.progress(at: model.now) ?? 0)
                .tint(pomodoro.phase?.isBreak == true ? .green : .accentColor)
                .accessibilityLabel(Text("Phase progress"))

            controls

            if let undo = model.pomodoroUndo {
                HStack {
                    Text(undo.action == .reset ? "Cycle reset" : "Focus skipped")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo", action: model.undoPomodoroAction)
                        .keyboardShortcut("z")
                }
                .font(.callout)
                .controlSize(.small)
            }

            if let stretch = model.currentStretch {
                StretchCard(stretch: stretch)
            }
        }
    }

    private var headline: LocalizedStringKey {
        switch pomodoro.state {
        case .idle: "Ready to Focus"
        case let .running(phase, _, _): phase.title
        case .paused: "Paused"
        case let .awaiting(next):
            switch next {
            case .focus: "Up Next: Focus"
            case .shortBreak: "Up Next: Short Break"
            case .longBreak: "Up Next: Long Break"
            }
        }
    }

    /// Remaining time, or the full duration of the phase that would start next.
    private var displayedTime: TimeInterval {
        if let remaining = pomodoro.remaining(at: model.now) {
            return remaining
        }
        if case let .awaiting(next) = pomodoro.state {
            return pomodoro.settings.duration(for: next)
        }
        return pomodoro.settings.focusDuration
    }

    private var controls: some View {
        HStack {
            switch pomodoro.state {
            case .idle:
                Button(action: model.startPomodoro) {
                    Label("Start Focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .prominentActionStyle()

            case let .awaiting(next):
                Button(action: model.startPomodoro) {
                    Label(next.isBreak ? "Start Break" : "Start Focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .prominentActionStyle()
                if next.isBreak {
                    skipButton
                }
                resetButton

            case .running:
                Button(action: model.pausePomodoro) {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .secondaryActionStyle()
                skipButton
                resetButton

            case .paused:
                Button(action: model.resumePomodoro) {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .prominentActionStyle()
                skipButton
                resetButton
            }
        }
        .controlSize(.large)
    }

    private var skipButton: some View {
        Button(action: model.skipPomodoroPhase) {
            Label("Skip", systemImage: "forward.end.fill")
                .labelStyle(.iconOnly)
        }
        .secondaryActionStyle()
        .help(Text("Skip"))
    }

    private var resetButton: some View {
        Button(action: model.resetPomodoro) {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .labelStyle(.iconOnly)
        }
        .secondaryActionStyle()
        .help(Text("Reset"))
    }
}

/// Dots showing focus sessions completed in the current cycle.
private struct CycleIndicator: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< total, id: \.self) { index in
                Circle()
                    .fill(index < completed ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(completed) of \(total) sessions completed"))
    }
}
