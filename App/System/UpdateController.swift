import AppKit
import Sparkle

/// Automatic updates through Sparkle. Updates stay off until a public EdDSA
/// key is set in Info.plist (`SUPublicEDKey`), so builds without release keys
/// never try to install anything.
final class UpdateController {
    private let controller: SPUStandardUpdaterController?

    init() {
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        controller = publicKey.isEmpty ? nil : SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var isAvailable: Bool {
        controller != nil
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        NSApplication.shared.activate()
        controller?.checkForUpdates(nil)
    }
}
