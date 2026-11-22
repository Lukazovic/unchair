import SwiftUI

/// The menu bar item: an icon, plus the remaining time while a phase is active.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let pomodoro = model.engine.pomodoro
        let symbol = pomodoro.phase?.symbolName ?? "figure.stand"

        if model.showsTimerInMenuBar, let remaining = pomodoro.remaining(at: model.now) {
            HStack(spacing: 4) {
                Image(systemName: pomodoro.isRunning ? symbol : "pause.fill")
                Text(Format.countdown(remaining))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Unchair"))
        } else {
            Image(systemName: symbol)
                .accessibilityLabel(Text("Unchair"))
        }
    }
}
