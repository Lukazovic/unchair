import AppIntents

/// A Focus filter: in System Settings › Focus, users add Unchair to a Focus
/// and choose whether reminders are held while it's on.
///
/// The system runs ``perform()`` when the Focus turns on, and again with
/// default values when it turns off, so the default must mean "don't hold".
struct UnchairFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Set Unchair Reminders"
    static let description: IntentDescription? = IntentDescription(
        "Hold Unchair's posture and water reminders while this Focus is on."
    )

    @Parameter(title: "Hold reminders", default: false)
    var holdsReminders: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: holdsReminders ? "Reminders held" : "Reminders on")
    }

    func perform() async throws -> some IntentResult {
        let holdsReminders = holdsReminders
        await MainActor.run {
            FocusFilterBridge.shared.update(holdsReminders: holdsReminders)
        }
        return .result()
    }
}

/// Hands Focus filter changes from the intent to the app model.
final class FocusFilterBridge {
    static let shared = FocusFilterBridge()

    private(set) var holdsReminders = false
    var onChange: ((Bool) -> Void)?

    func update(holdsReminders: Bool) {
        self.holdsReminders = holdsReminders
        onChange?(holdsReminders)
    }

    /// Reads the filter of the Focus that is active at launch.
    func loadCurrent() async {
        if let current = try? await UnchairFocusFilter.current {
            update(holdsReminders: current.holdsReminders)
        }
    }
}
