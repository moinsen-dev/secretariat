import AppKit

/// Opens the Polar checkout in Safari, because Polar's hosted checkout offers Apple Pay only there.
/// Falls back to the default browser when Safari is missing or fails to open the page.
enum Checkout {
    static func open(_ url: URL) {
        guard let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: safari, configuration: NSWorkspace.OpenConfiguration()) { @Sendable _, error in
            if error != nil { Task { @MainActor in NSWorkspace.shared.open(url) } }
        }
    }
}
