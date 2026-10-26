import Foundation

// `secretariat import`: moves named values from a dotenv file straight into the keychain. The values
// go file → keychain inside this process; output and errors carry names only, so an agent can migrate
// a project's .env without ever seeing a value.

public struct ImportedKey: Encodable, Sendable {
    public let variable: String
    public let key: String
    public let action: String   // "created" | "updated"
}
public struct ImportResult: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let imported: [ImportedKey]
    public let profile: String?
}

enum DotEnv {
    /// KEY=VALUE lines; `export ` prefix, comments, single/double quotes. The last assignment wins.
    static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let rest = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            result[key] = value(rest)
        }
        return result
    }

    private static func value(_ rest: String) -> String {
        if let quote = rest.first, quote == "\"" || quote == "'" {
            var out = "", escaped = false
            for ch in rest.dropFirst() {
                if escaped {
                    out.append(quote == "\"" ? (ch == "n" ? "\n" : ch == "t" ? "\t" : ch) : ch); escaped = false
                } else if ch == "\\" && quote == "\"" {
                    escaped = true
                } else if ch == quote {
                    return out
                } else {
                    out.append(ch)
                }
            }
            return out
        }
        if let hash = rest.range(of: " #") { return rest[..<hash.lowerBound].trimmingCharacters(in: .whitespaces) }
        return rest
    }
}

extension AgentService {
    /// Each request is VARIABLE or VARIABLE=KEYNAME (key name defaults to the variable). Everything is
    /// checked before the first write; an existing key is only overwritten with `replace`.
    public func importKeys(file: String, requests: [String], profile profileName: String?, replace: Bool) throws -> ImportResult {
        let path = (file as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: path), let text = String(data: data, encoding: .utf8) else {
            throw AgentError("file_unreadable", "Datei nicht lesbar: \(file)")
        }
        let env = DotEnv.parse(text)
        let pairs: [(variable: String, key: String)] = requests.map { request in
            guard let eq = request.firstIndex(of: "=") else { return (request, request) }
            return (String(request[..<eq]), String(request[request.index(after: eq)...]))
        }
        guard !pairs.isEmpty, pairs.allSatisfy({ !$0.variable.isEmpty && !$0.key.isEmpty }) else {
            throw AgentError("invalid_arguments", ProfileCommand.usage)
        }
        let missing = pairs.filter { (env[$0.variable] ?? "").isEmpty }.map(\.variable)
        guard missing.isEmpty else {
            throw AgentError("variable_missing", "In der Datei fehlt oder leer: \(missing.joined(separator: ", "))")
        }
        if let profileName { _ = try profile(named: profileName) }
        try vault.importSyncedKeys()
        let existing = try configuration.load().secrets
        let conflicts = pairs.filter { pair in existing.contains { $0.name == pair.key } }.map(\.key)
        guard replace || conflicts.isEmpty else {
            throw AgentError("key_exists", "Schlüssel gibt es schon: \(conflicts.joined(separator: ", ")). Überschreiben mit --replace.")
        }

        var imported: [ImportedKey] = []
        for pair in pairs {
            let value = env[pair.variable]!
            do {
                if let secret = try configuration.load().secrets.first(where: { $0.name == pair.key }) {
                    try vault.updateSecret(id: secret.id, name: secret.name, newValue: value)
                    imported.append(ImportedKey(variable: pair.variable, key: pair.key, action: "updated"))
                } else {
                    try vault.addSecret(name: pair.key, value: value)
                    imported.append(ImportedKey(variable: pair.variable, key: pair.key, action: "created"))
                }
            } catch let error as SecretariatError {
                throw AgentError("invalid_key", "\(pair.key): \(error.message)")
            }
            if let profileName { _ = try bind(profile: profileName, variable: pair.variable, key: pair.key) }
        }
        return ImportResult(imported: imported, profile: profileName)
    }
}
