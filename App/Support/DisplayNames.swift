import SwiftUI
import UnchairCore

extension PomodoroPhase {
    var title: LocalizedStringKey {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var symbolName: String {
        switch self {
        case .focus: "timer"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        }
    }
}

extension PomodoroPreset {
    var title: LocalizedStringKey {
        switch self {
        case .classic: "Classic (25/5)"
        case .extended: "Extended (50/10)"
        case .deepWork: "Deep Work (90/20)"
        }
    }
}

extension Posture {
    var title: LocalizedStringKey {
        switch self {
        case .sitting: "Sitting"
        case .standing: "Standing"
        }
    }

    var symbolName: String {
        switch self {
        case .sitting: "chair.fill"
        case .standing: "figure.stand"
        }
    }
}

// Stretch instructions are full sentences; splitting them would break localization keys.
// swiftlint:disable line_length
extension Stretch {
    var title: String {
        switch self {
        case .neckTilt: String(localized: "Neck tilt")
        case .shoulderRolls: String(localized: "Shoulder rolls")
        case .chestOpener: String(localized: "Chest opener")
        case .wristStretch: String(localized: "Wrist stretch")
        case .seatedTwist: String(localized: "Seated twist")
        case .standingHamstring: String(localized: "Hamstring stretch")
        case .calfRaises: String(localized: "Calf raises")
        case .upperBackStretch: String(localized: "Upper back stretch")
        }
    }

    var instructions: String {
        switch self {
        case .neckTilt:
            String(localized: "Slowly tilt your head toward each shoulder. Hold for 15 seconds on each side.")
        case .shoulderRolls:
            String(localized: "Roll your shoulders backward ten times, then forward ten times.")
        case .chestOpener:
            String(
                localized: "Clasp your hands behind your back, straighten your arms, and gently lift your chest for 20 seconds."
            )
        case .wristStretch:
            String(
                localized: "Extend one arm, palm up, and gently pull your fingers back. Hold for 15 seconds, then switch."
            )
        case .seatedTwist:
            String(localized: "Sit tall and turn your upper body to one side. Hold for 15 seconds on each side.")
        case .standingHamstring:
            String(localized: "Stand, put one heel forward, and hinge at the hips. Hold for 20 seconds on each leg.")
        case .calfRaises:
            String(localized: "Stand and slowly rise onto your toes, then lower. Repeat 15 times.")
        case .upperBackStretch:
            String(
                localized: "Interlace your fingers in front of you, round your upper back, and push your hands away for 20 seconds."
            )
        }
    }

    var symbolName: String {
        switch self {
        case .neckTilt: "figure.mind.and.body"
        case .shoulderRolls, .chestOpener: "figure.arms.open"
        case .wristStretch: "hand.raised.fill"
        case .seatedTwist, .standingHamstring: "figure.flexibility"
        case .calfRaises: "figure.step.training"
        case .upperBackStretch: "figure.cooldown"
        }
    }
}

// swiftlint:enable line_length
