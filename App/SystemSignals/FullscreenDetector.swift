import AppKit

/// Detects whether the frontmost app has a window covering a whole screen
/// (full screen apps, presentations, full screen video).
///
/// Uses window bounds and owners only, which don't require Screen Recording
/// permission (window titles would).
enum FullscreenDetector {
    static func isFrontmostAppFullscreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != "com.apple.finder",
              let primaryHeight = NSScreen.screens.first?.frame.height,
              let windows = CGWindowListCopyWindowInfo(
                  [.optionOnScreenOnly, .excludeDesktopElements],
                  kCGNullWindowID
              ) as? [[String: Any]]
        else { return false }

        // Window bounds use a top-left origin; NSScreen frames use bottom-left.
        let screens = NSScreen.screens.map { screen in
            CGRect(
                x: screen.frame.minX,
                y: primaryHeight - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
        }

        return windows.contains { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let boundsDictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { return false }
            return screens.contains { $0.equalTo(bounds) }
        }
    }
}
