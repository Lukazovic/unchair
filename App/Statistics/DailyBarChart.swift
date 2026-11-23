import Charts
import SwiftUI
import UnchairCore

/// One measure per day as thin bars, with an optional goal line. Hovering a
/// day highlights its bar and shows its value in the header.
struct DailyBarChart: View {
    let title: LocalizedStringKey
    let days: [DayStats]
    let color: Color
    let value: (DayStats) -> Double
    let format: (Double) -> String
    /// Shorter labels for the value axis. Defaults to `format`.
    var axisFormat: ((Double) -> String)?
    var goal: Double?

    @State private var selectedDate: Date?

    private var selectedDay: DayStats? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(headerDetail)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Value", value(day)),
                        width: .ratio(0.55)
                    )
                    .cornerRadius(4, style: .continuous)
                    .foregroundStyle(color.opacity(selectedDay == nil || selectedDay?.day == day.day ? 1 : 0.35))
                    .accessibilityLabel(Text(day.day, format: .dateTime.weekday(.wide).day().month()))
                    .accessibilityValue(Text(format(value(day))))
                }

                if let goal {
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days.count > 10 ? 7 : 1)) {
                    AxisValueLabel(format: days.count > 10 ? .dateTime.day().month(.abbreviated) : .dateTime.weekday())
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let number = axisValue.as(Double.self) {
                            Text((axisFormat ?? format)(number))
                        }
                    }
                }
            }
            .frame(height: 150)
        }
    }

    /// The hovered day's value, or the daily average.
    private var headerDetail: String {
        if let selectedDay {
            let date = selectedDay.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return "\(date): \(format(value(selectedDay)))"
        }
        guard let average = days.dailyAverage(of: value) else { return "" }
        return String(localized: "Daily average: \(format(average))")
    }
}
