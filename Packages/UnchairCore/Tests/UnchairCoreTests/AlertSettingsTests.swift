import Foundation
import Testing
@testable import UnchairCore

@Suite("Alert settings")
struct AlertSettingsTests {
    @Test("reminders use notifications by default")
    func defaultsToNotifications() {
        let alerts = AlertSettings()
        for kind in ReminderKind.allCases {
            #expect(alerts.style(for: kind) == .notification)
        }
    }

    @Test("each reminder can switch style on its own")
    func switchesPerReminder() {
        var alerts = AlertSettings()
        alerts.setStyle(.fullScreen, for: .posture)
        alerts.setStyle(.fullScreen, for: .hydration)
        alerts.setStyle(.notification, for: .hydration)

        #expect(alerts.style(for: .posture) == .fullScreen)
        #expect(alerts.style(for: .hydration) == .notification)
        #expect(alerts.fullScreenReminders == [.posture])
    }

    @Test("round-trips through JSON")
    func roundTrips() throws {
        var settings = UnchairSettings()
        settings.alerts.setStyle(.fullScreen, for: .eyes)
        let decoded = try JSONDecoder().decode(UnchairSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test("settings saved before alerts existed still decode")
    func decodesOlderSettings() throws {
        var old = UnchairSettings()
        old.hydration.dailyGoal = 3000
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any]
        )
        json.removeValue(forKey: "alerts")
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(UnchairSettings.self, from: data)

        #expect(decoded.hydration.dailyGoal == 3000)
        #expect(decoded.alerts == AlertSettings())
    }

    @Test("unknown reminder kinds are ignored")
    func ignoresUnknownKinds() throws {
        let data = Data(#"{"fullScreenReminders":["posture","teleport"]}"#.utf8)
        let decoded = try JSONDecoder().decode(AlertSettings.self, from: data)
        #expect(decoded.fullScreenReminders == [.posture])
    }
}
