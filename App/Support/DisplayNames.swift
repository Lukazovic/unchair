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
