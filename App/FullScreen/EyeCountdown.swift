import SwiftUI

/// Counts down the 20 seconds of a 20-20-20 eye break.
struct EyeCountdown: View {
    let onFinish: () -> Void

    static let duration = 20

    @State private var remaining = Self.duration

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: Double(remaining) / Double(Self.duration))
                .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(remaining)")
                .font(.largeTitle.weight(.light))
                .monospacedDigit()
        }
        .frame(width: 96, height: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Time remaining"))
        .accessibilityValue(Text(verbatim: "\(remaining)"))
        .task {
            while remaining > 0 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                remaining -= 1
            }
            onFinish()
        }
    }
}
