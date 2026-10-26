// Acceptance helper for 0.3 sync tests. Built as an app bundle with Secretariat's identifier,
// entitlements and provisioning profile (script/build_sync_fixture.sh), so it can reach the synced
// keychain items of the app's access group. It only ever touches TEST namespaces
// ("dev.moinsen.secretariat.keys.test.*") — never the real synced keys or the login keychain.
//   sync-fixture list   SERVICE            → JSON [{account,label}] (no values)
//   sync-fixture delete SERVICE ACCOUNT    → removes one test item (propagates via iCloud)
import Foundation
import Security

@main
enum SyncFixture {
    static let accessGroup = "VXX45ZYNM8.dev.moinsen.secretariat.local"
    static func main() {
        let a = CommandLine.arguments
        guard a.count >= 3, a[2].hasPrefix("dev.moinsen.secretariat.keys.test.") else {
            fputs("only test namespaces (dev.moinsen.secretariat.keys.test.*)\n", stderr); exit(2)
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: a[2],
            kSecUseDataProtectionKeychain as String: true, kSecAttrSynchronizable as String: true,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        switch (a[1], a.count) {
        case ("list", 3):
            query[kSecReturnAttributes as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitAll
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess || status == errSecItemNotFound else { fputs("status \(status)\n", stderr); exit(1) }
            let items = (result as? [[String: Any]] ?? []).map {
                ["account": $0[kSecAttrAccount as String] as? String ?? "", "label": $0[kSecAttrLabel as String] as? String ?? ""]
            }
            print(String(decoding: try! JSONSerialization.data(withJSONObject: items), as: UTF8.self))
        case ("delete", 4):
            query[kSecAttrAccount as String] = a[3]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { fputs("status \(status)\n", stderr); exit(1) }
            print(status == errSecSuccess ? "DELETED" : "NOT_FOUND")
        default:
            fputs("usage: sync-fixture list SERVICE | delete SERVICE ACCOUNT\n", stderr); exit(2)
        }
    }
}
