import Foundation
import CryptoKit
import Darwin

public struct AppPaths: Sendable {
    public let directory: URL
    public var configuration: URL { directory.appendingPathComponent("profiles.json") }
    public var auditLog: URL { directory.appendingPathComponent("audit.log") }
    /// Keychain service of the synced items. The real home shares one fixed service across all Macs
    /// (path and user differ per Mac); any other home (tests, fixtures) gets its own namespace.
    public var itemService: String {
        guard directory != AppPaths.defaultDirectory else { return "dev.moinsen.secretariat.items.v1" }
        let digest = SHA256.hash(data: Data(directory.standardizedFileURL.path.utf8))
        return "dev.moinsen.secretariat.items.test." + digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    public var isDefault: Bool { directory == AppPaths.defaultDirectory }
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SecretariatLocal", isDirectory: true).standardizedFileURL
    }
    /// The fleet's identifier registry (knowledge repo); only the real home exports into it.
    public var registryDirectory: URL? {
        guard isDefault else { return nil }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/registry", isDirectory: true)
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }
    public init(directory: URL? = nil) {
        if let directory { self.directory = directory.standardizedFileURL }
        else if let override = ProcessInfo.processInfo.environment["SECRETARIAT_HOME"], !override.isEmpty {
            self.directory = URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
        } else {
            self.directory = AppPaths.defaultDirectory
        }
    }
}

public struct ConfigurationStore {
    public let paths: AppPaths
    public init(paths: AppPaths = AppPaths()) { self.paths = paths }

    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: paths.configuration.path) else { return Configuration() }
        let data: Data
        do { data = try Data(contentsOf: paths.configuration) }
        catch { throw SecretariatError("Die lokale Konfiguration lässt sich nicht lesen. Sie wurde nicht verändert: \(paths.configuration.path)") }
        if let version = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["version"] as? Int, version != 2 {
            try Configuration.validateVersion(version)
        }
        do {
            let config = try JSONDecoder().decode(Configuration.self, from: data)
            try config.validate()
            return config
        } catch let error as SecretariatError { throw error }
        catch { throw SecretariatError("Die lokale Konfiguration lässt sich nicht lesen. Sie wurde nicht verändert: \(paths.configuration.path)") }
    }

    public func update(expectedRevision: Int? = nil, _ change: (inout Configuration) throws -> Void) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: paths.directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let lockURL = paths.directory.appendingPathComponent("configuration.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw SecretariatError("Die Konfiguration kann nicht zum Schreiben geöffnet werden.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw SecretariatError("Die Konfiguration wird gerade verwendet. Bitte erneut versuchen.") }
        defer { _ = flock(descriptor, LOCK_UN) }
        var configuration = try load()
        if let expectedRevision, expectedRevision != configuration.revision {
            throw SecretariatError("Die Daten wurden in einem anderen Fenster geändert. Bitte die Ansicht aktualisieren und erneut bearbeiten.")
        }
        try change(&configuration)
        try configuration.validate()
        configuration.revision += 1
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        let temporary = paths.directory.appendingPathComponent(".profiles-\(UUID().uuidString).tmp")
        defer { try? manager.removeItem(at: temporary) }
        guard manager.createFile(atPath: temporary.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            throw SecretariatError("Die Konfiguration konnte nicht gespeichert werden. Der bisherige Stand bleibt erhalten.")
        }
        guard rename(temporary.path, paths.configuration.path) == 0 else {
            throw SecretariatError("Die Konfiguration konnte nicht ersetzt werden. Der bisherige Stand bleibt erhalten.")
        }
    }
}

extension Configuration {
    static func validateVersion(_ version: Int) throws {
        var stale = Configuration(); stale.version = version
        try stale.validate()
    }
}

/// Append-only record of what used which value — names only, never values.
public struct AuditLog: Sendable {
    public let url: URL?
    public init(url: URL?) { self.url = url }
    public func record(_ action: String, _ details: [String: String] = [:]) {
        guard let url else { return }
        var entry = details; entry["at"] = ISO8601DateFormatter().string(from: Date()); entry["action"] = action
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd(); try? handle.write(contentsOf: line)
    }
    public func tail(_ count: Int) -> [String] {
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Array(text.split(separator: "\n").suffix(count).map(String.init))
    }
}

