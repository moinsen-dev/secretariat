import Foundation
import Security

public enum CredentialError: LocalizedError, Sendable {
    case notFound
    case unavailable(Int32)
    public var errorDescription: String? {
        switch self {
        case .notFound: "An item is missing from the keychain. It may have been deleted on another Mac."
        case .unavailable(let status): "The macOS keychain denied access (\(status)). Please check access in Secretariat."
        }
    }
}

/// Where items live. Metadata (path, fields, identifier values) is readable without touching
/// secret values; `secrets` returns the field → value map (file fields base64-encoded).
public protocol ItemStore {
    func list() throws -> [ItemMeta]
    func secrets(id: UUID) throws -> [String: String]
    /// `secrets == nil` keeps the stored values.
    func save(_ meta: ItemMeta, secrets: [String: String]?) throws
    func delete(id: UUID) throws
}

/// Data-protection keychain, synchronizable through iCloud Keychain: one keychain entry per item.
/// account = item id, label = path, generic attribute = metadata JSON, data = secret values JSON.
/// Never shows dialogs, so CLI calls stay noninteractive. Needs the app's keychain-access-groups
/// entitlement (embedded Developer ID provisioning profile).
public struct SyncedItemStore: ItemStore {
    public static let accessGroup = "VXX45ZYNM8.dev.moinsen.secretariat.local"
    public let service: String
    public let accessGroup: String?
    public init(service: String, accessGroup: String? = SyncedItemStore.accessGroup) {
        self.service = service; self.accessGroup = accessGroup
    }
    private func base() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
    private func query(_ id: UUID) -> [String: Any] {
        var query = base(); query[kSecAttrAccount as String] = id.uuidString; return query
    }
    public func list() throws -> [ItemMeta] {
        var item = base()
        item[kSecReturnAttributes as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        return (result as? [[String: Any]] ?? []).compactMap { attributes in
            guard let data = attributes[kSecAttrGeneric as String] as? Data else { return nil }
            return try? JSONDecoder().decode(ItemMeta.self, from: data)
        }.sorted { $0.path < $1.path }
    }
    public func secrets(id: UUID) throws -> [String: String] {
        var item = query(id)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        try check(SecItemCopyMatching(item as CFDictionary, &result))
        guard let data = result as? Data, let values = try? JSONDecoder().decode([String: String].self, from: data) else {
            throw SecretariatError("The keychain entry has an invalid format.")
        }
        return values
    }
    public func save(_ meta: ItemMeta, secrets: [String: String]?) throws {
        var attributes: [String: Any] = [
            kSecAttrLabel as String: "Secretariat · \(meta.path)",
            kSecAttrGeneric as String: try JSONEncoder().encode(meta),
        ]
        if let secrets { attributes[kSecValueData as String] = try JSONEncoder().encode(secrets) }
        let status = SecItemUpdate(query(meta.id) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(meta.id)
            item.merge(attributes) { _, new in new }
            if secrets == nil { item[kSecValueData as String] = try JSONEncoder().encode([String: String]()) }
            // Synchronizable items must not be device-bound; available once the Mac was unlocked after boot.
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            try check(SecItemAdd(item as CFDictionary, nil))
        } else { try check(status) }
    }
    public func delete(id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecItemNotFound { throw CredentialError.notFound }
        throw CredentialError.unavailable(status)
    }
}
