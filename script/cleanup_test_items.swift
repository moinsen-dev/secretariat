// Removes leftover test entries (services dev.moinsen.secretariat.<items|templates|license|screenshots|backup>.test.*,
// synced and this-Mac-only) from the keychain,
// e.g. after an interrupted acceptance run. Never touches the real namespace. Prints services only.
// Build: script/build_helper.sh cleanup_test_items
import Foundation
import Security

@main
enum CleanupTestItems {
    static func main() {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecUseDataProtectionKeychain as String: true,
                                   kSecAttrSynchronizable as String: kSecAttrSynchronizableAny, kSecAttrAccessGroup as String: "VXX45ZYNM8.dev.moinsen.secretariat.local"]
        var query = base; query[kSecReturnAttributes as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { print("0 Testeinträge"); return }
        var removed = 0
        for a in result as? [[String: Any]] ?? [] {
            guard let service = a[kSecAttrService as String] as? String, service.hasPrefix("dev.moinsen.secretariat."), service.contains(".test."),
                  let account = a[kSecAttrAccount as String] as? String else { continue }
            var item = base; item[kSecAttrService as String] = service; item[kSecAttrAccount as String] = account
            if SecItemDelete(item as CFDictionary) == errSecSuccess { removed += 1; print("entfernt: \(service)") }
        }
        print("\(removed) Testeinträge entfernt")
    }
}
