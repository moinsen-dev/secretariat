import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // iOS has no daemon — wire the same iCloud (ubiquity) vault sync the macOS
    // app exposes, so this device reads/writes the very document the Macs sync.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecretariatICloud") {
      ICloudBridge.register(messenger: registrar.messenger())
    }
  }
}

/// Mirrors macOS MainFlutterWindow's `dev.moinsen.secretariat/platform` method
/// channel + `dev.moinsen.secretariat/sync_events` event channel for iOS. Only
/// the iCloud document operations apply (there is no daemon socket on iOS).
final class ICloudBridge: NSObject, FlutterStreamHandler {
  private static var shared: ICloudBridge?
  private let container = "iCloud.dev.moinsen.secretariat"
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var metadataQuery: NSMetadataQuery?
  private var sink: FlutterEventSink?

  static func register(messenger: FlutterBinaryMessenger) {
    let inst = ICloudBridge()
    shared = inst  // retain
    let method = FlutterMethodChannel(
      name: "dev.moinsen.secretariat/platform", binaryMessenger: messenger)
    method.setMethodCallHandler { call, result in inst.handle(call, result) }
    let events = FlutterEventChannel(
      name: "dev.moinsen.secretariat/sync_events", binaryMessenger: messenger)
    events.setStreamHandler(inst)
    inst.methodChannel = method
    inst.eventChannel = events
  }

  private func ubiquityBase() -> URL? {
    FileManager.default.url(forUbiquityContainerIdentifier: container)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let fm = FileManager.default
    switch call.method {
    case "getUbiquityContainerPath":
      result(ubiquityBase()?.path)  // nil if iCloud not signed in / not ready

    case "icloudRead":
      guard let base = ubiquityBase() else { result(nil); return }
      let fileURL = base.appendingPathComponent("Documents/secretariat-vault.json")
      var coordError: NSError?
      var contents: String?
      NSFileCoordinator().coordinate(
        readingItemAt: fileURL, options: [], error: &coordError) { url in
        contents = try? String(contentsOf: url, encoding: .utf8)
      }
      result(contents)

    case "icloudWrite":
      guard let base = ubiquityBase() else {
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

    case "getSocketPath":
      result(FlutterError(code: "NO_DAEMON",
                          message: "iOS has no daemon socket", details: nil))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: FlutterStreamHandler — NSMetadataQuery change notifications.

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    startMetadataQuery()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopMetadataQuery()
    sink = nil
    return nil
  }

  private func startMetadataQuery() {
    guard metadataQuery == nil else { return }
    let q = NSMetadataQuery()
    q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    q.predicate = NSPredicate(
      format: "%K == %@", NSMetadataItemFSNameKey, "secretariat-vault.json")
    NotificationCenter.default.addObserver(
      self, selector: #selector(metadataChanged(_:)),
      name: .NSMetadataQueryDidUpdate, object: q)
    NotificationCenter.default.addObserver(
      self, selector: #selector(metadataChanged(_:)),
      name: .NSMetadataQueryDidFinishGathering, object: q)
    q.start()
    metadataQuery = q
  }

  private func stopMetadataQuery() {
    if let q = metadataQuery {
      q.stop()
      NotificationCenter.default.removeObserver(
        self, name: .NSMetadataQueryDidUpdate, object: q)
      NotificationCenter.default.removeObserver(
        self, name: .NSMetadataQueryDidFinishGathering, object: q)
    }
    metadataQuery = nil
  }

  @objc private func metadataChanged(_ note: Notification) {
    sink?("changed")
  }
}