public struct Vault {
    public let configuration: ConfigurationStore
    public let items: any ItemStore
    public let audit: AuditLog
    public let registryDirectory: URL?
    public let expectedRevision: Int?
    public init(configuration: ConfigurationStore, items: any ItemStore, audit: AuditLog = AuditLog(url: nil),
                registryDirectory: URL? = nil, expectedRevision: Int? = nil) {
        self.configuration = configuration; self.items = items; self.audit = audit
        self.registryDirectory = registryDirectory; self.expectedRevision = expectedRevision
    }
    public init(paths: AppPaths = AppPaths(), expectedRevision: Int? = nil) {
        self.init(configuration: ConfigurationStore(paths: paths), items: SyncedItemStore(service: paths.itemService),
                  audit: AuditLog(url: paths.auditLog), registryDirectory: paths.registryDirectory, expectedRevision: expectedRevision)
    }

    // MARK: items

    public func list() throws -> [ItemMeta] { try items.list() }

    public func item(path: String) throws -> ItemMeta {
        let matches = try list().filter { $0.path == path }
        guard let first = matches.first else {
            throw AgentError("item_not_found", "Eintrag nicht gefunden: \(path). Vorhandene Einträge: secretariat items")
        }
        guard matches.count == 1 else {
            throw AgentError("ambiguous_path", "Zwei Einträge heißen \(path) (auf zwei Macs gleichzeitig angelegt). Bitte einen in der App umbenennen.")
        }
        return first
    }
    public func item(id: UUID) throws -> ItemMeta {
        guard let item = try list().first(where: { $0.id == id }) else {
            throw AgentError("item_not_found", "Ein zugeordneter Eintrag fehlt. Vielleicht wurde er auf einem anderen Mac gelöscht.")
        }
        return item
    }
    public func resolve(_ reference: FieldReference) throws -> (ItemMeta, ItemField) {
        let item = try item(path: reference.path)
        guard let field = item.field(reference.field) else {
            throw AgentError("field_not_found", "\(reference.path) hat kein Feld \(reference.field). Felder: \(item.fields.map(\.name).joined(separator: ", "))")
        }
        return (item, field)
    }

    /// Save metadata and, if given, the complete set of secret values. Identifier values stay in `meta`.
    public func save(_ meta: ItemMeta, secrets: [String: String]? = nil) throws {
        var meta = meta
        meta.path = meta.path.trimmingCharacters(in: .whitespacesAndNewlines)
        try meta.validate()
        if try list().contains(where: { $0.path.lowercased() == meta.path.lowercased() && $0.id != meta.id }) {
            throw AgentError("path_exists", "Es gibt schon einen Eintrag \(meta.path).")
        }
        if let secrets {
            let secretFields = Set(meta.fields.filter { $0.kind.isSecret }.map(\.name))
            guard Set(secrets.keys).isSubset(of: secretFields) else { throw SecretariatError("Werte passen nicht zu den Feldern des Eintrags.") }
            for (name, value) in secrets where value.utf8.contains(0) && meta.field(name)?.kind != .file {
                throw SecretariatError("Werte dürfen kein Nullzeichen enthalten (\(name)).")
            }
            if let old = try? items.secrets(id: meta.id), old != secrets { meta.rotated = today() }
            else if (try? items.secrets(id: meta.id)) == nil, !secrets.isEmpty { meta.rotated = today() }
        }
        try items.save(meta, secrets: secrets)
        audit.record("item.save", ["item": meta.path, "values": secrets == nil ? "unchanged" : "set"])
        exportRegistry()
    }

    /// Set one secret value (creating the item or field when missing). Used by import and the app.
    public func setValue(_ reference: FieldReference, value: String, kind: FieldKind = .secret, fileName: String? = nil,
                         itemKind: ItemKind = .api, source: String = "", replace: Bool = false) throws {
        guard kind.isSecret else { throw SecretariatError("Kennungen werden in der Beschreibung gesetzt, nicht als Wert.") }
        guard !value.isEmpty else { throw SecretariatError("Leere Werte werden nicht gespeichert (\(reference)).") }
        var meta = (try? item(path: reference.path)) ?? ItemMeta(path: reference.path, kind: itemKind, source: source)
        var values = (try? items.secrets(id: meta.id)) ?? [:]
        if let existing = meta.field(reference.field) {
            guard replace || values[reference.field] == nil else {
                throw AgentError("field_exists", "\(reference) hat schon einen Wert. Überschreiben mit --replace.")
            }
            guard existing.kind == kind || replace else {
                throw AgentError("field_kind", "\(reference) ist als \(existing.kind.title) angelegt.")
            }
            meta.fields.removeAll { $0.name == reference.field }
        }
        meta.fields.append(ItemField(name: reference.field, kind: kind, fileName: fileName))
        if !source.isEmpty && meta.source.isEmpty { meta.source = source }
        values[reference.field] = value
        try save(meta, secrets: values)
    }

