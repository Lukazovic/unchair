import Foundation
import UnchairCore

/// The title and body for one or more wellbeing reminders that arrive
/// together, shared by notifications and full-screen alerts.
struct ReminderMessage {
    let title: String
    let body: String

    init(kinds: [ReminderKind], postureTarget: Posture?, water: (intake: Int, goal: Int)) {
        if kinds.count == 1, let kind = kinds.first {
            (title, body) = Self.single(kind, postureTarget: postureTarget, water: water)
            return
        }

        let actions = kinds.map { kind -> String in
            switch kind {
            case .posture:
                if postureTarget == .sitting {
                    return String(localized: "sit down")
                }
                return String(localized: "stand up")
            case .hydration: return String(localized: "drink water")
            case .eyes: return String(localized: "rest your eyes")
            case .postureCheck: return String(localized: "check your posture")
            }
        }
        let list = ListFormatter.localizedString(byJoining: actions)
        title = String(localized: "Time to \(list)")
        if kinds.contains(.hydration) {
            body = Self.waterProgress(water)
        } else if kinds.contains(.eyes) {
            body = Self.eyeInstructions
        } else {
            body = ""
        }
    }

    private static func single(
        _ kind: ReminderKind,
        postureTarget: Posture?,
        water: (intake: Int, goal: Int)
    ) -> (String, String) {
        switch kind {
        case .posture:
            if postureTarget == .sitting {
                return (
                    String(localized: "Time to sit down"),
                    String(localized: "Nice work. Take a seat and keep going.")
                )
            }
            return (
                String(localized: "Time to stand up"),
                String(localized: "Raise your desk and work standing for a while.")
            )
        case .hydration:
            return (String(localized: "Time to drink water"), waterProgress(water))
        case .eyes:
            return (String(localized: "Rest your eyes"), eyeInstructions)
        case .postureCheck:
            return (
                String(localized: "Posture check"),
                String(localized: "Relax your shoulders, sit back, and keep your screen at eye level.")
            )
        }
    }

    private static var eyeInstructions: String {
        String(localized: "Look at something about 6 meters (20 feet) away for 20 seconds.")
    }

    private static func waterProgress(_ water: (intake: Int, goal: Int)) -> String {
        String(localized: "\(Format.volume(water.intake)) of \(Format.volume(water.goal)) today.")
    }
}

extension ReminderKind {
    /// The reminder an engine event delivers, if any.
    init?(_ event: UnchairEvent) {
        switch event {
        case .posture: self = .posture
        case .hydration: self = .hydration
        case .eyeBreak: self = .eyes
        case .postureCheck: self = .postureCheck
        case .pomodoro, .dayEnded: return nil
        }
    }
}
