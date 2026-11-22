import Foundation
import UnchairCore

/// High-level actions used by the global shortcut and App Intents.
extension AppModel {
    /// Starts, pauses, or resumes focus: what the global shortcut does.
    func toggleFocus() {
        switch engine.pomodoro.state {
        case .idle, .awaiting: startPomodoro()
        case .running: pausePomodoro()
        case .paused: resumePomodoro()
        }
    }

    /// Gets a focus session going from any state.
    func startFocus() {
        switch engine.pomodoro.state {
        case .idle, .awaiting(.focus): startPomodoro()
        case .awaiting, .running(.shortBreak, _, _), .running(.longBreak, _, _),
             .paused(.shortBreak, _, _), .paused(.longBreak, _, _): skipPomodoroPhase()
        case .paused(.focus, _, _): resumePomodoro()
        case .running(.focus, _, _): break
        }
    }

    /// Gets a break going from any state.
    func startBreak() {
        switch engine.pomodoro.state {
        case .awaiting(.shortBreak), .awaiting(.longBreak): startPomodoro()
        case .idle, .awaiting(.focus):
            startPomodoro()
            skipPomodoroPhase()
        case .running(.focus, _, _), .paused(.focus, _, _): skipPomodoroPhase()
        case let .paused(phase, _, _) where phase.isBreak: resumePomodoro()
        case .running, .paused: break
        }
    }
}
