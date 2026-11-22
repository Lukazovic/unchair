import SwiftUI
import UnchairCore

/// Today at a glance, streaks, and daily charts for the last week or month.
struct StatsView: View {
    enum Range: Int, CaseIterable, Identifiable {
        case week = 7
        case month = 30

        var id: Int {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
            case .week: "7 Days"
            case .month: "30 Days"
            }
        }
    }

    let model: AppModel

    @State private var range: Range = .week
    @State private var days: [DayStats] = []
    @State private var streakDays: [DayStats] = []

    var body: some View {
        let today = days.last ?? DayStats(day: Calendar.current.startOfDay(for: model.now))
        let goal = model.settings.hydration.dailyGoal

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Today")
                    .font(.title2.weight(.semibold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatTile(
                        title: "Focus",
                        value: Format.total(today.focusTime),
                        detail: String(localized: "\(today.focusSessions) sessions")
                    )
                    StatTile(title: "Standing", value: Format.total(today.standingTime), detail: nil)
                    StatTile(
                        title: "Water",
                        value: Format.volume(today.water),
                        detail: String(localized: "of \(Format.volume(goal))")
                    )
                    StatTile(
                        title: "Water Goal Streak",
                        value: String(localized: "\(streakDays.streak { $0.water >= goal }) days"),
                        detail: nil
                    )
                    StatTile(
                        title: "Focus Streak",
                        value: String(localized: "\(streakDays.streak { $0.focusSessions > 0 }) days"),
                        detail: nil
                    )
                }

                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                DailyBarChart(
                    title: "Focus",
                    days: days,
                    color: .accentColor,
                    value: { $0.focusTime },
                    format: Format.total,
                    axisFormat: Format.compactTotal
                )
                DailyBarChart(
                    title: "Standing",
                    days: days,
                    color: .orange,
                    value: { $0.standingTime },
                    format: Format.total,
                    axisFormat: Format.compactTotal
                )
                DailyBarChart(
                    title: "Water",
                    days: days,
                    color: .cyan,
                    value: { Double($0.water) },
                    format: { Format.volume(Int($0)) },
                    goal: Double(goal)
                )
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 560)
        .task(id: range) {
            days = model.recentStats(days: range.rawValue)
            streakDays = model.recentStats(days: 365)
        }
    }
}

/// A headline number with a label: today's totals and streaks.
private struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.weight(.semibold))
                .monospacedDigit()
            // Always reserve the detail line so tiles in a row line up.
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(detail == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}
