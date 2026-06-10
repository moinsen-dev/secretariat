import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Platform channel: resolve sandbox-only paths the Dart side cannot
    // derive from $HOME (a sandboxed app's $HOME is its own container).
    let channel = FlutterMethodChannel(
      name: "dev.moinsen.secretariat/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { (call, result) in
      let fm = FileManager.default
      switch call.method {
      // The daemon's Unix socket lives in the shared App Group container so
      // the sandboxed app can reach it.
      case "getSocketPath":
        if let url = fm.containerURL(
          forSecurityApplicationGroupIdentifier: "group.dev.moinsen.secretariat") {
          result(url.appendingPathComponent("secretariat.sock").path)
        } else {
          result(FlutterError(
            code: "NO_GROUP_CONTAINER",
            message: "App Group container unavailable", details: nil))
        }
      // iCloud Drive (ubiquity) container for the encrypted vault sync file.
      case "getUbiquityContainerPath":
        if let url = fm.url(
          forUbiquityContainerIdentifier: "iCloud.dev.moinsen.secretariat") {
          result(url.path)
        } else {
          result(nil)  // iCloud not signed in / not ready yet
        }
      // Read the encrypted vault sync file from iCloud (coordinated). Returns
      // the JSON string, or nil if it doesn't exist yet.
      case "icloudRead":
        guard let base = fm.url(
          forUbiquityContainerIdentifier: "iCloud.dev.moinsen.secretariat") else {
          result(nil); return
        }
        let fileURL = base.appendingPathComponent("Documents/secretariat-vault.json")
        var coordError: NSError?
        var contents: String?
        NSFileCoordinator().coordinate(
          readingItemAt: fileURL, options: [], error: &coordError) { url in
          contents = try? String(contentsOf: url, encoding: .utf8)
        }
        result(contents)
      // Write the encrypted vault sync file to iCloud (coordinated, atomic).
      case "icloudWrite":
        guard let base = fm.url(
          forUbiquityContainerIdentifier: "iCloud.dev.moinsen.secretariat") else {
          result(FlutterError(code: "NO_ICLOUD",
                              message: "iCloud unavailable", details: nil)); return
        }
        guard let args = call.arguments as? [String: Any],
              let content = args["content"] as? String else {
          result(FlutterError(code: "BAD_ARGS",
                              message: "content required", details: nil)); return
        }
        let docsDir = base.appendingPathComponent("Documents")
        try? fm.createDirectory(at: docsDir, withIntermediateDirectories: true)
        let fileURL = docsDir.appendingPathComponent("secretariat-vault.json")
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(
          writingItemAt: fileURL, options: .forReplacing, error: &coordError) { url in
          do { try content.write(to: url, atomically: true, encoding: .utf8) }
          catch { writeError = error }
        }
        if let e = writeError ?? coordError {
          result(FlutterError(code: "WRITE_FAILED",
                              message: e.localizedDescription, details: nil))
        } else {
          result(true)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
