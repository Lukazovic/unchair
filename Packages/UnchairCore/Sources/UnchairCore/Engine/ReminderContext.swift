import Foundation

/// What the system reports about the user's situation.
public struct ReminderContext: Equatable, Sendable {
    /// The microphone or camera is in use.
    public var isInMeeting: Bool
    /// The frontmost app is full screen.
    public var isFullscreen: Bool
    /// The active Focus has an Unchair filter that holds reminders.
    public var focusFilterHoldsReminders: Bool

    public init(isInMeeting: Bool = false, isFullscreen: Bool = false, focusFilterHoldsReminders: Bool = false) {
        self.isInMeeting = isInMeeting
        self.isFullscreen = isFullscreen
        self.focusFilterHoldsReminders = focusFilterHoldsReminders
    }
}

/// Why posture and hydration reminders are being held. Held reminders are
/// delivered once the reason goes away.
public enum HoldReason: Equatable, Sendable {
    case quietMode(until: Date)
    case away
    case outsideWorkingHours
    case focusMode
    case meeting
    case fullscreen
}
