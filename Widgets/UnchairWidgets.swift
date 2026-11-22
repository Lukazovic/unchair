import SwiftUI
import UnchairCore
import WidgetKit

@main
struct UnchairWidgets: WidgetBundle {
    var body: some Widget {
        FocusTimerWidget()
        TodayWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the snapshot the app shares through the App Group. The app reloads
/// timelines whenever something shown changes, so one entry is enough; a
/// running phase also refreshes when it ends.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in _: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = currentEntry()
        let policy: TimelineReloadPolicy = if case let .running(_, endsAt) = entry.snapshot.timer {
            .after(endsAt)
        } else {
            .never
        }
        completion(Timeline(entries: [entry], policy: policy))
    }

    private func currentEntry() -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? WidgetSnapshot(updatedAt: .now))
    }
}

extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        updatedAt: .now,
        timer: .running(.focus, endsAt: .now.addingTimeInterval(18 * 60)),
        posture: .sitting,
        focusSessionsToday: 3,
        focusTimeToday: 75 * 60,
        standingTimeToday: 40 * 60,
        waterToday: 1250,
        waterGoal: 2000
    )
}

// MARK: - Focus timer

struct FocusTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusTimer", provider: SnapshotProvider()) { entry in
            FocusTimerView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Timer")
        .description("The current Pomodoro phase and time left.")
        .supportedFamilies([.systemSmall])
    }
}

struct FocusTimerView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(headline)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            timer
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let posture = snapshot.posture {
                Label(
                    posture == .standing ? "Standing" : "Sitting",
                    systemImage: posture == .standing ? "figure.stand" : "chair.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var timer: some View {
        switch snapshot.timer {
        case let .running(_, endsAt):
            Text(endsAt, style: .timer)
        case let .paused(_, remaining):
            Text(Duration.seconds(Int(remaining)).formatted(.time(pattern: .minuteSecond)))
                .foregroundStyle(.secondary)
        case .idle, .awaiting:
            Text(verbatim: "–:––")
                .foregroundStyle(.tertiary)
        }
    }

    private var headline: LocalizedStringKey {
        switch snapshot.timer {
        case .idle: "Ready to Focus"
        case let .running(phase, _): title(of: phase)
        case .paused: "Paused"
        case .awaiting(.focus): "Up Next: Focus"
        case .awaiting: "Up Next: Break"
        }
    }

    private var symbol: String {
        switch snapshot.timer {
        case .running(.focus, _): "timer"
        case .running: "cup.and.saucer.fill"
        case .paused: "pause.fill"
        case .idle, .awaiting: "figure.stand"
        }
    }

    private func title(of phase: PomodoroPhase) -> LocalizedStringKey {
        switch phase {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }
}

// MARK: - Today

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: SnapshotProvider()) { entry in
            TodayView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Focus time, standing time, and water so far today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayView: View {
    let snapshot: WidgetSnapshot

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let water = Measurement(value: Double(snapshot.waterToday), unit: UnitVolume.milliliters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        let progress = snapshot.waterGoal > 0 ? min(1, Double(snapshot.waterToday) / Double(snapshot.waterGoal)) : 0

        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            if family == .systemMedium {
                HStack(alignment: .top) {
                    metric("Focus", value: total(snapshot.focusTimeToday), symbol: "timer")
                    metric("Standing", value: total(snapshot.standingTimeToday), symbol: "figure.stand")
                    metric("Water", value: water, symbol: "drop.fill")
                }
            } else {
                metric("Focus", value: total(snapshot.focusTimeToday), symbol: "timer")
                metric("Water", value: water, symbol: "drop.fill")
            }

            Spacer(minLength: 0)

            ProgressView(value: progress)
                .tint(.cyan)
                .accessibilityLabel(Text("Water goal"))
        }
    }

    private func metric(_ title: LocalizedStringKey, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func total(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let allowed: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 60 ? [.hours, .minutes] : [.minutes]
        return Duration.seconds(minutes * 60).formatted(.units(allowed: allowed, width: .abbreviated))
    }
}
