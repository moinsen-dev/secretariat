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
    /// The template the item follows; the item stores its id as `kind`.
    var template: Template
    var kind: String { template.id }
    /// Path parts: moinsen/<provider>[/<label>]. With `customPath` the path is typed directly (Advanced).
    var provider = ""
    var label = ""
    var customPath = false
    var typedPath = ""
    var source = ""
    var expires = ""
    var fields: [FieldDraft] = []
    /// Bind the usable fields into the profile "werkzeuge" (available in every folder).
    var everywhere = false
    /// Agent Guard: programs need Touch ID before they get this item's values.
    var approval = false
    var revision = 0
    /// Clipboard capture this item is filed from; it leaves the inbox once the item is saved.
    var replaces: UUID?
    /// Prefilled from a screenshot read on this Mac: how it was read, shown above the form until saved.
    var readNote: String?

    init(template: Template, revision: Int) {
        self.template = template
        self.revision = revision
        fields = Self.fields(template)
        if template.identity { provider = "moinsen" }
    }
    init(item: ItemMeta, template: Template, revision: Int) {
        existing = item; self.template = template; source = item.source; expires = item.expires ?? ""; approval = item.needsApproval
        let parts = item.path.split(separator: "/").map(String.init)
        if template.identity, parts.count == 2, parts[1] == item.kind { provider = parts[0] }
        else if parts.count >= 2, parts.count <= 3, parts[0] == "moinsen" {
            provider = parts[1]; label = parts.count == 3 ? parts[2] : ""
        } else { customPath = true; typedPath = item.path }
        fields = item.fields.map {
            FieldDraft(id: $0.id, name: $0.name, kind: $0.kind, value: $0.value ?? "", fileName: $0.fileName, storedName: $0.name)
        }
        // Optional fields of the template that were left empty are not stored; offer them again when editing.
        for spec in template.fields where !fields.contains(where: { $0.name == spec.name }) {
            fields.append(FieldDraft(name: spec.name, kind: spec.kind))
        }
        self.revision = revision
    }
    static func fields(_ template: Template) -> [FieldDraft] { template.fields.map { FieldDraft(name: $0.name, kind: $0.kind) } }

    static func slug(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"[^a-z0-9._@-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }
    var path: String {
        if customPath { return typedPath.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Identity items live at <organisation>/<template id> (moinsen/company is the default every agent reads first).
        if template.identity { let o = Self.slug(provider); return o.isEmpty ? "" : "\(o)/\(kind)" }
        let p = Self.slug(provider), l = Self.slug(label)
        return p.isEmpty ? "" : "moinsen/\(p)" + (l.isEmpty ? "" : "/\(l)")
    }
    /// Variable prefix for "everywhere": OPENAI from moinsen/openai, CLOUDFLARE_PULSE_READONLY from moinsen/cloudflare/pulse-readonly.
    /// A project key gets its own name, so it never takes over the main key's variable.
    var envPrefix: String {
        [provider, label].map { Self.slug($0).uppercased().replacingOccurrences(of: #"[^A-Z0-9]+"#, with: "_", options: .regularExpression) }
            .filter { !$0.isEmpty }.joined(separator: "_")
    }
    /// The variable a field gets in the profile "werkzeuge"; the API key may carry its own name in `env_var`.
    func variable(_ spec: FieldSpec) -> String? {
        guard let suffix = spec.envSuffix else { return nil }
        if spec.name == "api_key", let custom = field("env_var")?.value.trimmingCharacters(in: .whitespaces), !custom.isEmpty { return custom }
        return "\(envPrefix)_\(suffix)"
    }
    /// A whole location was typed into the provider field (moinsen/cloudflare/pulse-readonly).
    var providerIsPath: Bool { !customPath && !template.identity && provider.contains("/") }
    /// Splits a typed location into provider and project; anything outside moinsen/<provider>/<project> becomes a custom location.
    mutating func splitProvider() {
        var parts = provider.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if parts.first == "moinsen" { parts.removeFirst() }
        if parts.count <= 2 { provider = parts.first ?? ""; label = parts.count == 2 ? parts[1] : label }
        else { typedPath = provider.trimmingCharacters(in: .whitespaces); customPath = true }
    }
    func field(_ name: String) -> FieldDraft? { fields.first { $0.name == name } }
    /// Required fields of the template that are still empty (stored values count as filled).
    var missing: [String] {
        (path.isEmpty ? [customPath ? "Location" : (template.identity ? "Organisation" : "Provider or account")] : [])
            + (providerIsPath ? ["Provider without “/”"] : []) + template.fields.filter(\.required).filter { spec in
            guard let f = field(spec.name) else { return true }
            return f.value.isEmpty && f.fileData == nil && f.storedName == nil
        }.map(\.label)
    }
}

/// A template field row in the template editor (stable identity while the name is being typed).
struct FieldSpecDraft: Identifiable {
    let id = UUID()
    var spec: FieldSpec
}

struct TemplateDraft: Identifiable {
    let id = UUID()
    var isNew: Bool
    var template: Template
    var fields: [FieldSpecDraft]
    init(template: Template, isNew: Bool) {
        self.isNew = isNew; self.template = template
        fields = template.fields.map { FieldSpecDraft(spec: $0) }
    }
    /// The template as it would be saved: trimmed names, labels and suffixes.
    var result: Template {
        var t = template
        t.id = t.id.trimmingCharacters(in: .whitespaces)
        t.symbol = t.symbol.trimmingCharacters(in: .whitespaces)
        t.explanation = t.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        t.fields = fields.map { row in
            var spec = row.spec
            spec.name = spec.name.trimmingCharacters(in: .whitespaces)
            spec.label = spec.label.trimmingCharacters(in: .whitespaces)
            let suffix = spec.envSuffix?.trimmingCharacters(in: .whitespaces) ?? ""
            spec.envSuffix = suffix.isEmpty ? nil : suffix
            return spec
        }
        return t
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
    var catalog = TemplateCatalog.builtin
    var targetReport: Targets.Report?
    var selection = "items"
    var selectedItem: UUID?
    var selectedTarget: String?
    var selectedTemplate: String?
    var errorMessage: String?
    var loadFailed = false
    var itemEditor: ItemDraft?
    var profileEditor: ProfileDraft?
    var templateEditor: TemplateDraft?
    var copied = false
    var agentSetup: AgentSetupDraft?
    var license: Licensing.State = .licensed(email: "")
    var showLicense = false
    /// Resolved off the main thread at launch (asking for the iCloud container can block); nil until then.
    var screenshotLibrary: ScreenshotLibrary?
    var screenshots: [Screenshot] = []
    var screenshotsPending = 0
    var screenshotsUnreadable = 0
    var selectedScreenshot: UUID?
    var screenshotDraft: ScreenshotDraft?
    /// Screenshot waiting for the delete confirmation.
    var pendingScreenshotDelete: Screenshot?
    /// Screenshot being read for "Create Item …".
    var readingScreenshot: UUID?
    /// This Mac's history (audit.log), loaded when the History view is shown.
    /// Backup state for the Backup view; refreshed after each automatic backup.
    var backupStatus: Backup.Status?
    var backingUp = false
    var backupAgain = false
    var backupSetup: BackupSetupDraft?
    var showRestore = false
    var history: [HistoryEntry] = []
    var historyPeriod = HistoryPeriod.week
    var historyVia: String?
    var thumbnails: [UUID: NSImage] = [:]

    init() {
        reload()
        let paths = paths
        Task {
            let library = await Task.detached { ScreenshotLibrary.resolve(paths: paths) }.value
            screenshotLibrary = library
            reloadScreenshots()
        }
    }
    func template(_ id: String) -> Template { catalog.template(id) }
    /// Built-ins removed by the user (hidden on every Mac, restorable).
    var hiddenBuiltins: [Template] { catalog.stored.filter { $0.hidden && $0.isBuiltin } }
    /// A built-in whose stored version differs from the default.
    func isOverridden(_ template: Template) -> Bool { template.isBuiltin && catalog.stored.contains { $0.id == template.id && !$0.hidden } }
    func newItemDraft() -> ItemDraft {
        let start = catalog.isKnown("api") ? template("api") : (catalog.all.first ?? Template.generic("api"))
        return ItemDraft(template: start, revision: configuration.revision)
    }
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
        guard let item = items.first(where: { $0.id == binding.itemID }) else { return "Item missing (\(binding.field))" }
        return "\(item.path)/\(binding.field)"
    }

    func reload() {
        do {
            configuration = try ConfigurationStore(paths: paths).load()
            loadFailed = false
        } catch { loadFailed = true; errorMessage = error.localizedDescription; return }
        catalog = Vault(paths: paths).catalog()
        do { items = try Vault(paths: paths).list() }
        catch { items = []; errorMessage = error.localizedDescription }
        if selection == "targets" { refreshTargets() }
        license = Vault(paths: paths).licensing.state()
        reloadScreenshots()
        // The retention set in History applies on every start and return to the app, off the main thread.
        if selection == "history" { loadHistory() } else { let paths = paths; Task.detached { Vault(paths: paths).pruneHistory() } }
        backUpAutomatically()
    }
    func activateLicense(_ text: String) throws {
        try Vault(paths: paths).licensing.activate(text)
        license = Vault(paths: paths).licensing.state()
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
                // Optional fields of the template that stayed empty are not stored.
                fields: draft.fields.filter { f in
                    !(draft.template.spec(f.name).map { !$0.required } ?? false) || !f.value.isEmpty || f.fileData != nil || f.storedName != nil
                }.map {
                    ItemField(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespaces), kind: $0.kind,
                              value: $0.kind == .identifier ? $0.value.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                              fileName: $0.kind == .file ? $0.fileName : nil)
                },
                expires: expires.isEmpty ? nil : expires,
                rotated: draft.existing?.rotated, source: draft.source.trimmingCharacters(in: .whitespacesAndNewlines),
                approval: draft.approval ? true : nil)
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
            if let capture = draft.replaces { removeCapture(capture, filedIn: secrets, vault: vault) }
        }
        if saved { selectedItem = savedID }
        return saved
    }
    /// The capture leaves the inbox only once its value is in the new item; otherwise it stays and the user is told.
    private func removeCapture(_ id: UUID, filedIn secrets: [String: String], vault: Vault) {
        do {
            guard let captured = try vault.personalValue(itemID: id, field: "value"), secrets.values.contains(captured) else {
                errorMessage = "The item was saved without the captured value, so the capture stays in the Inbox."
                return
            }
            try vault.delete(id: id)
        } catch { errorMessage = "The item was saved, but the capture could not be removed from the Inbox: \(error.localizedDescription)" }
    }
    /// Binds the item's usable fields into the profile "werkzeuge" (runs in any folder): OPENAI_API_KEY etc.
    private func makeAvailableEverywhere(_ draft: ItemDraft, meta: ItemMeta, vault: Vault) throws {
        let config = try ConfigurationStore(paths: paths).load()
        var profile = config.profiles.first { $0.name == "werkzeuge" } ?? Profile(name: "werkzeuge", directory: Profile.anywhere)
        for field in meta.fields where field.kind.isUsable {
            guard let variable = draft.template.spec(field.name).flatMap(draft.variable) else { continue }
            profile.bindings.removeAll { $0.variable == variable }
            profile.bindings.append(SecretariatCore.Binding(variable: variable, itemID: meta.id, field: field.name))
        }
        try Vault(paths: paths).saveProfile(profile)
    }
    /// Item waiting for the delete confirmation (list, detail, editor, Delete key).
    var pendingDelete: ItemMeta?
    func item(_ id: UUID) -> ItemMeta? { items.first { $0.id == id } }
    func edit(_ item: ItemMeta) { itemEditor = ItemDraft(item: item, template: template(item.kind), revision: configuration.revision) }
    func deleteItem(_ item: ItemMeta) {
        if perform({ try vault.delete(id: item.id) }) { selectedItem = nil }
    }
    /// A stored value for the user; `purpose` (show, copy, export, file) goes into the history, the value never does.
    func secretValue(_ item: ItemMeta, _ field: ItemField, for purpose: String) -> String? {
        do {
            guard let value = try vault.personalValue(itemID: item.id, field: field.name) else {
                throw SecretariatError("No value is stored yet for \(item.path)/\(field.name).")
            }
            vault.audit.record("read", ["field": "\(item.path)/\(field.name)", "purpose": purpose])
            return value
        } catch { errorMessage = error.localizedDescription; return nil }
    }
    /// Stores copied text in the inbox and shows it. Returns an error message instead of raising the alert (the capture panel shows it).
    func capture(_ value: String, name: String) -> String? {
        do {
            let meta = try Capture.save(value, name: name, vault: Vault(paths: paths))
            reload(); selection = "inbox"; selectedItem = meta.id
            return nil
        } catch { return error.localizedDescription }
    }
    /// Opens the item editor prefilled with a capture's value; saving removes the capture from the inbox.
    func file(_ capture: ItemMeta) {
        guard let field = capture.field("value"), let value = secretValue(capture, field, for: "file") else { return }
        var draft = newItemDraft()
        // "cloudflare-pulse-readonly" → provider cloudflare, project pulse-readonly; otherwise guess from the key's prefix.
        let words = Capture.name(of: capture).split(separator: "-").map(String.init)
        if let first = words.first, ItemEditor.providers.contains(first) {
            draft.provider = first; draft.label = words.dropFirst().joined(separator: "-")
        } else {
            draft.provider = Capture.provider(for: value) ?? words.joined(separator: "-")
        }
        if let index = draft.fields.firstIndex(where: { draft.template.spec($0.name)?.kind.isSecret == true }) { draft.fields[index].value = value }
        draft.source = capture.source
        draft.replaces = capture.id
        itemEditor = draft
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
        guard let value = secretValue(item, field, for: "export") else { return }
        guard let data = Data(base64Encoded: value) else { errorMessage = "The stored file is damaged."; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = field.fileName ?? field.name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: templates

    func saveTemplate(_ draft: TemplateDraft) -> Bool {
        let template = draft.result
        return perform {
            if draft.isNew && catalog.isKnown(template.id) { throw SecretariatError("A template \(template.id) already exists.") }
            try Vault(paths: paths).saveTemplate(template)
        }
    }
    func deleteTemplate(_ template: Template) { perform { try Vault(paths: paths).deleteTemplate(id: template.id) } }
    func resetTemplate(_ template: Template) { perform { try Vault(paths: paths).resetTemplate(id: template.id) } }

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
            errorMessage = "Please enter a start command in the profile."; return
        }
        copyText(launchCommand(profile: profile, executable: launcherPath))
        copied = true
    }
    func openAgentSetup(_ profile: Profile) {
        do {
            let current = try ConfigurationStore(paths: paths).load()
            guard current.revision == configuration.revision else {
                throw SecretariatError("The profiles changed. Please refresh the view and set up again.")
            }
            agentSetup = AgentSetupDraft(plan: try ProjectInstructions.preview(profile: profile, executable: launcherPath), revision: current.revision)
        } catch { errorMessage = error.localizedDescription }
    }
    func applyAgentSetup(_ draft: AgentSetupDraft) throws {
        guard try ConfigurationStore(paths: paths).load().revision == draft.revision else {
            throw SecretariatError("The profile changed since the preview. Please close the preview and open it again.")
        }
        try ProjectInstructions.apply(draft.plan)
    }
    func usages(of id: UUID) -> [String] {
        configuration.profiles.filter { $0.bindings.contains { $0.itemID == id } }.map(\.name)
            + configuration.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "Target \($0.name)" }
    }
}

/// Days until a yyyy-MM-dd date (negative when past).
func daysUntil(_ date: String?) -> Int? {
    guard let date else { return nil }
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
    guard let day = f.date(from: date) else { return nil }
    return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: day).day
}
