import SwiftUI
import UnchairCore

struct BreakOverlayView: View {
    let model: AppModel
    let onHide: () -> Void

    var body: some View {
        let pomodoro = model.engine.pomodoro

        ZStack {
            Rectangle()
                .fill(.ultraThickMaterial)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text(pomodoro.phase?.title ?? "Break")
                    .font(.largeTitle.weight(.semibold))

                if let remaining = pomodoro.remaining(at: model.now) {
                    Text(Format.countdown(remaining))
                        .font(.system(size: 96, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }

                if let stretch = model.currentStretch {
                    StretchCard(stretch: stretch)
                        .frame(maxWidth: 420)
                }

                if model.settings.eyes.isEnabled {
                    Label("Rest your eyes on something far away.", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Skip Break", action: model.skipPomodoroPhase)
                    Button("Hide", action: onHide)
                        .keyboardShortcut(.cancelAction)
                }
                .controlSize(.large)
            }
            .padding(40)
        }
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
