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
        // Hash a canonical path: macOS drops "/private" from /private/tmp paths only once the folder exists,
        // which would switch test namespaces between the first and the second write.
        let digest = SHA256.hash(data: Data(AppPaths.canonical(directory.path).utf8))
        return "dev.moinsen.secretariat.items.test." + digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
    public var templateService: String { itemService.replacingOccurrences(of: ".items.", with: ".templates.") }
    public var licenseService: String { itemService.replacingOccurrences(of: ".items.", with: ".license.") }
    public var screenshotKeyService: String { itemService.replacingOccurrences(of: ".items.", with: ".screenshots.") }
    public var isDefault: Bool { directory == AppPaths.defaultDirectory }
    static func canonical(_ path: String) -> String {
        for root in ["/tmp/", "/var/", "/etc/"] where path.hasPrefix("/private" + root) { return String(path.dropFirst(8)) }
        return path
    }
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
        catch { throw SecretariatError("The local configuration can't be read. It was not changed: \(paths.configuration.path)") }
        if let version = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["version"] as? Int, version != 2 {
            try Configuration.validateVersion(version)
        }
        do {
            let config = try JSONDecoder().decode(Configuration.self, from: data)
            try config.validate()
            return config
        } catch let error as SecretariatError { throw error }
        catch { throw SecretariatError("The local configuration can't be read. It was not changed: \(paths.configuration.path)") }
    }

    public func update(expectedRevision: Int? = nil, _ change: (inout Configuration) throws -> Void) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: paths.directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let lockURL = paths.directory.appendingPathComponent("configuration.lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw SecretariatError("The configuration can't be opened for writing.") }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw SecretariatError("The configuration is in use right now. Please try again.") }
        defer { _ = flock(descriptor, LOCK_UN) }
        var configuration = try load()
        if let expectedRevision, expectedRevision != configuration.revision {
            throw SecretariatError("The data was changed in another window. Please refresh the view and edit again.")
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
            throw SecretariatError("The configuration could not be saved. The previous state is kept.")
        }
        guard rename(temporary.path, paths.configuration.path) == 0 else {
            throw SecretariatError("The configuration could not be replaced. The previous state is kept.")
        }
    }
}

extension Configuration {
    static func validateVersion(_ version: Int) throws {
        var stale = Configuration(); stale.version = version
        try stale.validate()
    }
}

/// Record of who used what, on this Mac — names only, never values. Appending and pruning share one lock file,
/// so an entry written while old ones are removed is never lost.
public struct AuditLog: Sendable {
    public let url: URL?
    /// Fixed origin for tests; otherwise each entry takes `Origin.current`.
    public let origin: String?
    public init(url: URL?, origin: String? = nil) { self.url = url; self.origin = origin }

