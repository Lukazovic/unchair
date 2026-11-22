import Foundation
import UnchairCore

/// Identifies a break, so a hidden break overlay stays hidden for that break.
enum BreakOverlayKey: Equatable {
    case awaiting(Int)
    case running(Date)
}

/// Full-screen breaks and reminders.
extension AppModel {
    /// The break that is due or running, if any.
    private var currentBreak: BreakOverlayKey? {
        switch engine.pomodoro.state {
        case let .running(phase, endsAt, _) where phase.isBreak: .running(endsAt)
        case let .awaiting(phase) where phase.isBreak: .awaiting(engine.pomodoro.completedFocusSessions)
        default: nil
        }
    }

    func updateOverlay() {
        let isHeld = switch engine.holdReason(at: clock.now) {
        case .quietMode, .focusMode, .meeting, .fullscreen: true
        case .away, .outsideWorkingHours, nil: false
        }
        guard settings.breaks.showsOverlay, let key = currentBreak, key != hiddenBreakOverlay, !isHeld else {
            breakOverlay.hide()
            return
        }
        guard !breakOverlay.isVisible else { return }
        breakOverlay.show { [weak self] in
            self?.hideBreakOverlay()
        } content: {
            BreakOverlayView(model: self) { [weak self] in
                self?.hideBreakOverlay()
            }
        }
    }

    private func hideBreakOverlay() {
        hiddenBreakOverlay = currentBreak
        breakOverlay.hide()
    }

    func postureTarget(in events: [UnchairEvent]) -> Posture? {
        for case let .posture(.switchSuggested(posture)) in events {
            return posture
        }
        return nil
    }

    /// Shows `kinds` full screen, together with any reminders already showing.
    func presentFullScreen(_ kinds: [ReminderKind], postureTarget: Posture?) {
        guard !kinds.isEmpty else { return }
        var all = fullScreenReminder?.kinds ?? []
        for kind in kinds where !all.contains(kind) {
            all.append(kind)
        }
        let target = postureTarget ?? fullScreenReminder?.postureTarget
        let water = (engine.hydration.intake(at: clock.now), settings.hydration.dailyGoal)
        let alert = FullScreenReminder(
            kinds: all,
            postureTarget: target,
            message: ReminderMessage(kinds: all, postureTarget: target, water: water)
        )
        fullScreenReminder = alert
        reminderOverlay.hide()
        reminderOverlay.show { [weak self] in
            self?.respondToFullScreen(.snoozeReminders)
        } content: {
            ReminderOverlayView(
                alert: alert,
                onDone: { [weak self] in self?.respondToFullScreen(.completeReminders) },
                onSnooze: { [weak self] in self?.respondToFullScreen(.snoozeReminders) }
            )
        }
    }

    private func respondToFullScreen(_ action: NotificationAction) {
        guard let alert = fullScreenReminder else { return }
        fullScreenReminder = nil
        reminderOverlay.hide()
        perform(action, kinds: Set(alert.kinds))
    }

    /// Removes a reminder the user handled elsewhere, such as in the menu bar panel.
    func clearFullScreen(_ kind: ReminderKind) {
        guard let alert = fullScreenReminder, alert.kinds.contains(kind) else { return }
        fullScreenReminder = nil
        reminderOverlay.hide()
        presentFullScreen(alert.kinds.filter { $0 != kind }, postureTarget: alert.postureTarget)
    }
}
