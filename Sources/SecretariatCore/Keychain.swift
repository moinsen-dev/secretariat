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
