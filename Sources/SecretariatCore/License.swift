import CryptoKit
import Foundation

/// A Secretariat license: the JSON the shared `moinsen-licenses` Worker (repo moinsen-edge) mails after a
/// purchase (same format as Klabauter, own keypair per product).
public struct License: Codable, Equatable, Sendable {
    public var email: String
    public var issuedAt: Date
    /// Base64 Ed25519 signature over `signedPayload`.
    public var signature: String

    /// The canonical bytes the Worker signs and the app verifies.
    var signedPayload: Data {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return Data("\(email.lowercased())\n\(f.string(from: issuedAt))".utf8)
    }
}

/// Where the license and the trial start live. The synced store keeps both in the iCloud keychain,
/// so one purchase covers every Mac and the trial doesn't restart on the next one.
public protocol LicenseStore {
    func read(_ key: String) throws -> Data?
    func write(_ key: String, _ data: Data) throws
    func remove(_ key: String) throws
}

public struct SyncedLicenseStore: LicenseStore {
    public let service: String
    public let accessGroup: String?
    public init(service: String, accessGroup: String? = SyncedItemStore.accessGroup) {
        self.service = service; self.accessGroup = accessGroup
    }
    private func query(_ key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true, kSecAttrSynchronizable as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
    public func read(_ key: String) throws -> Data? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CredentialError.unavailable(status) }
        return result as? Data
    }
    public func write(_ key: String, _ data: Data) throws {
        var query = query(key)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrLabel as String: "Secretariat license · \(key)"]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CredentialError.unavailable(status) }
    }
    public func remove(_ key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CredentialError.unavailable(status) }
    }
}

public final class InMemoryLicenseStore: LicenseStore, @unchecked Sendable {
    public var values: [String: Data] = [:]
    public init() {}
    public func read(_ key: String) throws -> Data? { values[key] }
    public func write(_ key: String, _ data: Data) throws { values[key] = data }
    public func remove(_ key: String) throws { values[key] = nil }
}

/// 14 days to try everything; afterwards app and CLI show a reminder, but nothing is ever blocked:
/// a `run` that refuses in the middle of an agent's job would cost more trust than it earns.
/// Verification is offline (Ed25519): no network, no account, no activation server.
public struct Licensing {
    public static let trialDays = 14
    public static let buyURL = URL(string: "https://secretariat.moinsen.dev/buy")!
    /// Public half of the issuer's keypair (raw 32 bytes, base64). The private half lives only in the
    /// moinsen-licenses Worker secret and in Secretariat (moinsen/secretariat-license).
    public static let productionPublicKeyBase64 = "ZpFO0CayUtXyG+mpRmXonXCG5zwIYOjOakVaTsWjUB4="

    public enum State: Equatable, Sendable {
        case licensed(email: String)
        case trial(daysLeft: Int)
        case expired
    }

    let store: any LicenseStore
    let publicKey: Curve25519.Signing.PublicKey?
    let now: () -> Date

    public init(store: any LicenseStore, publicKeyBase64: String = Licensing.productionPublicKeyBase64, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.publicKey = Data(base64Encoded: publicKeyBase64).flatMap { $0.count == 32 ? try? Curve25519.Signing.PublicKey(rawRepresentation: $0) : nil }
        self.now = now
    }

    /// The stored license, if it still verifies.
    public var license: License? { (try? store.read("license")).flatMap { $0 }.flatMap { try? verified($0) } }

    /// Current state; the first call starts the trial (shared by all Macs through the keychain).
    public func state() -> State {
        guard publicKey != nil else { return .licensed(email: "") }   // a build without a key enforces nothing
        if let license { return .licensed(email: license.email) }
        let start: Date
        if let data = try? store.read("trial-start"), let stored = try? JSONDecoder().decode(Date.self, from: data) {
            start = stored
        } else {
            start = now()
            try? store.write("trial-start", JSONEncoder().encode(start))
        }
        let end = Calendar.current.date(byAdding: .day, value: Self.trialDays, to: start) ?? start
        let seconds = end.timeIntervalSince(now())
        // Clamped: a clock set back doesn't stretch the trial.
        return seconds <= 0 ? .expired : .trial(daysLeft: min(Self.trialDays, Int((seconds / 86_400).rounded(.up))))
    }

    /// Verify the pasted JSON and store exactly what was verified.
    @discardableResult
    public func activate(_ raw: String) throws -> License {
        let data = Data(raw.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let license = try verified(data)
        try store.write("license", data)
        return license
    }

    public func remove() throws { try store.remove("license") }

    func verified(_ data: Data) throws -> License {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let license = try? decoder.decode(License.self, from: data) else {
            throw AgentError("invalid_license", "That isn't a license. Paste the whole JSON block from the purchase email.")
        }
        guard let publicKey else { throw AgentError("invalid_license", "This build doesn't check licenses.") }
        guard let signature = Data(base64Encoded: license.signature), publicKey.isValidSignature(signature, for: license.signedPayload) else {
            throw AgentError("invalid_license", "This license doesn't belong to Secretariat (signature invalid).")
        }
        return license
    }

    /// One line for app and CLI; nil while there is nothing to say.
    public static func reminder(_ state: State) -> String? {
        switch state {
        case .licensed: nil
        case .trial(let days): days <= 3 ? "Secretariat trial: \(days) day\(days == 1 ? "" : "s") left. Buy a license: \(buyURL.absoluteString)" : nil
        case .expired: "Secretariat trial has ended – everything keeps working. Please buy a license: \(buyURL.absoluteString) (then: secretariat license activate)"
        }
    }
}
