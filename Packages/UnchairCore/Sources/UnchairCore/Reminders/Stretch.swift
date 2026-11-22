import Foundation

/// A small curated set of desk-friendly stretches suggested during breaks.
/// The app provides localized names, instructions, and symbols.
public enum Stretch: String, CaseIterable, Codable, Sendable {
    case neckTilt
    case shoulderRolls
    case chestOpener
    case wristStretch
    case seatedTwist
    case standingHamstring
    case calfRaises
    case upperBackStretch

    /// A stretch for the given break, rotating through the set so consecutive
    /// breaks suggest different stretches.
    public static func suggestion(forBreak index: Int) -> Stretch {
        let all = allCases
        let position = ((index % all.count) + all.count) % all.count
        return all[position]
    }
}
