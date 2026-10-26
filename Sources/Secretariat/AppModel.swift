import AppKit
import Observation
import SecretariatCore

struct FieldDraft: Identifiable {
    var id = UUID()
    var name = ""
    var kind = FieldKind.identifier
    /// Identifier value, or a newly typed secret value (empty keeps the stored one).
    var value = ""
    var fileName: String?
    /// Newly chosen file, base64.
    var fileData: String?
    /// Name under which the value is stored today (nil for new fields).
    var storedName: String?
}

struct ItemDraft: Identifiable {
    let id = UUID()
    var existing: ItemMeta?
    var kind = ItemKind.api
    /// Path parts: moinsen/<provider>[/<label>]. With `customPath` the path is typed directly (Erweitert).
    var provider = ""
    var label = ""
    var customPath = false
    var typedPath = ""
    var source = ""
    var expires = ""
    var fields: [FieldDraft] = []
    /// Bind the usable fields into the profile "werkzeuge" (available in every folder).
    var everywhere = false
    var revision = 0

    init(revision: Int) {
        self.revision = revision
        fields = Self.template(kind)
    }
    init(item: ItemMeta, revision: Int) {
        existing = item; kind = item.kind; source = item.source; expires = item.expires ?? ""
        let parts = item.path.split(separator: "/").map(String.init)
        if parts.count >= 2, parts.count <= 3, parts[0] == "moinsen" {
            provider = parts[1]; label = parts.count == 3 ? parts[2] : ""
        } else { customPath = true; typedPath = item.path }
        fields = item.fields.map {
            FieldDraft(id: $0.id, name: $0.name, kind: $0.kind, value: $0.value ?? "", fileName: $0.fileName, storedName: $0.name)
        }
        self.revision = revision
    }
    static func template(_ kind: ItemKind) -> [FieldDraft] { kind.fields.map { FieldDraft(name: $0.name, kind: $0.kind) } }

