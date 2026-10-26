import SwiftUI
import SecretariatCore

struct MainView: View {
    @Bindable var model: AppModel
    @State private var deletingItem: ItemMeta?
    @State private var deletingProfile: Profile?
    @State private var deletingTarget: String?
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Label("Alle Einträge", systemImage: "key.horizontal").tag("items")
                Label("Ziele", systemImage: "arrow.up.forward.app").tag("targets")
                Section("Projektprofile") {
                    ForEach(model.configuration.profiles.sorted { $0.name < $1.name }) { profile in
                        Label(profile.name, systemImage: "folder").tag(profile.id.uuidString)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 225)
            .safeAreaInset(edge: .bottom) {
                Button { model.profileEditor = ProfileDraft(revision: model.configuration.revision) } label: {
                    Label("Neues Profil", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.borderless).padding()
            }
        } detail: {
            Group {
                if model.loadFailed {
                    ContentUnavailableView {
                        Label("Daten konnten nicht geladen werden", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Der vorhandene Stand bleibt erhalten. Bitte die Konfiguration prüfen und erneut laden.")
                    } actions: { Button("Erneut laden") { model.reload() } }.padding(28)
                } else if let profile = model.currentProfile { profileDetail(profile).padding(28) }
                else if model.selection == "targets" { targetsView.padding(28) }
                else { itemLibrary }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle("Secretariat")
        .onChange(of: model.selection) { _, selection in
            model.copied = false
            if selection == "targets" { model.refreshTargets() }
        }
        .toolbar {
            ToolbarItem { Button { model.reload() } label: { Label("Aktualisieren", systemImage: "arrow.clockwise") } }
        }
        .sheet(item: $model.itemEditor) { draft in ItemEditor(model: model, draft: draft) }
        .sheet(item: $model.agentSetup) { draft in AgentSetupView(model: model, draft: draft) }
        .sheet(item: $model.profileEditor) { draft in ProfileEditor(model: model, draft: draft) }
        .alert("Das hat nicht geklappt", isPresented: flag(model.errorMessage != nil) { model.errorMessage = nil }) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Eintrag löschen?", isPresented: flag(deletingItem != nil) { deletingItem = nil }) {
            Button("Abbrechen", role: .cancel) { deletingItem = nil }
            Button("Löschen", role: .destructive) {
                if let item = deletingItem { model.deleteItem(item) }; deletingItem = nil
            }
        } message: { Text("‚\(deletingItem?.path ?? "")‘ wird auf allen deinen Macs entfernt. Verwendete Einträge bleiben geschützt.") }
        .alert("Profil löschen?", isPresented: flag(deletingProfile != nil) { deletingProfile = nil }) {
            Button("Abbrechen", role: .cancel) { deletingProfile = nil }
            Button("Löschen", role: .destructive) {
                if let profile = deletingProfile { model.deleteProfile(profile) }; deletingProfile = nil
            }
        } message: { Text("Die Zuordnungen werden entfernt. Die gespeicherten Einträge bleiben erhalten.") }
        .alert("Ziel löschen?", isPresented: flag(deletingTarget != nil) { deletingTarget = nil }) {
            Button("Abbrechen", role: .cancel) { deletingTarget = nil }
            Button("Löschen", role: .destructive) {
                if let name = deletingTarget { model.deleteTarget(named: name); model.refreshTargets() }; deletingTarget = nil
            }
        } message: { Text("‚\(deletingTarget ?? "")‘ wird aus der Liste entfernt. Bereits verteilte Werte bleiben dort, wo sie sind.") }
    }

    private func flag(_ value: Bool, clear: @escaping () -> Void) -> SwiftUI.Binding<Bool> {
        SwiftUI.Binding(get: { value }, set: { if !$0 { clear() } })
    }

    // MARK: Items

    private var filteredItems: [ItemMeta] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return model.items }
        return model.items.filter { item in
            item.path.lowercased().contains(query) || item.fields.contains {
                $0.name.lowercased().contains(query) || ($0.value?.lowercased().contains(query) ?? false)
            }
        }
    }