    public func record(_ action: String, _ details: [String: String] = [:], at date: Date = Date()) {
        guard let url else { return }
        var entry = details
        entry["at"] = ISO8601DateFormatter().string(from: date); entry["action"] = action; entry["via"] = origin ?? Origin.current
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        try? locked {
            let descriptor = open(url.path, O_WRONLY | O_APPEND | O_CREAT | O_NOFOLLOW, 0o600)
            guard descriptor >= 0 else { return }
            defer { close(descriptor) }
            _ = line.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
        }
    }
    public func tail(_ count: Int) -> [String] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return Array(String(decoding: data, as: UTF8.self).split(separator: "\n").suffix(count).map(String.init))
    }
    /// Every readable entry; reading never changes the file. A damaged byte only costs its own line.
    public func entries() -> [HistoryEntry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return History.parse(data)
    }
    /// Removes entries older than `cutoff`; unreadable lines are kept. Returns how many went.
    /// Lines are dated by a byte search, so the check on every CLI call stays cheap; the file is only rewritten when something goes.
    @discardableResult public func prune(olderThan cutoff: Date) throws -> Int {
        guard let url else { return 0 }
        var removed = 0
        try locked {
            guard let data = try? Data(contentsOf: url) else { return }
            var kept: [Data.SubSequence] = []
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                if let date = History.lineDate(line), date < cutoff { removed += 1 } else { kept.append(line) }
            }
            guard removed > 0 else { return }
            let temporary = url.deletingLastPathComponent().appendingPathComponent(".audit-\(UUID().uuidString).tmp")
            defer { try? FileManager.default.removeItem(at: temporary) }
            var output = Data()
            for line in kept { output.append(contentsOf: line); output.append(0x0A) }
            guard FileManager.default.createFile(atPath: temporary.path, contents: output, attributes: [.posixPermissions: 0o600]),
                  rename(temporary.path, url.path) == 0 else { throw SecretariatError("The history could not be shortened. It is unchanged.") }
        }
        return removed
    }

    private func locked(_ body: () throws -> Void) throws {
        guard let url else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        let descriptor = open(url.deletingLastPathComponent().appendingPathComponent("audit.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { return }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { return }
        defer { _ = flock(descriptor, LOCK_UN) }
        try body()
    }
}

public struct Vault {
    public let configuration: ConfigurationStore
    public let items: any ItemStore
    public let templates: any TemplateStore
    public let licenses: any LicenseStore
    public let approver: any Approver
    public let audit: AuditLog
    public let registryDirectory: URL?
    public let expectedRevision: Int?
    public init(configuration: ConfigurationStore, items: any ItemStore, templates: any TemplateStore = InMemoryTemplateStore(),
                licenses: any LicenseStore = InMemoryLicenseStore(), approver: any Approver = DeviceOwnerApprover(),
                audit: AuditLog = AuditLog(url: nil), registryDirectory: URL? = nil, expectedRevision: Int? = nil) {
        self.configuration = configuration; self.items = items; self.templates = templates; self.licenses = licenses; self.approver = approver; self.audit = audit
        self.registryDirectory = registryDirectory; self.expectedRevision = expectedRevision
    }
    public init(paths: AppPaths = AppPaths(), expectedRevision: Int? = nil) {
        self.init(configuration: ConfigurationStore(paths: paths), items: SyncedItemStore(service: paths.itemService),
                  templates: SyncedTemplateStore(service: paths.templateService), licenses: SyncedLicenseStore(service: paths.licenseService), audit: AuditLog(url: paths.auditLog), registryDirectory: paths.registryDirectory, expectedRevision: expectedRevision)
    }

    // MARK: templates

    public var licensing: Licensing { Licensing(store: licenses) }

    public func catalog() -> TemplateCatalog { TemplateCatalog(stored: (try? templates.list()) ?? []) }

    public func saveTemplate(_ template: Template) throws {
        var template = template
        template.title = template.title.trimmingCharacters(in: .whitespaces)
        try template.validate()
        try templates.save(template)
        audit.record("template.save", ["template": template.id])
        exportRegistry()
    }
    /// Own templates are deleted; built-ins are hidden on every Mac (`resetTemplate` brings them back).
    /// Items keep their fields either way and show plain field names.
    public func deleteTemplate(id: String) throws {
        if let builtin = Template.builtins.first(where: { $0.id == id }) {
            var marker = builtin; marker.hidden = true; try templates.save(marker)
        } else { try templates.delete(id: id) }
        audit.record("template.delete", ["template": id])
        exportRegistry()
    }
    public func resetTemplate(id: String) throws {
        try templates.delete(id: id)
        audit.record("template.reset", ["template": id])
        exportRegistry()
    }

    // MARK: items

    public func list() throws -> [ItemMeta] { try items.list() }

    /// Agent Guard: one Touch ID / password prompt for every approval item a program is about to get.
    public func requireApproval(_ itemIDs: [UUID], for purpose: String) throws {
        let needing = Set(itemIDs).compactMap { try? item(id: $0) }.filter(\.needsApproval).map(\.path).sorted()
        guard !needing.isEmpty else { return }
        try approver.approve("\(purpose) wants to use \(needing.joined(separator: ", "))")
        audit.record("approval", ["items": needing.joined(separator: ","), "purpose": purpose])
    }

    public func item(path: String) throws -> ItemMeta {
        let matches = try list().filter { $0.path == path }
        guard let first = matches.first else {
            throw AgentError("item_not_found", "Item not found: \(path). Existing items: secretariat items")
        }
        guard matches.count == 1 else {
            throw AgentError("ambiguous_path", "Two items are named \(path) (created on two Macs at the same time). Please rename one in the app.")
        }
        return first
    }
    public func item(id: UUID) throws -> ItemMeta {
        guard let item = try list().first(where: { $0.id == id }) else {
            throw AgentError("item_not_found", "A bound item is missing. It may have been deleted on another Mac.")
        }
        return item
    }
    public func resolve(_ reference: FieldReference) throws -> (ItemMeta, ItemField) {
        let item = try item(path: reference.path)
        guard let field = item.field(reference.field) else {
            throw AgentError("field_not_found", "\(reference.path) has no field \(reference.field). Fields: \(item.fields.map(\.name).joined(separator: ", "))")
        }
        return (item, field)
    }

    /// Save metadata and, if given, the complete set of secret values. Identifier values stay in `meta`.
    public func save(_ meta: ItemMeta, secrets: [String: String]? = nil) throws {
        var meta = meta
        meta.path = meta.path.trimmingCharacters(in: .whitespacesAndNewlines)
        try meta.validate()
        if try list().contains(where: { $0.path.lowercased() == meta.path.lowercased() && $0.id != meta.id }) {
            throw AgentError("path_exists", "An item \(meta.path) already exists.")
        }
        if let secrets {
            let secretFields = Set(meta.fields.filter { $0.kind.isSecret }.map(\.name))
            guard Set(secrets.keys).isSubset(of: secretFields) else { throw SecretariatError("The values don't match the item's fields.") }
            for (name, value) in secrets where value.utf8.contains(0) && meta.field(name)?.kind != .file {
                throw SecretariatError("Values must not contain a null character (\(name)).")
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
                         itemKind: String = "api", source: String = "", replace: Bool = false) throws {
        guard kind.isSecret else { throw SecretariatError("Identifiers are set in the description, not as a value.") }
        guard !value.isEmpty else { throw SecretariatError("Empty values are not stored (\(reference)).") }
        var meta = (try? item(path: reference.path)) ?? ItemMeta(path: reference.path, kind: itemKind, source: source)
        var values = (try? items.secrets(id: meta.id)) ?? [:]
        if let existing = meta.field(reference.field) {
            guard replace || values[reference.field] == nil else {
                throw AgentError("field_exists", "\(reference) already has a value. Overwrite with --replace.")
            }
            guard existing.kind == kind || replace else {
                throw AgentError("field_kind", "\(reference) already exists as a field of kind '\(existing.kind.title)'.")
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
            + config.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "target \($0.name)" }
        guard users.isEmpty else { throw SecretariatError("This item is still in use: \(users.joined(separator: ", ")). Please remove the bindings first.") }
        let path = (try? item(id: id).path) ?? id.uuidString
        try items.delete(id: id)
        audit.record("item.delete", ["item": path])
        exportRegistry()
    }

    /// Value of a field for a program. Identifiers come from metadata, personal fields never leave the app.
    public func value(itemID: UUID, field name: String) throws -> String {
        let meta = try item(id: itemID)
        guard let field = meta.field(name) else { throw AgentError("field_not_found", "\(meta.path) has no field \(name).") }
        switch field.kind {
        case .identifier: return field.value ?? ""
        case .personal: throw AgentError("personal_field", "\(meta.path)/\(name) is only for you and is never passed to a program.")
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
                guard replace else { throw AgentError("field_exists", "\(destination) already exists. Overwrite with --replace.") }
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
        guard profile.isAnywhere || FileManager.default.fileExists(atPath: profile.directory, isDirectory: &isDirectory) && isDirectory.boolValue else {
            throw SecretariatError("The chosen project folder doesn't exist. Please choose it again.")
        }
        try configuration.update(expectedRevision: expectedRevision) { config in
            if let index = config.profiles.firstIndex(where: { $0.id == profile.id }) { config.profiles[index] = profile }
            else { config.profiles.append(profile) }
        }
    }
    public func deleteProfile(id: UUID) throws {
        try configuration.update(expectedRevision: expectedRevision) { $0.profiles.removeAll { $0.id == id } }
    }
    /// Automatic deletion of history entries older than `days` (nil keeps everything). The app is the only caller.
    public func setHistoryRetention(days: Int?) throws {
        try configuration.update(expectedRevision: expectedRevision) { $0.historyRetentionDays = days }
        audit.record("history.retention", days.map { ["days": String($0)] } ?? [:])
    }
    /// Applies the retention setting; run on every CLI call and when the app loads.
    @discardableResult public func pruneHistory(now: Date = Date()) -> Int {
        guard let days = (try? configuration.load())?.historyRetentionDays, days > 0,
              let removed = try? audit.prune(olderThan: now.addingTimeInterval(-Double(days) * 86_400)), removed > 0 else { return 0 }
        audit.record("history.pruned", ["entries": String(removed), "days": String(days)])
        return removed
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
            throw SecretariatError("Profile not found. Create a profile in Secretariat or use 'secretariat profiles'.")
        }
        guard !arguments.isEmpty, !arguments[0].isEmpty else { throw SecretariatError("Please name a program after --.") }
        try requireApproval(profile.bindings.map(\.itemID), for: "run \(name): \(arguments.joined(separator: " ").prefix(80))")
        var environment = inheritedEnvironment
        var files: [PreparedLaunch.File] = []
        var masks: [StreamMasker.Secret] = []
        for binding in profile.bindings {
            let meta = try item(id: binding.itemID)
            let value = try value(itemID: binding.itemID, field: binding.field)
            if meta.field(binding.field)?.kind == .file {
                guard let data = Data(base64Encoded: value) else { throw SecretariatError("The file in \(meta.path)/\(binding.field) is damaged.") }
                files.append(.init(variable: binding.variable, name: meta.field(binding.field)?.fileName ?? binding.field, data: data))
            } else {
                guard !value.utf8.contains(0) else { throw SecretariatError("A value contains a null character, which environment variables don't allow.") }
                environment[binding.variable] = value
                if meta.field(binding.field)?.kind != .identifier {
                    masks.append(.init(value: Data(value.utf8), label: "\(meta.path)/\(binding.field)"))
                }
            }
        }
        audit.record("run", ["profile": name, "variables": profile.bindings.map(\.variable).sorted().joined(separator: ",")])
        let directory = profile.isAnywhere ? FileManager.default.currentDirectoryPath : profile.directory
        return PreparedLaunch(directory: directory, arguments: arguments, environment: environment, files: files, masks: masks)
    }

    // MARK: registry

    /// Writes identifiers (and names of secret fields) to the fleet registry. Deterministic, no timestamps,
    /// so every Mac produces the same file.
    public func exportRegistry() {
        guard let registryDirectory, let all = try? list() else { return }
        let text = RegistryExport.render(all)
        let url = registryDirectory.appendingPathComponent("accounts.toml")
        if (try? String(contentsOf: url, encoding: .utf8)) != text { try? text.write(to: url, atomically: true, encoding: .utf8) }
        // Company identity goes into an always-loaded rule, so every agent session knows who it works for.
        let rule = registryDirectory.deletingLastPathComponent().appendingPathComponent("rules/company.md")
        let ruleText = CompanyRule.render(all, catalog: catalog())
        if FileManager.default.fileExists(atPath: rule.deletingLastPathComponent().path),
           (try? String(contentsOf: rule, encoding: .utf8)) != ruleText { try? ruleText.write(to: rule, atomically: true, encoding: .utf8) }
    }
}

/// `~/.claude/rules/company.md`: loaded by every Claude Code session (rules without `paths:`) and read by Hermes.
public enum CompanyRule {
    public static let defaultPath = "moinsen/company"
    public static func render(_ items: [ItemMeta], catalog: TemplateCatalog = .builtin) -> String {
        let identity = Set(catalog.all.filter(\.identity).map(\.id))
        let companies = items.filter { identity.contains($0.kind) }
            .sorted { ($0.path == defaultPath ? "" : $0.path) < ($1.path == defaultPath ? "" : $1.path) }
        var lines = ["# Company identity — who you work for", "",
                     "<!-- GENERATED by Secretariat from items whose template is marked as identity. Edit in the Secretariat app; every Mac rewrites this file. -->", "",
                     "Use these details for imprints (Impressum), privacy policies, terms, email senders, footers, store listings",
                     "and app metadata. **Never ask Uli for them.** The first company is the default; a project belongs to another one",
                     "only if its CLAUDE.md says so (e.g. `Company: private/company`). A field that is missing here: ask once, then tell",
                     "Uli to add it in Secretariat (item \(defaultPath)) — don't invent it.", ""]
        guard !companies.isEmpty else {
            lines.append("**Not set up yet.** Ask Uli to create the item `\(defaultPath)` (template Company) in the Secretariat app; until then ask for the details once per task.")
            return lines.joined(separator: "\n") + "\n"
        }
        for company in companies {
            let template = catalog.template(company.kind)
            lines.append("## `\(company.path)`" + (company.path == defaultPath ? " (default)" : ""))
            lines.append("")
            for spec in template.fields {
                if let value = company.field(spec.name)?.value { lines.append("- \(spec.label): \(value)") }
            }
            for field in company.fields where template.spec(field.name) == nil && field.kind == .identifier {
                lines.append("- \(field.name): \(field.value ?? "")")
            }
            let missing = template.fields.filter { company.field($0.name)?.value == nil }.map(\.label)
            if !missing.isEmpty { lines.append("- _Not recorded:_ \(missing.joined(separator: ", "))") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
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
            lines.append("_kind = \(q(item.kind))")
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
