import AppKit
import SwiftUI

/// How the Pomodoro countdown appears next to the menu bar icon.
enum MenuBarTimerStyle: String, CaseIterable, Identifiable {
    case hidden
    /// Rounded-up minutes, such as "25m". Changes once a minute.
    case minutes
    /// A live countdown, such as "24:59".
    case minutesAndSeconds

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .hidden: "Hidden"
        case .minutes: "Minutes"
        case .minutesAndSeconds: "Minutes and Seconds"
        }
    }

    func text(remaining: TimeInterval) -> String? {
        switch self {
        case .hidden: nil
        case .minutes: Format.roundedMinutes(remaining)
        case .minutesAndSeconds: Format.countdown(remaining)
        }
    }
}

/// The menu bar icon while no break is running.
enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case figure
    case tomato
    case redTomato

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .figure: "Figure"
        case .tomato: "Tomato"
        case .redTomato: "Red Tomato"
        }
    }

    /// The icon when idle or focusing. Breaks and pauses keep their own symbols.
    var image: Image {
        switch self {
        case .figure: Image(systemName: "figure.stand")
        case .tomato: Image(nsImage: TomatoIcon.template)
        case .redTomato: Image(nsImage: TomatoIcon.colored)
        }
    }
}

/// A tomato drawn in code, so it stays crisp at menu bar size.
enum TomatoIcon {
    static let template = make(colored: false)
    static let colored = make(colored: true)

    private static func make(colored: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let red = NSColor(srgbRed: 0.89, green: 0.26, blue: 0.21, alpha: 1)
            let green = NSColor(srgbRed: 0.25, green: 0.62, blue: 0.30, alpha: 1)

            (colored ? red : .black).setFill()
            NSBezierPath(ovalIn: NSRect(x: 1.5, y: 4, width: 15, height: 13)).fill()

            let calyx = calyxPath()
            if !colored {
                // Cut a thin gap around the leaves so they read against the body.
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                calyx.lineWidth = 1.1
                calyx.stroke()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
            (colored ? green : .black).setFill()
            calyx.fill()
            NSBezierPath(roundedRect: NSRect(x: 8.25, y: 1, width: 1.5, height: 4), xRadius: 0.75, yRadius: 0.75)
                .fill()
            return true
        }
        image.isTemplate = !colored
        return image
    }

    /// Five slender leaves lying over the top of the fruit, fanning out
    /// sideways and down from the stem (angles in degrees, y pointing down).
    private static func calyxPath() -> NSBezierPath {
        let center = NSPoint(x: 9, y: 5)
        let leafAngles: [CGFloat] = [-15, 35, 90, 145, 195]
        let path = NSBezierPath()
        for (index, degrees) in leafAngles.enumerated() {
            let angle = degrees * .pi / 180
            let tip = NSPoint(x: center.x + 5.5 * cos(angle), y: center.y + 4 * sin(angle))
            let gapAngle = (degrees + 27.5) * .pi / 180
            let notch = NSPoint(x: center.x + 1.2 * cos(gapAngle), y: center.y + 1.2 * sin(gapAngle))
            if index == 0 {
                path.move(to: tip)
            } else {
                path.line(to: tip)
            }
            path.line(to: notch)
        }
        path.close()
        return path
    }
}
