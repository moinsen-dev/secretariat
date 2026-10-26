// One-time move from Secretariat 0.x (one synced keychain entry per key, profiles.json v1) to 1.0
// (one synced entry per item with fields, profiles.json v2). Built by script/build_migrate_v1.sh
// into an app bundle with Secretariat's identifier and entitlements; compiled together with
// SecretariatCore's sources. Prints names only, never values.
//   migrate-v1            convert keys into items (idempotent, same item ids on every Mac) and this Mac's profiles.json
//   migrate-v1 --delete-old   additionally remove the old 0.x key entries (run once, after every Mac converted)
import Foundation
import Security
import CryptoKit

@main
enum MigrateV1 {
    static let oldService = "dev.moinsen.secretariat.keys.v1"

    struct OldKey { let id: UUID; let name: String; let value: String? }

    /// 0.x key name → item path, field and kind. Client id/secret pairs become one token item.
    static func target(_ name: String) -> (path: String, field: String, kind: FieldKind) {
        for (suffix, field, kind) in [("-client-id", "client_id", FieldKind.identifier), ("-client-secret", "client_secret", .secret)] where name.hasSuffix(suffix) {
            return (String(name.dropLast(suffix.count)), field, kind)
        }
        let path = name.replacingOccurrences(of: #"[^A-Za-z0-9._@/-]+"#, with: "-", options: .regularExpression)
        return (path, "value", .secret)
    }
    /// Same path → same item id on every Mac, so parallel migrations converge on one item.
    static func itemID(_ path: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(("secretariat-item:" + path).utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func oldQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: oldService,
         kSecUseDataProtectionKeychain as String: true, kSecAttrSynchronizable as String: true,
         kSecAttrAccessGroup as String: SyncedItemStore.accessGroup]
    }
    static func oldKeys() -> [OldKey] {
        var q = oldQuery(); q[kSecReturnAttributes as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess else { return [] }
        return (result as? [[String: Any]] ?? []).compactMap { a in
            guard let account = a[kSecAttrAccount as String] as? String, let id = UUID(uuidString: account) else { return nil }
            let label = (a[kSecAttrLabel as String] as? String ?? "").replacingOccurrences(of: "Secretariat · ", with: "")
            var r = oldQuery(); r[kSecAttrAccount as String] = account; r[kSecReturnData as String] = true; r[kSecMatchLimit as String] = kSecMatchLimitOne
            var data: CFTypeRef?
            let value = SecItemCopyMatching(r as CFDictionary, &data) == errSecSuccess ? (data as? Data).flatMap { String(data: $0, encoding: .utf8) } : nil
            return OldKey(id: id, name: label, value: value)
        }
    }

    static func main() {
        let deleteOld = CommandLine.arguments.contains("--delete-old")
        let paths = AppPaths()
        let vault = Vault(paths: paths)
        do {
            // 1. keys → items
            let keys = oldKeys()
            for key in keys {
                guard let value = key.value, !value.isEmpty else { print("übersprungen (kein Wert auf diesem Mac): \(key.name)"); continue }
                let t = target(key.name)
                var meta = (try? vault.item(id: itemID(t.path))) ?? ItemMeta(id: itemID(t.path), path: t.path, kind: t.field == "value" ? .api : .token,
                                                                          source: "übernommen aus Secretariat 0.x")
                var secrets = (try? vault.items.secrets(id: meta.id)) ?? [:]
                meta.fields.removeAll { $0.name == t.field }
                if t.kind == .identifier { meta.fields.append(ItemField(name: t.field, kind: .identifier, value: value)) }
                else { meta.fields.append(ItemField(name: t.field, kind: t.kind)); secrets[t.field] = value }
                meta.fields.sort { $0.name < $1.name }
                try vault.items.save(meta, secrets: secrets)
                guard try vault.value(itemID: meta.id, field: t.field) == value else { throw SecretariatError("Prüfung fehlgeschlagen: \(key.name)") }
                print("\(key.name) → \(t.path)/\(t.field) (\(t.kind.title))")
            }
            // 2. profiles.json v1 → v2 (names from this Mac's v1 file; no keychain access needed)
            let url = paths.configuration
            if let data = try? Data(contentsOf: url), let old = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               (old["version"] as? Int) == 1 {
                let names = Dictionary(uniqueKeysWithValues: (old["secrets"] as? [[String: Any]] ?? []).compactMap { s -> (String, String)? in
                    guard let id = s["id"] as? String, let name = s["name"] as? String else { return nil }; return (id, name)
                })
                var config = Configuration(); config.revision = (old["revision"] as? Int ?? 0) + 1
                for p in old["profiles"] as? [[String: Any]] ?? [] {
                    let bindings = (p["bindings"] as? [[String: Any]] ?? []).compactMap { b -> Binding? in
                        guard let variable = b["variable"] as? String, let secretID = b["secretID"] as? String, let name = names[secretID] else { return nil }
                        let t = target(name)
                        return Binding(variable: variable, itemID: itemID(t.path), field: t.field)
                    }
                    config.profiles.append(Profile(id: UUID(uuidString: p["id"] as? String ?? "") ?? UUID(), name: p["name"] as? String ?? "",
                                                   directory: p["directory"] as? String ?? "", command: p["command"] as? String ?? "", bindings: bindings))
                }
                try config.validate()
                try data.write(to: paths.directory.appendingPathComponent("profiles.v1-backup.json"))
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(config).write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                print("profiles.json → Version 2 (\(config.profiles.count) Profile, Sicherung profiles.v1-backup.json)")
            } else { print("profiles.json: schon Version 2 oder nicht vorhanden") }
            // 3. old entries
            if deleteOld {
                for key in keys { var q = oldQuery(); q[kSecAttrAccount as String] = key.id.uuidString; SecItemDelete(q as CFDictionary) }
                print("\(keys.count) alte Einträge entfernt")
            }
            vault.exportRegistry()
            print("Einträge jetzt: \(try vault.list().map(\.path).joined(separator: ", "))")
        } catch {
            fputs("Migration fehlgeschlagen: \(error.localizedDescription)\n", stderr); exit(1)
        }
    }
}
