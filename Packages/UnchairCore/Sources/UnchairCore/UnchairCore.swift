// UnchairCore holds Unchair's platform-independent logic: timers, reminders,
// scheduling, and statistics.
//
// Rule: this module must not import SwiftUI, AppKit, or any other Apple UI or
// platform framework, so it can be reused on Windows and Linux later.
// Only Foundation is allowed.
