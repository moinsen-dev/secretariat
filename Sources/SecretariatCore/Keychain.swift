import Foundation
import Security

public enum CredentialError: LocalizedError, Sendable {
    case notFound
    case unavailable(Int32)
    public var errorDescription: String? {
        switch self {
        case .notFound: "Ein Schlüssel fehlt im macOS-Schlüsselbund. Bitte seinen Wert in Secretariat neu speichern."
        case .unavailable(let status): "Der macOS-Schlüsselbund erlaubt den Zugriff nicht (\(status)). Bitte den Zugriff in Secretariat prüfen."
        }
    }
}

public protocol CredentialStore {
    func set(_ value: String, id: UUID, label: String) throws
    func read(id: UUID) throws -> String
    func delete(id: UUID) throws
}

public struct KeychainStore: CredentialStore {
    private static let interactionLock = NSRecursiveLock()
    public let service: String
    public let allowInteraction: Bool
    public init(service: String, allowInteraction: Bool = true) {
        self.service = service; self.allowInteraction = allowInteraction
    }
    private func query(_ id: UUID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: false
        ]
        if !allowInteraction {
            // This store uses the legacy login keychain (SecAccess), not the
            // data-protection keychain. Enforce its Security-framework UI policy
            // directly; no LocalAuthentication context is needed for this query.
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        return query
    }
    public func set(_ value: String, id: UUID, label: String) throws {
        try withInteractionPolicy { try setItem(value, id: id, label: label) }
    }
    private func setItem(_ value: String, id: UUID, label: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrLabel as String: "Secretariat · \(label)"]
        let status = SecItemUpdate(query(id) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(id)
            item.merge(attributes) { _, value in value }
            try check(SecItemAdd(item as CFDictionary, nil))
        } else { try check(status) }
    }
    public func read(id: UUID) throws -> String {
        try withInteractionPolicy { try readItem(id: id) }
    }
    private func readItem(id: UUID) throws -> String {
        var item = query(id)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        try check(SecItemCopyMatching(item as CFDictionary, &result))
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw SecretariatError("Der Schlüsselbund-Eintrag hat ein ungültiges Format.")
        }
        return value
    }
    public func delete(id: UUID) throws {
        try withInteractionPolicy { try deleteItem(id: id) }
    }
    private func deleteItem(id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    private func withInteractionPolicy<T>(_ operation: () throws -> T) throws -> T {
        // The SecItem UI flags are ignored by file-based keychains (FB16959400).
        // This legacy policy is local to this process. Serialize every store call
        // so a GUI operation cannot overlap another call's temporary no-UI scope.
        Self.interactionLock.lock(); defer { Self.interactionLock.unlock() }
        guard !allowInteraction else { return try operation() }
        var previous = DarwinBoolean(false)
        try check(SecKeychainGetUserInteractionAllowed(&previous))
        try check(SecKeychainSetUserInteractionAllowed(false))
        defer { _ = SecKeychainSetUserInteractionAllowed(previous.boolValue) }
        return try operation()
    }
    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecItemNotFound { throw CredentialError.notFound }
        throw CredentialError.unavailable(status)
    }
}

// MARK: - 0.3: keys shared across Uli's Macs through iCloud Keychain

public struct SyncedKeyEntry: Equatable, Sendable {
    public let id: UUID
    public let name: String
}

/// A store that can enumerate its key names (never values).
public protocol SyncedKeyListing {
    func syncedKeys() throws -> [SyncedKeyEntry]
}

