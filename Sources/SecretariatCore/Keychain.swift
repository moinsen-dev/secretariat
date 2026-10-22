import Foundation
import Security
import LocalAuthentication

public enum CredentialError: LocalizedError, Sendable {
    case notFound
    public var errorDescription: String? {
        "Ein Schlüssel fehlt im macOS-Schlüsselbund. Bitte seinen Wert in Secretariat neu speichern."
    }
}

public protocol CredentialStore {
    func set(_ value: String, id: UUID, label: String) throws
    func read(id: UUID) throws -> String
    func delete(id: UUID) throws
}

public struct KeychainStore: CredentialStore {
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
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        return query
    }
    public func set(_ value: String, id: UUID, label: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrLabel as String: "Secretariat · \(label)"]
        let status = SecItemUpdate(query(id) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(id)
            item.merge(attributes) { _, value in value }
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
    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecItemNotFound { throw CredentialError.notFound }
        if status == errSecUserCanceled { throw SecretariatError("Der Schlüsselbund-Zugriff wurde abgebrochen. Es wurde kein Programm gestartet.") }
        if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            throw SecretariatError("Der macOS-Schlüsselbund erlaubt den Zugriff nicht. Bitte entsperren und erneut versuchen (\(status)).")
        }
        throw SecretariatError("Der macOS-Schlüsselbund meldet Fehler \(status). Bitte erneut versuchen.")
    }
}