    private var itemLibrary: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deine Einträge").font(.largeTitle.bold())
                        Text("Einmal hinterlegen. Auf allen Macs und in deinen Projekten verwenden.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Eintrag hinzufügen", systemImage: "plus") { model.itemEditor = ItemDraft(revision: model.configuration.revision) }
                        .buttonStyle(.borderedProminent)
                }
                if model.items.isEmpty {
                    ContentUnavailableView {
                        Label("Alles an einem Ort", systemImage: "key.horizontal.fill")
                    } description: {
                        Text("Hinterlege deinen ersten Zugang. Die Werte liegen im Schlüsselbund und gleichen sich über iCloud ab.")
                    } actions: {
                        Button("Ersten Eintrag hinzufügen") { model.itemEditor = ItemDraft(revision: model.configuration.revision) }
                    }.frame(maxHeight: .infinity)
                } else {
                    TextField("Suchen", text: $search, prompt: Text("Pfad, Feld oder Kennung suchen"))
                        .textFieldStyle(.roundedBorder)
                    List(selection: $model.selectedItem) {
                        ForEach(Dictionary(grouping: filteredItems, by: \.group).sorted { $0.key < $1.key }, id: \.key) { group, items in
                            Section(group) {
                                ForEach(items.sorted { $0.path < $1.path }) { item in itemRow(item).tag(item.id) }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .overlay { if filteredItems.isEmpty { ContentUnavailableView.search(text: search) } }
                }
                Label("Die Werte bleiben im macOS-Schlüsselbund.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(minWidth: 380, idealWidth: 460, maxHeight: .infinity, alignment: .topLeading)
            Group {
                if let item = model.currentItem { ItemDetail(model: model, item: item, delete: { deletingItem = item }).id(item.id) }
                else {
                    ContentUnavailableView("Kein Eintrag ausgewählt", systemImage: "sidebar.right",
                                           description: Text("Wähle links einen Eintrag, um seine Felder zu sehen."))
                }
            }.frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func itemRow(_ item: ItemMeta) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbol).foregroundStyle(.tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.path).font(.headline)
                Text(item.fields.map(\.name).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            ExpiryBadge(date: item.expires)
        }.padding(.vertical, 4)
    }

    // MARK: Targets

    private var targetsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ziele").font(.largeTitle.bold())
                    Text("Orte außerhalb deiner Macs, die Kopien von Werten halten.").foregroundStyle(.secondary)
                }
                Label("Verteilen startest du im Terminal; Ziele legst du per CLI an (secretariat target add …).", systemImage: "terminal")
                    .font(.callout).foregroundStyle(.secondary)
                if let targets = model.targetReport?.targets, !targets.isEmpty {
                    ForEach(targets, id: \.name) { target in targetCard(target) }
                } else {
                    ContentUnavailableView("Noch keine Ziele", systemImage: "arrow.up.forward.app",
                                           description: Text("Lege ein Ziel im Terminal an, zum Beispiel für einen Cloudflare Worker oder eine .env-Datei auf einem Server."))
                }
            }
        }
    }

    private func targetCard(_ target: Targets.TargetStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.name).font(.title3.bold())
                    Text(target.destination).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                    if let pushedAt = target.pushedAt { Text("Zuletzt verteilt: \(pushedAt)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button("Befehl kopieren", systemImage: "doc.on.doc") { model.copyText("secretariat push \(shellQuote(target.name))") }
                Button { deletingTarget = target.name } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Ziel \(target.name) löschen")
            }
            if target.variables.isEmpty {
                Text("Diesem Ziel ist noch keine Variable zugeordnet.").foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    ForEach(target.variables, id: \.variable) { variable in
                        GridRow {
                            Text(variable.variable).font(.system(.body, design: .monospaced))
                            Text(variable.reference).foregroundStyle(.secondary)
                            StatusBadge(status: variable.status)
                        }
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Profiles

    private func profileDetail(_ profile: Profile) -> some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.name).font(.largeTitle.bold())
                    Label(profile.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button("Bearbeiten") { model.profileEditor = ProfileDraft(profile: profile, revision: model.configuration.revision) }
            }
            Divider()
            Text("Werte für dieses Projekt").font(.headline)
            if profile.bindings.isEmpty {
                Text("Diesem Profil sind noch keine Felder zugeordnet.").foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    ForEach(profile.bindings) { binding in
                        GridRow {
                            Text(binding.variable).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Image(systemName: "arrow.left").foregroundStyle(.secondary)
                            Text(model.label(binding)).textSelection(.enabled)
                        }
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Im Terminal starten").font(.headline)
                Text(profile.command.isEmpty ? "Trage unter Bearbeiten einen Startbefehl ein." : profile.command)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Button(model.copied ? "Aufruf kopiert" : "Terminalaufruf kopieren", systemImage: model.copied ? "checkmark" : "terminal") {
                    model.copyLaunch(profile)
                }.buttonStyle(.borderedProminent).disabled(profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Den Aufruf im Terminal einfügen. Das Programm erhält die zugeordneten Werte beim Start.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Mit Coding-Systemen verwenden").font(.headline)
                Text("Projektanweisungen für Codex, Claude Code und OpenCode vorbereiten.")
                    .foregroundStyle(.secondary)
                Button("Coding-System einrichten", systemImage: "terminal.fill") { model.openAgentSetup(profile) }
            }
            Spacer()
            Button("Profil löschen", role: .destructive) { deletingProfile = profile }.buttonStyle(.borderless)
        }
        }
    }
}