/// Data-protection keychain, synchronizable through iCloud Keychain. The key name travels in the
/// item's label, the id in its account, so another Mac can list and use the key. This keychain never
/// shows authentication dialogs, so CLI calls stay noninteractive. Needs the app's
/// keychain-access-groups entitlement (embedded Developer ID provisioning profile).
public struct SyncedKeychainStore: CredentialStore, SyncedKeyListing {
    public static let accessGroup = "VXX45ZYNM8.dev.moinsen.secretariat.local"
    static let labelPrefix = "Secretariat · "
    public let service: String
    public let accessGroup: String?
    public init(service: String, accessGroup: String? = SyncedKeychainStore.accessGroup) {
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
    public func set(_ value: String, id: UUID, label: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrLabel as String: Self.labelPrefix + label]
        let status = SecItemUpdate(query(id) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(id)
            item.merge(attributes) { _, new in new }
            // Synchronizable items must not be device-bound; available once the Mac was unlocked after boot.
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            try check(SecItemAdd(item as CFDictionary, nil))
        } else { try check(status) }
    }
    public func read(id: UUID) throws -> String {
        var item = query(id)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        try check(SecItemCopyMatching(item as CFDictionary, &result))
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw SecretariatError("Der Schlüsselbund-Eintrag hat ein ungültiges Format.")
        }
        return value
    }
    public func delete(id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    public func syncedKeys() throws -> [SyncedKeyEntry] {
        var item = base()
        item[kSecReturnAttributes as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        return (result as? [[String: Any]] ?? []).compactMap { attributes in
            guard let account = attributes[kSecAttrAccount as String] as? String, let id = UUID(uuidString: account) else { return nil }
            let label = attributes[kSecAttrLabel as String] as? String ?? ""
            let name = label.hasPrefix(Self.labelPrefix) ? String(label.dropFirst(Self.labelPrefix.count)) : label
            return SyncedKeyEntry(id: id, name: name.isEmpty ? "Schlüssel \(account.prefix(8))" : name)
        }.sorted { $0.name < $1.name }
    }
    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecItemNotFound { throw CredentialError.notFound }
        throw CredentialError.unavailable(status)
    }
}

/// New values go to the synced store; values written by 0.1/0.2 are still read from the local login
/// keychain until migrated. Without the entitlement (ad-hoc builds) everything stays local.
public struct FleetCredentialStore: CredentialStore, SyncedKeyListing {
    public let synced: any CredentialStore & SyncedKeyListing
    public let legacy: any CredentialStore
    public init(synced: any CredentialStore & SyncedKeyListing, legacy: any CredentialStore) {
        self.synced = synced; self.legacy = legacy
    }
    private func syncUnavailable(_ error: Error) -> Bool {
        if case CredentialError.unavailable(let status) = error { return status == errSecMissingEntitlement }
        return false
    }
    public func set(_ value: String, id: UUID, label: String) throws {
        do { try synced.set(value, id: id, label: label) }
        catch where syncUnavailable(error) { return try legacy.set(value, id: id, label: label) }
        try? legacy.delete(id: id)
    }
    public func read(id: UUID) throws -> String {
        do { return try synced.read(id: id) }
        catch CredentialError.notFound { return try legacy.read(id: id) }
        catch where syncUnavailable(error) { return try legacy.read(id: id) }
    }
    public func delete(id: UUID) throws {
        do { try synced.delete(id: id) } catch where syncUnavailable(error) {}
        try legacy.delete(id: id)
    }
    public func syncedKeys() throws -> [SyncedKeyEntry] {
        do { return try synced.syncedKeys() } catch where syncUnavailable(error) { return [] }
    }
    /// Copy a value from the local login keychain into the synced store, verify it, then drop the local copy.
    /// Returns false when there was nothing to migrate. A failure leaves the local value in place.
    @discardableResult public func migrate(id: UUID, label: String) throws -> Bool {
        if (try? synced.read(id: id)) != nil { return false }
        let value: String
        do { value = try legacy.read(id: id) } catch CredentialError.notFound { return false }
        try synced.set(value, id: id, label: label)
        guard try synced.read(id: id) == value else {
            try? synced.delete(id: id)
            throw SecretariatError("Die Übernahme in den iCloud-Schlüsselbund ließ sich nicht bestätigen. Der lokale Wert bleibt erhalten.")
        }
        try legacy.delete(id: id)
        return true
    }
}