    public func rename(path: String, to newPath: String) throws -> ItemMeta {
        var meta = try item(path: path)
        meta.path = newPath
        try save(meta)
        return meta
    }

    /// Delete an item; refused while a profile or target of this Mac uses it.
    public func delete(id: UUID) throws {
        let config = try configuration.load()
        let users = config.profiles.filter { $0.bindings.contains { $0.itemID == id } }.map(\.name)
            + config.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "Ziel \($0.name)" }
        guard users.isEmpty else { throw SecretariatError("Dieser Eintrag wird noch verwendet: \(users.joined(separator: ", ")). Bitte zuerst die Zuordnungen entfernen.") }
        let path = (try? item(id: id).path) ?? id.uuidString
        try items.delete(id: id)
        audit.record("item.delete", ["item": path])
        exportRegistry()
    }

    /// Value of a field for a program. Identifiers come from metadata, personal fields never leave the app.
    public func value(itemID: UUID, field name: String) throws -> String {
        let meta = try item(id: itemID)
        guard let field = meta.field(name) else { throw AgentError("field_not_found", "\(meta.path) hat kein Feld \(name).") }
        switch field.kind {
        case .identifier: return field.value ?? ""
        case .personal: throw AgentError("personal_field", "\(meta.path)/\(name) ist nur für dich bestimmt und wird an kein Programm weitergegeben.")
        case .secret, .file:
            guard let value = try items.secrets(id: itemID)[name], !value.isEmpty else { throw CredentialError.notFound }
            return value
        }
    }
    /// For the app only (copy, reveal, export file).
    public func personalValue(itemID: UUID, field name: String) throws -> String? {
        try items.secrets(id: itemID)[name]
    }

    /// Move a value between fields (also across items) without it leaving this process.
    public func moveField(from source: FieldReference, to destination: FieldReference, replace: Bool = false) throws {
        let (fromItem, field) = try resolve(source)
        if field.kind == .identifier {
            var target = (try? item(path: destination.path)) ?? ItemMeta(path: destination.path, kind: fromItem.kind, source: fromItem.source)
            if target.field(destination.field) != nil {
                guard replace else { throw AgentError("field_exists", "\(destination) gibt es schon. Überschreiben mit --replace.") }
                target.fields.removeAll { $0.name == destination.field }
            }
            target.fields.append(ItemField(name: destination.field, kind: .identifier, value: field.value))
            try save(target)
        } else {
            let value = try items.secrets(id: fromItem.id)[source.field] ?? ""
            try setValue(destination, value: value, kind: field.kind, fileName: field.fileName, itemKind: fromItem.kind,
                         source: fromItem.source, replace: replace)
        }
        // Remove the source field; drop the item when nothing is left.
        var updated = try item(id: fromItem.id)
        var values = try items.secrets(id: fromItem.id)
        updated.fields.removeAll { $0.name == source.field }; values.removeValue(forKey: source.field)
        let destinationItem = try item(path: destination.path)
        try configuration.update { config in
            func rebind(_ bindings: inout [Binding]) {
                for i in bindings.indices where bindings[i].itemID == fromItem.id && bindings[i].field == source.field {
                    bindings[i].itemID = destinationItem.id; bindings[i].field = destination.field
                }
            }
            for p in config.profiles.indices { rebind(&config.profiles[p].bindings) }
            for t in config.targets.indices { rebind(&config.targets[t].bindings) }
        }
        if updated.fields.isEmpty && updated.id != destinationItem.id { try items.delete(id: updated.id) }
        else if updated.id != destinationItem.id { try save(updated, secrets: values) }
        audit.record("field.move", ["from": source.description, "to": destination.description])
        exportRegistry()
    }

    // MARK: profiles and targets

    public func saveProfile(_ profile: Profile) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: profile.directory, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw SecretariatError("Der gewählte Projektordner existiert nicht. Bitte erneut auswählen.")
        }
        try configuration.update(expectedRevision: expectedRevision) { config in
            if let index = config.profiles.firstIndex(where: { $0.id == profile.id }) { config.profiles[index] = profile }
            else { config.profiles.append(profile) }
        }
    }
    public func deleteProfile(id: UUID) throws {
        try configuration.update(expectedRevision: expectedRevision) { $0.profiles.removeAll { $0.id == id } }
    }
    public func saveTarget(_ target: Target) throws {
        try configuration.update(expectedRevision: expectedRevision) { config in
            if let index = config.targets.firstIndex(where: { $0.id == target.id }) { config.targets[index] = target }
            else { config.targets.append(target) }
        }
    }
    public func deleteTarget(id: UUID) throws {
        try configuration.update(expectedRevision: expectedRevision) { $0.targets.removeAll { $0.id == id } }
    }

    public func fingerprint(_ value: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + "\u{0}" + value).utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: run

    public func preparedLaunch(name: String, arguments: [String], inheritedEnvironment: [String: String]) throws -> PreparedLaunch {
        let config = try configuration.load()
        guard let profile = config.profiles.first(where: { $0.name == name }) else {
            throw SecretariatError("Profil nicht gefunden. Bitte in Secretariat ein Profil anlegen oder ‚secretariat profiles‘ verwenden.")
        }
        guard !arguments.isEmpty, !arguments[0].isEmpty else { throw SecretariatError("Bitte nach -- ein Programm angeben.") }
        var environment = inheritedEnvironment
        var files: [PreparedLaunch.File] = []
        for binding in profile.bindings {
            let meta = try item(id: binding.itemID)
            let value = try value(itemID: binding.itemID, field: binding.field)
            if meta.field(binding.field)?.kind == .file {
                guard let data = Data(base64Encoded: value) else { throw SecretariatError("Die Datei in \(meta.path)/\(binding.field) ist beschädigt.") }
                files.append(.init(variable: binding.variable, name: meta.field(binding.field)?.fileName ?? binding.field, data: data))
            } else {
                guard !value.utf8.contains(0) else { throw SecretariatError("Ein Wert enthält ein für Umgebungsvariablen unzulässiges Nullzeichen.") }
                environment[binding.variable] = value
            }
        }
        audit.record("run", ["profile": name, "variables": profile.bindings.map(\.variable).sorted().joined(separator: ",")])
        return PreparedLaunch(directory: profile.directory, arguments: arguments, environment: environment, files: files)
    }

    // MARK: registry

    /// Writes identifiers (and names of secret fields) to the fleet registry. Deterministic, no timestamps,
    /// so every Mac produces the same file.
    public func exportRegistry() {
        guard let registryDirectory, let all = try? list() else { return }
        let text = RegistryExport.render(all)
        let url = registryDirectory.appendingPathComponent("accounts.toml")
        if (try? String(contentsOf: url, encoding: .utf8)) != text { try? text.write(to: url, atomically: true, encoding: .utf8) }
    }
}

public enum RegistryExport {
    static func q(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default: out.unicodeScalars.append(c)
            }
        }
        return out + "\""
    }
    public static func render(_ items: [ItemMeta]) -> String {
        var lines = ["# GENERATED by Secretariat from its items — do not edit here.",
                     "# Change values in the Secretariat app or with `secretariat item …`; every Mac rewrites this file.",
                     "# Identifiers only. \"secret:<path>/<field>\" names a Secretariat field; its value never appears here.", ""]
        for item in items.sorted(by: { $0.path < $1.path }) {
            lines.append("[\(q(item.path))]")
            lines.append("_kind = \(q(item.kind.rawValue))")
            if !item.source.isEmpty { lines.append("_source = \(q(item.source))") }
            if let expires = item.expires { lines.append("_expires = \(q(expires))") }
            if let rotated = item.rotated { lines.append("_rotated = \(q(rotated))") }
            for field in item.fields.sorted(by: { $0.name < $1.name }) {
                lines.append("\(field.name) = \(q(field.kind == .identifier ? field.value ?? "" : "secret:\(item.path)/\(field.name)"))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