    static func slug(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"[^a-z0-9._@-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }
    var path: String {
        if customPath { return typedPath.trimmingCharacters(in: .whitespacesAndNewlines) }
        let p = Self.slug(provider), l = Self.slug(label)
        return p.isEmpty ? "" : "moinsen/\(p)" + (l.isEmpty ? "" : "/\(l)")
    }
    /// Variable prefix for "everywhere": OPENAI from moinsen/openai.
    var envPrefix: String { Self.slug(provider).uppercased().replacingOccurrences(of: #"[^A-Z0-9]+"#, with: "_", options: .regularExpression) }
    func field(_ name: String) -> FieldDraft? { fields.first { $0.name == name } }
    /// Required fields of the kind that are still empty (stored values count as filled).
    var missing: [String] {
        (path.isEmpty ? [customPath ? "Ablage" : "Anbieter oder Konto"] : []) + kind.fields.filter(\.required).filter { spec in
            guard let f = field(spec.name) else { return true }
            return f.value.isEmpty && f.fileData == nil && f.storedName == nil
        }.map(\.label)
    }
}

struct ProfileDraft: Identifiable {
    let id = UUID()
    var profile = Profile()
    var revision = 0
}

/// A field a profile can bind to (everything except personal fields).
struct UsableField: Identifiable, Hashable {
    let itemID: UUID
    let field: String
    let label: String
    var id: String { "\(itemID)|\(field)" }
}

@Observable
final class AppModel {
    let paths = AppPaths()
    var configuration = Configuration()
    var items: [ItemMeta] = []
    var targetReport: Targets.Report?
    var selection = "items"
    var selectedItem: UUID?
    var errorMessage: String?
    var loadFailed = false
    var itemEditor: ItemDraft?
    var profileEditor: ProfileDraft?
    var copied = false
    var agentSetup: AgentSetupDraft?

    init() { reload() }
    var vault: Vault { Vault(paths: paths, expectedRevision: configuration.revision) }
    var currentProfile: Profile? { configuration.profiles.first { $0.id.uuidString == selection } }
    var currentItem: ItemMeta? { items.first { $0.id == selectedItem } }
    var launcherPath: String {
        let installed = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/secretariat")
        if installed.resolvingSymlinksInPath().path == Bundle.main.executableURL?.path { return installed.path }
        return Bundle.main.executableURL?.path ?? "secretariat"
    }
    var usableFields: [UsableField] {
        items.flatMap { item in
            item.fields.filter { $0.kind.isUsable }.map { UsableField(itemID: item.id, field: $0.name, label: "\(item.path)/\($0.name)") }
        }
    }
    func label(_ binding: SecretariatCore.Binding) -> String {
        guard let item = items.first(where: { $0.id == binding.itemID }) else { return "Eintrag fehlt (\(binding.field))" }
        return "\(item.path)/\(binding.field)"
    }

    func reload() {
        do {
            configuration = try ConfigurationStore(paths: paths).load()
            loadFailed = false
        } catch { loadFailed = true; errorMessage = error.localizedDescription; return }
        do { items = try Vault(paths: paths).list() }
        catch { items = []; errorMessage = error.localizedDescription }
        if selection == "targets" { refreshTargets() }
    }
    func refreshTargets() {
        do { targetReport = try Targets.report(vault: Vault(paths: paths)) }
        catch { targetReport = nil; errorMessage = error.localizedDescription }
    }
    @discardableResult func perform(_ action: () throws -> Void) -> Bool {
        do { try action(); reload(); copied = false; return true }
        catch { errorMessage = error.localizedDescription; return false }
    }

    func saveItem(_ draft: ItemDraft) -> Bool {
        var savedID: UUID?
        let saved = perform {
            let vault = Vault(paths: paths, expectedRevision: draft.revision)
            let expires = draft.expires.trimmingCharacters(in: .whitespaces)
            let meta = ItemMeta(
                id: draft.existing?.id ?? UUID(), path: draft.path, kind: draft.kind,
                // Optional fields of the kind that stayed empty are not stored.
                fields: draft.fields.filter { f in
                    !(draft.kind.spec(f.name).map { !$0.required } ?? false) || !f.value.isEmpty || f.fileData != nil || f.storedName != nil
                }.map {
                    ItemField(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespaces), kind: $0.kind,
                              value: $0.kind == .identifier ? $0.value.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                              fileName: $0.kind == .file ? $0.fileName : nil)
                },
                expires: expires.isEmpty ? nil : expires,
                rotated: draft.existing?.rotated, source: draft.source.trimmingCharacters(in: .whitespacesAndNewlines))
            // Complete value map: stored values (following renames), overridden by what was typed or chosen now.
            let stored = draft.existing == nil ? [:] : try vault.items.secrets(id: meta.id)
            var secrets: [String: String] = [:]
            for field in draft.fields where field.kind.isSecret {
                let typed = field.kind == .file ? field.fileData : (field.value.isEmpty ? nil : field.value)
                if let value = typed ?? field.storedName.flatMap({ stored[$0] }) {
                    secrets[field.name.trimmingCharacters(in: .whitespaces)] = value
                }
            }
            try vault.save(meta, secrets: secrets)
            savedID = meta.id
            if draft.everywhere { try makeAvailableEverywhere(draft, meta: meta, vault: vault) }
        }
        if saved { selectedItem = savedID }
        return saved
    }
    /// Binds the item's usable fields into the profile "werkzeuge" (runs in any folder): OPENAI_API_KEY etc.
    private func makeAvailableEverywhere(_ draft: ItemDraft, meta: ItemMeta, vault: Vault) throws {
        let config = try ConfigurationStore(paths: paths).load()
        var profile = config.profiles.first { $0.name == "werkzeuge" } ?? Profile(name: "werkzeuge", directory: Profile.anywhere)
        for field in meta.fields where field.kind.isUsable {
            guard let suffix = draft.kind.spec(field.name)?.envSuffix else { continue }
            var variable = "\(draft.envPrefix)_\(suffix)"
            if field.name == "api_key", let custom = meta.field("env_var")?.value, !custom.isEmpty { variable = custom }
            profile.bindings.removeAll { $0.variable == variable }
            profile.bindings.append(SecretariatCore.Binding(variable: variable, itemID: meta.id, field: field.name))
        }
        try Vault(paths: paths).saveProfile(profile)
    }
    /// Item waiting for the delete confirmation (list, detail, editor, Delete key).
    var pendingDelete: ItemMeta?
    func item(_ id: UUID) -> ItemMeta? { items.first { $0.id == id } }
    func edit(_ item: ItemMeta) { itemEditor = ItemDraft(item: item, revision: configuration.revision) }
    func deleteItem(_ item: ItemMeta) {
        if perform({ try vault.delete(id: item.id) }) { selectedItem = nil }
    }
    func secretValue(_ item: ItemMeta, _ field: ItemField) -> String? {
        do {
            guard let value = try vault.personalValue(itemID: item.id, field: field.name) else {
                throw SecretariatError("Für \(item.path)/\(field.name) ist noch kein Wert gespeichert.")
            }
            return value
        } catch { errorMessage = error.localizedDescription; return nil }
    }
    /// Copies a secret and clears the clipboard after 60 s, unless something else was copied meanwhile.
    func copySecret(_ value: String) {
        let pasteboard = NSPasteboard.general
        copyText(value)
        let count = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: .seconds(60))
            if pasteboard.changeCount == count { pasteboard.clearContents() }
        }
    }
    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    func exportFile(_ item: ItemMeta, _ field: ItemField) {
        guard let value = secretValue(item, field) else { return }
        guard let data = Data(base64Encoded: value) else { errorMessage = "Die gespeicherte Datei ist beschädigt."; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = field.fileName ?? field.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { errorMessage = error.localizedDescription }
    }

    func saveProfile(_ profile: Profile, expectedRevision: Int) -> Bool {
        let saved = perform { try Vault(paths: paths, expectedRevision: expectedRevision).saveProfile(profile) }
        if saved { selection = profile.id.uuidString }
        return saved
    }
    func deleteProfile(_ profile: Profile) {
        if perform({ try vault.deleteProfile(id: profile.id) }) { selection = "items" }
    }
    func deleteTarget(named name: String) {
        guard let target = configuration.targets.first(where: { $0.name == name }) else { return }
        perform { try vault.deleteTarget(id: target.id) }
    }
    func copyLaunch(_ profile: Profile) {
        guard !profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Bitte im Profil einen Startbefehl eintragen."; return
        }
        copyText(launchCommand(profile: profile, executable: launcherPath))
        copied = true
    }
    func openAgentSetup(_ profile: Profile) {
        do {
            let current = try ConfigurationStore(paths: paths).load()
            guard current.revision == configuration.revision else {
                throw SecretariatError("Die Profile wurden geändert. Bitte Ansicht aktualisieren und erneut einrichten.")
            }
            agentSetup = AgentSetupDraft(plan: try ProjectInstructions.preview(profile: profile, executable: launcherPath), revision: current.revision)
        } catch { errorMessage = error.localizedDescription }
    }
    func applyAgentSetup(_ draft: AgentSetupDraft) throws {
        guard try ConfigurationStore(paths: paths).load().revision == draft.revision else {
            throw SecretariatError("Das Profil wurde seit der Vorschau geändert. Bitte die Vorschau schließen und erneut öffnen.")
        }
        try ProjectInstructions.apply(draft.plan)
    }
    func usages(of id: UUID) -> [String] {
        configuration.profiles.filter { $0.bindings.contains { $0.itemID == id } }.map(\.name)
            + configuration.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "Ziel \($0.name)" }
    }
}

/// Days until a yyyy-MM-dd date (negative when past).
func daysUntil(_ date: String?) -> Int? {
    guard let date else { return nil }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
    guard let day = f.date(from: date) else { return nil }
    return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: day).day
}
