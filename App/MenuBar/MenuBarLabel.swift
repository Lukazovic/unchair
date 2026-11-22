import SwiftUI

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
        let symbol = pomodoro.phase?.symbolName ?? "figure.stand"

        if model.showsTimerInMenuBar, let remaining = pomodoro.remaining(at: model.now) {
            HStack(spacing: 4) {
                Image(systemName: pomodoro.isRunning ? symbol : "pause.fill")
                Text(Format.countdown(remaining))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Unchair"))
            .accessibilityValue(Text(accessibilityValue(remaining: remaining)))
        } else {
            Image(systemName: symbol)
                .accessibilityLabel(Text("Unchair"))
        }
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
