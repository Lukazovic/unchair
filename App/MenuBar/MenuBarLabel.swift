import SwiftUI
import UnchairCore

/// The menu bar item: an icon, plus the remaining time while a phase is active.
struct MenuBarLabel: View {
    let model: AppModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        content
            .task {
                // The label appears at launch, so it's where first-run onboarding starts.
                guard !model.hasCompletedOnboarding else { return }
                openWindow(id: "onboarding")
                NSApplication.shared.activate()
            }
    }

    @ViewBuilder
    private var content: some View {
        let pomodoro = model.engine.pomodoro

        if let remaining = pomodoro.remaining(at: model.now) {
            HStack(spacing: 4) {
                icon
                if let text = model.menuBarTimer.text(remaining: remaining) {
                    Text(text)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Unchair"))
            .accessibilityValue(Text(accessibilityValue(remaining: remaining)))
        } else {
            icon
                .accessibilityLabel(Text("Unchair"))
        }
    }

    /// Breaks and pauses keep their symbols, so the state is clear at a glance.
    private var icon: Image {
        let pomodoro = model.engine.pomodoro
        if pomodoro.phase != nil, !pomodoro.isRunning {
            return Image(systemName: "pause.fill")
        }
        if let phase = pomodoro.phase, phase.isBreak {
            return Image(systemName: phase.symbolName)
        }
        if pomodoro.phase == .focus, model.menuBarIcon == .figure {
            return Image(systemName: PomodoroPhase.focus.symbolName)
        }
        return model.menuBarIcon.image
    }

    private func accessibilityValue(remaining: TimeInterval) -> String {
        let time = Format.minutes(remaining)
        let pomodoro = model.engine.pomodoro
        guard let phase = pomodoro.phase else { return "" }
        let name = switch phase {
        case .focus: String(localized: "Focus")
        case .shortBreak: String(localized: "Short Break")
        case .longBreak: String(localized: "Long Break")
        }
        return pomodoro.isRunning
            ? String(localized: "\(name), \(time) left")
            : String(localized: "\(name) paused, \(time) left")
    }
}
