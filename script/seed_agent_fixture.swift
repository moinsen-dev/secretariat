// Disposable integration fixture only; never creates or locks a keychain.
import Foundation
import Security
import LocalAuthentication
import CryptoKit

@main enum Fixture {
    static func main() {
        do {
            let a = CommandLine.arguments
            var previous = DarwinBoolean(false)
            try check(SecKeychainGetUserInteractionAllowed(&previous))
            try check(SecKeychainSetUserInteractionAllowed(false))
            defer { _ = SecKeychainSetUserInteractionAllowed(previous.boolValue) }
            if a.count == 2, a[1] == "inventory" {
                var result: CFTypeRef?
                let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                    kSecAttrLabel as String: "Secretariat · Prüfung Agenten (temporär)",
                    kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                if status == errSecItemNotFound { print("[]"); return }
                try check(status)
                let items = (result as? [[String: Any]] ?? []).compactMap { item -> [String: String]? in
                    guard let service = item[kSecAttrService as String] as? String,
                          service.hasPrefix("dev.moinsen.secretariat.local.v1."),
                          let account = item[kSecAttrAccount as String] as? String else { return nil }
                    return ["service": service, "account": account]
                }
                print(String(decoding: try JSONSerialization.data(withJSONObject: items), as: UTF8.self)); return
            }
            if a.count == 3, a[1] == "service" {
                let path = URL(fileURLWithPath: a[2], isDirectory: true).standardizedFileURL.path
                let hash = SHA256.hash(data: Data(path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
                print("dev.moinsen.secretariat.local.v1." + hash); return
            }
            guard a.count == 6, ["seed", "seed-denied", "remove"].contains(a[1]), a[2].hasPrefix("dev.moinsen.secretariat.local.v1."), UUID(uuidString: a[3]) != nil, a[5].hasPrefix("artificial-agent-value-") else { throw NSError(domain: "fixture_arguments", code: 1) }
            let context = LAContext(); context.interactionNotAllowed = true
            var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: a[2], kSecAttrAccount as String: a[3],
                kSecAttrLabel as String: "Secretariat · Prüfung Agenten (temporär)",
                kSecAttrSynchronizable as String: false,
                kSecUseAuthenticationContext as String: context,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
            let status: OSStatus
            if a[1].hasPrefix("seed") {
                var application: SecTrustedApplication?
                var fixtureTool: SecTrustedApplication?
                let executable = URL(fileURLWithPath: a[4])
                let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                guard bundle.pathExtension == "app" else { throw NSError(domain: "fixture_app_bundle", code: 2) }
                try check(SecTrustedApplicationCreateFromPath(bundle.path, &application))
                try check(SecTrustedApplicationCreateFromPath(nil, &fixtureTool))
                var access: SecAccess?
                let trusted = a[1] == "seed-denied" ? [fixtureTool!] : [application!, fixtureTool!]
                try check(SecAccessCreate("Secretariat disposable acceptance" as CFString, trusted as CFArray, &access))
                query[kSecAttrAccess as String] = access
                query[kSecAttrLabel as String] = "Secretariat · Prüfung Agenten (temporär)"
                query[kSecValueData as String] = Data(a[5].utf8)
                status = SecItemAdd(query as CFDictionary, nil)
            } else { status = SecItemDelete(query as CFDictionary) }
            if status != errSecItemNotFound || a[1].hasPrefix("seed") { try check(status) }
            print("FIXTURE_OK")
        } catch {
            fputs("Fixture fehlgeschlagen: \((error as NSError).code)\n", stderr); exit(1)
        }
    }
    static func check(_ status: OSStatus) throws {
        if status != errSecSuccess { throw NSError(domain: "fixture_keychain", code: Int(status)) }
    }
}
