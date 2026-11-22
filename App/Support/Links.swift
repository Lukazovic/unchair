import Foundation

// Literal URLs that are known to be valid.
// swiftlint:disable force_unwrapping

/// Public pages for help, feedback, and policies.
enum Links {
    static let website = URL(string: "https://lukazovic.github.io/unchair/")!
    static let privacyPolicy = URL(string: "https://lukazovic.github.io/unchair/privacy.html")!
    static let feedback = URL(string: "https://github.com/Lukazovic/unchair/issues/new?template=feedback.yml")!

    /// A bug report with the app and macOS versions filled in.
    static var reportProblem: URL {
        var components = URLComponents(string: "https://github.com/Lukazovic/unchair/issues/new")!
        // swiftlint:enable force_unwrapping
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        components.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: "\(version) (\(build))"),
            URLQueryItem(name: "macos", value: ProcessInfo.processInfo.operatingSystemVersionString),
        ]
        return components.url ?? feedback
    }
}
