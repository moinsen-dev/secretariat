import Foundation
import Sparkle

/// Sparkle: checks https://secretariat.moinsen.dev/appcast.xml once a day and installs signed, notarized
/// releases on request. The CLI lives in the same bundle (~/bin/secretariat is a symlink), so it updates too.
/// Builds without a feed key (swift run, tests) never start the updater.
final class Updates {
    private let controller: SPUStandardUpdaterController?

    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String != nil
        controller = configured ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) : nil
    }

    var available: Bool { controller != nil }
    func check() { controller?.checkForUpdates(nil) }
}
