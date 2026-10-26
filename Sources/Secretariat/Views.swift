import SwiftUI
import SecretariatCore

struct MainView: View {
    @Bindable var model: AppModel
    @State private var deletingProfile: Profile?
    @State private var deletingTarget: String?
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Label("All Items", systemImage: "key.horizontal").tag("items")
                Label("Targets", systemImage: "arrow.up.forward.app").tag("targets")
                Section("Project Profiles") {
                    ForEach(model.configuration.profiles.sorted { $0.name < $1.name }) { profile in
                        Label(profile.name, systemImage: "folder").tag(profile.id.uuidString)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 225)
            .safeAreaInset(edge: .bottom) {
                Button { model.profileEditor = ProfileDraft(revision: model.configuration.revision) } label: {
                    Label("New Profile", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.borderless).padding()
            }
        } detail: {
            Group {
                if model.loadFailed {
                    ContentUnavailableView {
                        Label("Couldn't load data", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Your existing data is kept. Please check the configuration and reload.")
                    } actions: { Button("Reload") { model.reload() } }.padding(28)
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
            ToolbarItem { Button { model.reload() } label: { Label("Refresh", systemImage: "arrow.clockwise") } }
        }
        .sheet(item: $model.itemEditor) { draft in ItemEditor(model: model, draft: draft) }
        .sheet(item: $model.agentSetup) { draft in AgentSetupView(model: model, draft: draft) }
        .sheet(item: $model.profileEditor) { draft in ProfileEditor(model: model, draft: draft) }
        .alert("That didn't work", isPresented: flag(model.errorMessage != nil) { model.errorMessage = nil }) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Delete item?", isPresented: flag(model.pendingDelete != nil) { model.pendingDelete = nil }) {
            Button("Cancel", role: .cancel) { model.pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = model.pendingDelete { model.deleteItem(item) }; model.pendingDelete = nil
            }
        } message: { Text("‘\(model.pendingDelete?.path ?? "")’ will be removed from all your Macs. Items that are in use stay protected.") }
        .alert("Delete profile?", isPresented: flag(deletingProfile != nil) { deletingProfile = nil }) {
            Button("Cancel", role: .cancel) { deletingProfile = nil }
            Button("Delete", role: .destructive) {
                if let profile = deletingProfile { model.deleteProfile(profile) }; deletingProfile = nil
            }
        } message: { Text("The bindings are removed. Your stored items are kept.") }
        .alert("Delete target?", isPresented: flag(deletingTarget != nil) { deletingTarget = nil }) {
            Button("Cancel", role: .cancel) { deletingTarget = nil }
            Button("Delete", role: .destructive) {
                if let name = deletingTarget { model.deleteTarget(named: name); model.refreshTargets() }; deletingTarget = nil
            }
        } message: { Text("‘\(deletingTarget ?? "")’ will be removed from the list. Values already pushed stay where they are.") }
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
                        Text("Your Items").font(.largeTitle.bold())
                        Text("Store it once. Use it on all your Macs and in your projects.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Add Item", systemImage: "plus") { model.itemEditor = ItemDraft(revision: model.configuration.revision) }
                        .buttonStyle(.borderedProminent)
                }
                if model.items.isEmpty {
                    ContentUnavailableView {
                        Label("Everything in one place", systemImage: "key.horizontal.fill")
                    } description: {
                        Text("Add your first credential. Values live in the keychain and sync through iCloud.")
                    } actions: {
                        Button("Add First Item") { model.itemEditor = ItemDraft(revision: model.configuration.revision) }
                    }.frame(maxHeight: .infinity)
                } else {
                    TextField("Search", text: $search, prompt: Text("Search path, field or identifier"))
                        .textFieldStyle(.roundedBorder)
                    List(selection: $model.selectedItem) {
                        ForEach(Dictionary(grouping: filteredItems, by: \.group).sorted { $0.key < $1.key }, id: \.key) { group, items in
                            Section(group) {
                                ForEach(items.sorted { $0.path < $1.path }) { item in itemRow(item).tag(item.id) }
                            }
                        }
                    }
                    .listStyle(.inset)
                    // Double-click edits; right-click offers edit and delete; the Delete key deletes.
                    .contextMenu(forSelectionType: UUID.self) { ids in
                        if let item = ids.first.flatMap(model.item) {
                            Button("Edit …") { model.edit(item) }
                            Button("Delete …", role: .destructive) { model.pendingDelete = item }
                        }
                    } primaryAction: { ids in
                        if let item = ids.first.flatMap(model.item) { model.edit(item) }
                    }
                    .onDeleteCommand { if let item = model.currentItem { model.pendingDelete = item } }
                    .overlay { if filteredItems.isEmpty { ContentUnavailableView.search(text: search) } }
                }
                Label("Values stay in the macOS keychain.", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(minWidth: 380, idealWidth: 460, maxHeight: .infinity, alignment: .topLeading)
            Group {
                if let item = model.currentItem { ItemDetail(model: model, item: item, delete: { model.pendingDelete = item }).id(item.id) }
                else {
                    ContentUnavailableView("No Item Selected", systemImage: "sidebar.right",
                                           description: Text("Select an item on the left to see its fields."))
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
                    Text("Targets").font(.largeTitle.bold())
                    Text("Places outside your Macs that hold copies of values.").foregroundStyle(.secondary)
                }
                Label("You push from Terminal and create targets with the CLI (secretariat target add …).", systemImage: "terminal")
                    .font(.callout).foregroundStyle(.secondary)
                if let targets = model.targetReport?.targets, !targets.isEmpty {
                    ForEach(targets, id: \.name) { target in targetCard(target) }
                } else {
                    ContentUnavailableView("No Targets Yet", systemImage: "arrow.up.forward.app",
                                           description: Text("Create a target in Terminal, for example for a Cloudflare Worker or an .env file on a server."))
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
                    if let pushedAt = target.pushedAt { Text("Last pushed: \(pushedAt)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button("Copy Command", systemImage: "doc.on.doc") { model.copyText("secretariat push \(shellQuote(target.name))") }
                Button { deletingTarget = target.name } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Delete target \(target.name)")
            }
            if target.variables.isEmpty {
                Text("No variable is mapped to this target yet.").foregroundStyle(.secondary)
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
                Button("Edit") { model.profileEditor = ProfileDraft(profile: profile, revision: model.configuration.revision) }
            }
            Divider()
            Text("Values for this project").font(.headline)
            if profile.bindings.isEmpty {
                Text("No fields are bound to this profile yet.").foregroundStyle(.secondary)
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
                Text("Start in Terminal").font(.headline)
                Text(profile.command.isEmpty ? "Add a start command under Edit." : profile.command)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Button(model.copied ? "Command Copied" : "Copy Terminal Command", systemImage: model.copied ? "checkmark" : "terminal") {
                    model.copyLaunch(profile)
                }.buttonStyle(.borderedProminent).disabled(profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Paste the command into Terminal. The program receives the bound values at launch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Use with coding agents").font(.headline)
                Text("Prepare project instructions for Codex, Claude Code and OpenCode.")
                    .foregroundStyle(.secondary)
                Button("Set Up Coding Agent", systemImage: "terminal.fill") { model.openAgentSetup(profile) }
            }
            Spacer()
            Button("Delete Profile", role: .destructive) { deletingProfile = profile }.buttonStyle(.borderless)
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
                    Button("Edit") { model.edit(item) }
                    Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    if !item.source.isEmpty { info("Source", item.source) }
                    if let expires = item.expires {
                        GridRow {
                            Text("Expires").foregroundStyle(.secondary)
                            HStack { Text(expires); ExpiryBadge(date: expires) }
                        }
                    }
                    if let rotated = item.rotated { info("Last changed", rotated) }
                    let usages = model.usages(of: item.id)
                    info("Used in", usages.isEmpty ? "Nowhere yet" : usages.joined(separator: ", "))
                }.font(.callout)
                Divider()
                Text("Fields").font(.headline)
                VStack(spacing: 0) {
                    ForEach(item.fields) { field in
                        fieldRow(field).padding(.vertical, 10)
                        Divider()
                    }
                }
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
                Button(revealed[field.name] == nil ? "Show" : "Hide") {
                    if revealed[field.name] == nil { revealed[field.name] = model.secretValue(item, field) }
                    else { revealed[field.name] = nil }
                }
                copyButton(field, secret: true) { model.secretValue(item, field) }
            case .file:
                Label(field.fileName ?? "File", systemImage: "doc").lineLimit(1)
                Spacer(minLength: 8)
                Button("Export …") { model.exportFile(item, field) }
            }
        }
    }

    private func copyButton(_ field: ItemField, secret: Bool = false, value: @escaping () -> String?) -> some View {
        Button(copiedField == field.name ? "Copied" : "Copy") {
            guard let text = value() else { return }
            if secret { model.copySecret(text) } else { model.copyText(text) }
            copiedField = field.name
        }.help(secret ? "The clipboard is cleared after 60 seconds." : "")
    }
}

struct ExpiryBadge: View {
    let date: String?
    var body: some View {
        if let days = daysUntil(date), days <= 30 {
            Text(days < 0 ? "expired" : days == 0 ? "expires today" : days == 1 ? "1 day left" : "\(days) days left")
                .font(.caption.bold()).padding(.horizontal, 7).padding(.vertical, 2)
                .foregroundStyle(.white).background(days < 0 ? Color.red : Color.orange, in: Capsule())
        }
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        let (title, color): (String, Color) = switch status {
        case "current": ("current", .green)
        case "stale": ("stale", .orange)
        case "never": ("never pushed", .gray)
        default: ("missing", .red)
        }
        Text(title).font(.caption.bold()).padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(.white).background(color, in: Capsule())
    }
}
