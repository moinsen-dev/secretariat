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
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
