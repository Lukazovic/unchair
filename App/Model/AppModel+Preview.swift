import Foundation
import UnchairCore

/// Samples of each alert, shown from Settings. They never change timers,
/// water, or history.
extension AppModel {
    func previewAlert(for kind: ReminderKind) {
        let water = (engine.hydration.intake(at: clock.now), settings.hydration.dailyGoal)
        switch settings.alerts.style(for: kind) {
        case .notification:
            Task {
                await ensureNotificationPermission()
                notifications.postPreview(
                    of: kind,
                    postureTarget: .standing,
                    extras: NotificationExtras(water: water)
                )
            }
        case .fullScreen:
            let alert = FullScreenReminder(
                kinds: [kind],
                postureTarget: .standing,
                message: ReminderMessage(kinds: [kind], postureTarget: .standing, water: water)
            )
            previewOverlay.show { [weak self] in
                self?.previewOverlay.hide()
            } content: {
                ReminderOverlayView(
                    alert: alert,
                    onDone: { [weak self] in self?.previewOverlay.hide() },
                    onSnooze: { [weak self] in self?.previewOverlay.hide() }
                )
            }
        }
    }

    func previewBreakAlert() {
        let stretch = settings.breaks.suggestsStretches ? Stretch.suggestion(forBreak: 0) : nil
        if settings.breaks.showsOverlay {
            previewOverlay.show { [weak self] in
                self?.previewOverlay.hide()
            } content: {
                BreakPreviewView(
                    duration: settings.pomodoro.shortBreakDuration,
                    stretch: stretch,
                    mentionsEyes: settings.eyes.isEnabled
                ) { [weak self] in
                    self?.previewOverlay.hide()
                }
            }
        } else {
            Task {
                await ensureNotificationPermission()
                notifications.postBreakPreview(extras: NotificationExtras(
                    stretch: stretch,
                    mentionsEyes: settings.eyes.isEnabled && settings.eyes.mergeWithPomodoro
                ))
            }
        }
    }

    /// Pass `-UnchairDemoFullScreen` (Debug builds) to see a full-screen reminder at launch.
    func showLaunchDemoIfRequested() {
        #if DEBUG
            guard CommandLine.arguments.contains("-UnchairDemoFullScreen") else { return }
            Task {
                try? await clock.sleep(for: 1)
                presentFullScreen([.posture, .hydration], postureTarget: .standing)
            }
        #endif
    }

    /// Asks for permission if the user was never asked, so the sample can appear.
    private func ensureNotificationPermission() async {
        await refreshNotificationStatus()
        if notificationStatus == .notDetermined {
            await requestNotificationPermission()
        }
    }
}
