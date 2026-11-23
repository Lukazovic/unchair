import Foundation
import UnchairCore

/// A Pomodoro action that can still be undone.
struct PomodoroUndo {
    enum Action {
        case skippedFocus
        case reset
    }

    let action: Action
    let timer: PomodoroTimer
}

/// Undo for skipping a focus session and for resetting the cycle.
extension AppModel {
    static let undoWindow: TimeInterval = 10

    /// Remembers the timer before an action that loses progress.
    func offerUndo(_ action: PomodoroUndo.Action, restoring timer: PomodoroTimer) {
        pomodoroUndo = PomodoroUndo(action: action, timer: timer)
        undoTask?.cancel()
        undoTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.undoWindow)
            } catch {
                return
            }
            self?.pomodoroUndo = nil
        }
    }

    func clearUndo() {
        undoTask?.cancel()
        pomodoroUndo = nil
    }

    func undoPomodoroAction() {
        guard let undo = pomodoroUndo else { return }
        clearUndo()
        handle(engine.restorePomodoro(undo.timer, now: clock.now))
    }
}
