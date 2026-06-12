import AppIntents
import AppKit
import Foundation
import LocalAuthentication

// App Intents expose Secretariat to the system Shortcuts app, so a user can
// bind a global keyboard shortcut that fetches a secret and (via a paste step)
// inserts it wherever the cursor is. The intent talks to the daemon over the
// App Group Unix socket — the daemon decrypts (trusted local interface), so no
// crypto runs here. Mirrored on iOS later (there the intent reads the iCloud
// vault + decrypts via the Rust core, since iOS has no daemon).

/// A secret, as a pickable entity in Shortcuts (so the user chooses from a list
/// instead of typing the name). Listing needs no unlock — only names cross.
@available(macOS 13.0, *)
struct SecretEntity: AppEntity {
  var id: String  // the secret name/key
  var provider: String?

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Secret"
  static var defaultQuery = SecretEntityQuery()

  var displayRepresentation: DisplayRepresentation {
    if let p = provider, !p.isEmpty {
      return DisplayRepresentation(title: "\(id)", subtitle: "\(p)")
    }
    return DisplayRepresentation(title: "\(id)")
  }
}

@available(macOS 13.0, *)
struct SecretEntityQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [SecretEntity] {
    let all = try SecretariatDaemon.listSecrets()
    return all.filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [SecretEntity] {
    try SecretariatDaemon.listSecrets()
  }
}

@available(macOS 13.0, *)
struct GetSecretValueIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Secret"
  static var description = IntentDescription(
    "Fetch a Secretariat secret and copy its value to the clipboard so you can paste it.")

  @Parameter(title: "Secret")
  var secret: SecretEntity

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let value: String
    do {
      value = try SecretariatDaemon.getSecret(name: secret.id)
    } catch SecretariatError.locked {
      // Vault is locked — gate with Touch ID, unlock from the Keychain, retry.
      try await SecretariatDaemon.authenticate(reason: "Unlock Secretariat to fill \(secret.id)")
      try SecretariatDaemon.unlockKeychain()
      value = try SecretariatDaemon.getSecret(name: secret.id)
    }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    return .result(value: value, dialog: "Copied \(secret.id) to the clipboard.")
  }
}

@available(macOS 13.0, *)
struct SecretariatShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: GetSecretValueIntent(),
      phrases: ["Get a \(.applicationName) secret"],
      shortTitle: "Get Secret",
      systemImageName: "key.fill")
  }
}

enum SecretariatError: Error, CustomLocalizedStringResourceConvertible {
  case notConnected
  case locked
  case notFound(String)
  case authFailed
  case protocolError(String)

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .notConnected: return "Secretariat daemon isn't running."
    case .locked: return "Vault is locked — unlock Secretariat first."
    case .notFound(let n): return "Secret '\(n)' was not found."
    case .authFailed: return "Touch ID authentication failed."
    case .protocolError(let m): return "Secretariat error: \(m)"
    }
  }
}

/// Minimal newline-delimited JSON-RPC client over the App Group Unix socket.
enum SecretariatDaemon {
  static func socketPath() -> String? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.dev.moinsen.secretariat")?
      .appendingPathComponent("secretariat.sock").path
  }

  static func listSecrets() throws -> [SecretEntity] {
    let resp = try request(method: "secret.list", params: [:])
    guard let result = resp["result"] as? [String: Any],
          let secrets = result["secrets"] as? [[String: Any]] else {
      return []
    }
    return secrets.compactMap { dict in
      guard let name = dict["name"] as? String else { return nil }
      return SecretEntity(id: name, provider: dict["provider"] as? String)
    }
  }

  static func getSecret(name: String) throws -> String {
    let resp = try request(
      method: "secret.get",
      params: ["name": name, "app_id": "flutter-app"])
    if let err = resp["error"] as? [String: Any] {
      let msg = (err["message"] as? String) ?? "unknown error"
      if msg.contains("locked") { throw SecretariatError.locked }
      if msg.contains("not found") || msg.contains("does not exist") {
        throw SecretariatError.notFound(name)
      }
      throw SecretariatError.protocolError(msg)
    }
    guard let result = resp["result"] as? [String: Any],
          let value = result["value"] as? String else {
      throw SecretariatError.protocolError("malformed response")
    }
    return value
  }

  static func unlockKeychain() throws {
    let resp = try request(method: "vault.unlock_keychain", params: [:])
    if let err = resp["error"] as? [String: Any] {
      throw SecretariatError.protocolError((err["message"] as? String) ?? "unlock failed")
    }
  }

  /// Biometric (Touch ID) gate, falling back to the device password.
  static func authenticate(reason: String) async throws {
    let ctx = LAContext()
    var err: NSError?
    guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
      throw SecretariatError.authFailed
    }
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, evalErr in
        if ok { cont.resume() } else { cont.resume(throwing: evalErr ?? SecretariatError.authFailed) }
      }
    }
  }

  static func request(method: String, params: [String: Any]) throws -> [String: Any] {
    guard let path = socketPath() else { throw SecretariatError.notConnected }

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    if fd < 0 { throw SecretariatError.notConnected }
    defer { close(fd) }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = path.utf8CString
    guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
      throw SecretariatError.notConnected
    }
    withUnsafeMutablePointer(to: &addr.sun_path) { dst in
      dst.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { d in
        pathBytes.withUnsafeBufferPointer { src in
          d.update(from: src.baseAddress!, count: pathBytes.count)
        }
      }
    }
    let connected = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    if connected < 0 { throw SecretariatError.notConnected }

    let req: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params]
    var data = try JSONSerialization.data(withJSONObject: req)
    data.append(0x0A)
    _ = data.withUnsafeBytes { write(fd, $0.baseAddress, data.count) }

    var response = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
      let n = read(fd, &buf, buf.count)
      if n <= 0 { break }
      response.append(contentsOf: buf[0..<n])
      if buf[0..<n].contains(0x0A) { break }
    }
    guard let text = String(data: response, encoding: .utf8),
          let line = text.split(separator: "\n").first,
          let obj = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
    else {
      throw SecretariatError.protocolError("no/invalid response")
    }
    return obj
  }
}