struct ItemDetail: View {
    let model: AppModel
    let item: ItemMeta
    let delete: () -> Void
    @State private var revealed: [String: String] = [:]
    @State private var copiedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Image(systemName: item.kind.symbol).font(.title).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.path).font(.title2.bold()).textSelection(.enabled)
                        Text(item.kind.title).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Bearbeiten") { model.itemEditor = ItemDraft(item: item, revision: model.configuration.revision) }
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    if !item.source.isEmpty { info("Herkunft", item.source) }
                    if let expires = item.expires {
                        GridRow {
                            Text("Läuft ab").foregroundStyle(.secondary)
                            HStack { Text(expires); ExpiryBadge(date: expires) }
                        }
                    }
                    if let rotated = item.rotated { info("Zuletzt geändert", rotated) }
                    let usages = model.usages(of: item.id)
                    info("Verwendet in", usages.isEmpty ? "Noch nirgends" : usages.joined(separator: ", "))
                }.font(.callout)
                Divider()
                Text("Felder").font(.headline)
                VStack(spacing: 0) {
                    ForEach(item.fields) { field in
                        fieldRow(field).padding(.vertical, 10)
                        Divider()
                    }
                }
                Button("Eintrag löschen", role: .destructive, action: delete).buttonStyle(.borderless)
            }.padding(28)
        }
    }

    private func info(_ title: String, _ value: String) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }

    private func fieldRow(_ field: ItemField) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.kind.spec(field.name)?.label ?? field.name)
                Text("\(field.name) · \(field.kind.title)").font(.caption).foregroundStyle(.secondary)
            }.frame(width: 150, alignment: .leading)
            switch field.kind {
            case .identifier:
                Text(field.value ?? "").textSelection(.enabled).lineLimit(2)
                Spacer(minLength: 8)
                copyButton(field) { field.value }
            case .secret, .personal:
                Text(revealed[field.name] ?? "••••••").font(.system(.body, design: .monospaced))
                    .foregroundStyle(revealed[field.name] == nil ? .tertiary : .primary).textSelection(.enabled).lineLimit(3)
                Spacer(minLength: 8)
                Button(revealed[field.name] == nil ? "Anzeigen" : "Verbergen") {
                    if revealed[field.name] == nil { revealed[field.name] = model.secretValue(item, field) }
                    else { revealed[field.name] = nil }
                }
                copyButton(field, secret: true) { model.secretValue(item, field) }
            case .file:
                Label(field.fileName ?? "Datei", systemImage: "doc").lineLimit(1)
                Spacer(minLength: 8)
                Button("Exportieren …") { model.exportFile(item, field) }
            }
        }
    }

    private func copyButton(_ field: ItemField, secret: Bool = false, value: @escaping () -> String?) -> some View {
        Button(copiedField == field.name ? "Kopiert" : "Kopieren") {
            guard let text = value() else { return }
            if secret { model.copySecret(text) } else { model.copyText(text) }
            copiedField = field.name
        }.help(secret ? "Die Zwischenablage wird nach 60 Sekunden geleert." : "")
    }
}

struct ExpiryBadge: View {
    let date: String?
    var body: some View {
        if let days = daysUntil(date), days <= 30 {
            Text(days < 0 ? "abgelaufen" : days == 0 ? "läuft heute ab" : "noch \(days) Tage")
                .font(.caption.bold()).padding(.horizontal, 7).padding(.vertical, 2)
                .foregroundStyle(.white).background(days < 0 ? Color.red : Color.orange, in: Capsule())
        }
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        let (title, color): (String, Color) = switch status {
        case "current": ("aktuell", .green)
        case "stale": ("veraltet", .orange)
        case "never": ("nie verteilt", .gray)
        default: ("fehlt", .red)
        }
        Text(title).font(.caption.bold()).padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(.white).background(color, in: Capsule())
    }
}
