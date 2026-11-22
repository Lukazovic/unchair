import Foundation

public extension History {
    /// Pretty-printed JSON with ISO 8601 dates.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// One row per record: `type,date,value,detail`. Dates are ISO 8601,
    /// durations are seconds, water is milliliters.
    func csv() -> String {
        let formatter = ISO8601DateFormatter()
        var rows: [(Date, String)] = []
        for session in focusSessions {
            rows.append((session.end, "focus,\(formatter.string(from: session.end)),\(Int(session.duration)),"))
        }
        for change in presenceChanges {
            rows.append((change.date, "presence,\(formatter.string(from: change.date)),,\(change.state.rawValue)"))
        }
        for entry in waterEntries {
            rows.append((entry.date, "water,\(formatter.string(from: entry.date)),\(entry.amount),"))
        }
        for response in reminderResponses {
            let detail = "\(response.kind.rawValue):\(response.outcome.rawValue)"
            rows.append((response.date, "reminder,\(formatter.string(from: response.date)),,\(detail)"))
        }
        let body = rows.sorted { $0.0 < $1.0 }.map(\.1)
        return (["type,date,value,detail"] + body).joined(separator: "\n") + "\n"
    }
}
