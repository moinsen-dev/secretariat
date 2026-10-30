import SwiftUI
import SecretariatCore

/// Three columns like Notes and Reminders: lists on the left, the items of the chosen list in the middle, the item on the right.
struct MainView: View {
    @Bindable var model: AppModel
    @State private var deletingProfile: Profile?
    @State private var deletingTarget: String?
    @State private var deletingTemplate: Template?
    @State private var search = ""
    @AppStorage("sidebar.accounts") private var accountsOpen = true
    @AppStorage("sidebar.projects") private var projectsOpen = true

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } content: {
            content.navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 480)
        } detail: {
            detail
        }
        // One search across all items, profiles and targets. ⌘F focuses it.
        .searchable(text: $search, placement: .sidebar, prompt: Text("Search"))
        .onChange(of: model.selection) { _, selection in
            model.copied = false
            if selection == "targets" { model.refreshTargets() }
            if let id = model.selectedItem, !visibleItems.contains(where: { $0.id == id }) { model.selectedItem = nil }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { CaptureController.shared.show() } label: { Label("Capture Clipboard", systemImage: "doc.on.clipboard") }
                    .help("Save what you copied to the Inbox (⌃⌥⌘V from any app)")
                Button { model.itemEditor = model.newItemDraft() } label: { Label("New Item", systemImage: "square.and.pencil") }
                    .help("New item (⌘N)")
            }
            if let badge = licenseBadge {
                ToolbarItem { Button { model.showLicense = true } label: { Text(badge) }.help("Secretariat license") }
            }
        }
        .sheet(isPresented: $model.showLicense) { LicenseView(model: model) }
        .sheet(item: $model.itemEditor) { draft in ItemEditor(model: model, draft: draft) }
        .sheet(item: $model.agentSetup) { draft in AgentSetupView(model: model, draft: draft) }
        .sheet(item: $model.profileEditor) { draft in ProfileEditor(model: model, draft: draft) }
        .sheet(item: $model.templateEditor) { draft in TemplateEditor(model: model, draft: draft) }
        .sheet(item: $model.screenshotDraft) { draft in ScreenshotComposer(model: model, draft: draft) }
        .alert("That didn't work", isPresented: flag(model.errorMessage != nil) { model.errorMessage = nil }) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Delete item?", isPresented: flag(model.pendingDelete != nil) { model.pendingDelete = nil }) {
            Button("Cancel", role: .cancel) { model.pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = model.pendingDelete { model.deleteItem(item) }; model.pendingDelete = nil
            }
        } message: { Text("‘\(model.pendingDelete?.path ?? "")’ will be removed from all your Macs. Items that are in use stay protected.") }
        .alert("Delete screenshot?", isPresented: flag(model.pendingScreenshotDelete != nil) { model.pendingScreenshotDelete = nil }) {
            Button("Cancel", role: .cancel) { model.pendingScreenshotDelete = nil }
            Button("Delete", role: .destructive) {
                if let shot = model.pendingScreenshotDelete { model.deleteScreenshot(shot) }; model.pendingScreenshotDelete = nil
            }
        } message: { Text("‘\(model.pendingScreenshotDelete?.title ?? "")’ and its note will be removed from all your Macs.") }
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
        .alert("Delete template?", isPresented: flag(deletingTemplate != nil) { deletingTemplate = nil }) {
            Button("Cancel", role: .cancel) { deletingTemplate = nil }
            Button(deletingTemplate?.isBuiltin == true ? "Hide" : "Delete", role: .destructive) {
                if let template = deletingTemplate { model.deleteTemplate(template) }; deletingTemplate = nil
            }
        } message: {
            Text(deletingTemplate?.isBuiltin == true
                 ? "The built-in template ‘\(deletingTemplate?.title ?? "")’ will be hidden on all your Macs. You can restore it later. Existing items keep their fields."
                 : "‘\(deletingTemplate?.title ?? "")’ will be removed from all your Macs. Existing items keep their fields and show plain field names.")
        }
    }

    private func flag(_ value: Bool, clear: @escaping () -> Void) -> SwiftUI.Binding<Bool> {
        SwiftUI.Binding(get: { value }, set: { if !$0 { clear() } })
    }

    // MARK: Sidebar

    private var inbox: [ItemMeta] { model.items.filter(Capture.isCapture) }
    private var stored: [ItemMeta] { model.items.filter { !Capture.isCapture($0) } }
    private var expiring: [ItemMeta] { stored.filter { (daysUntil($0.expires) ?? .max) <= 30 } }
    private var guarded: [ItemMeta] { stored.filter(\.needsApproval) }
    private var accounts: [(name: String, count: Int)] {
        Dictionary(grouping: stored, by: \.group).map { ($0.key, $0.value.count) }.sorted { $0.name < $1.name }
    }

    private var sidebar: some View {
        List(selection: $model.selection) {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    SmartTile(title: "Inbox", symbol: "tray.fill", color: .blue, count: inbox.count, selected: model.selection == "inbox") { model.selection = "inbox" }
                    SmartTile(title: "All", symbol: "key.horizontal.fill", color: .gray, count: stored.count, selected: model.selection == "items") { model.selection = "items" }
                    SmartTile(title: "Expiring", symbol: "clock.fill", color: .orange, count: expiring.count, selected: model.selection == "expiring") { model.selection = "expiring" }
                    SmartTile(title: "Touch ID", symbol: "touchid", color: .pink, count: guarded.count, selected: model.selection == "approval") { model.selection = "approval" }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .selectionDisabled()
            }
            Section("Projects", isExpanded: $projectsOpen) {
                ForEach(filteredProfiles) { profile in
                    Label(profile.name, systemImage: "folder.fill").badge(profile.bindings.count).tag(profile.id.uuidString)
                        .contextMenu {
                            Button("Edit …") { model.profileEditor = ProfileDraft(profile: profile, revision: model.configuration.revision) }
                            Button("Delete …", role: .destructive) { deletingProfile = profile }
                        }
                }
            }
            Section("Accounts", isExpanded: $accountsOpen) {
                ForEach(accounts, id: \.name) { account in
                    Label(account.name, systemImage: "building.2").badge(account.count).tag("group:" + account.name)
                }
            }
            Section("Library") {
                Label("Targets", systemImage: "arrow.up.forward.app").tag("targets")
                Label("Templates", systemImage: "square.grid.2x2").tag("templates")
                Label("Screenshots", systemImage: "photo.on.rectangle").badge(model.screenshots.count).tag("screenshots")
                Label("History", systemImage: "clock.arrow.circlepath").tag("history")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button { model.profileEditor = ProfileDraft(revision: model.configuration.revision) } label: {
                Label("New Project", systemImage: "plus.circle").frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderless).padding(12)
        }
    }

    // MARK: Middle column

    private var query: String { search.trimmingCharacters(in: .whitespaces).lowercased() }
    private func matches(_ item: ItemMeta) -> Bool {
        item.path.lowercased().contains(query) || model.template(item.kind).title.lowercased().contains(query)
            || item.source.lowercased().contains(query) || item.fields.contains {
                $0.name.lowercased().contains(query) || ($0.value?.lowercased().contains(query) ?? false)
                    || (model.template(item.kind).spec($0.name)?.label.lowercased().contains(query) ?? false)
            }
    }
    private var filteredProfiles: [Profile] {
        let profiles = model.configuration.profiles.sorted { $0.name < $1.name }
        guard !query.isEmpty else { return profiles }
        let pathsByID = Dictionary(uniqueKeysWithValues: model.items.map { ($0.id, $0.path) })
        return profiles.filter { p in
            p.name.lowercased().contains(query) || p.directory.lowercased().contains(query)
                || p.bindings.contains { $0.variable.lowercased().contains(query) || (pathsByID[$0.itemID]?.lowercased().contains(query) ?? false) }
        }
    }

    /// The items the middle column shows for the current list (search runs across everything).
    private var visibleItems: [ItemMeta] {
        if !query.isEmpty { return model.items.filter(matches) }
        switch model.selection {
        case "inbox": return inbox.sorted { (Capture.capturedAt($0) ?? "") > (Capture.capturedAt($1) ?? "") }
        case "expiring": return expiring.sorted { ($0.expires ?? "") < ($1.expires ?? "") }
        case "approval": return guarded
        case let s where s.hasPrefix("group:"): return stored.filter { $0.group == s.dropFirst(6) }
        default: return stored
        }
    }
    private var listTitle: String {
        if !query.isEmpty { return "Search" }
        switch model.selection {
        case "inbox": return "Inbox"
        case "expiring": return "Expiring"
        case "approval": return "Touch ID"
        case let s where s.hasPrefix("group:"): return String(s.dropFirst(6))
        default: return "All Items"
        }
    }

    @ViewBuilder private var content: some View {
        if model.loadFailed {
            ContentUnavailableView {
                Label("Couldn't load data", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Your existing data is kept. Please check the configuration and reload.")
            } actions: { Button("Reload") { model.reload() } }
        } else if model.selection == "history" {
            HistorySummary(model: model)
        } else if model.selection == "screenshots" {
            // Searching here filters the screenshots by title and note.
            ScreenshotList(model: model, query: query)
        } else if let profile = model.currentProfile, query.isEmpty {
            profileList(profile)
        } else if model.selection == "targets" && query.isEmpty {
            targetsList
        } else if model.selection == "templates" && query.isEmpty {
            templatesList
        } else {
            itemList
        }
    }

    private var itemList: some View {
        let items = visibleItems
        let sectioned = model.selection == "items" || !query.isEmpty
        return List(selection: $model.selectedItem) {
            if sectioned {
                ForEach(Dictionary(grouping: items, by: \.group).sorted { $0.key < $1.key }, id: \.key) { group, members in
                    Section(group) {
                        ForEach(members.sorted { $0.path < $1.path }) { item in ItemRow(model: model, item: item, showGroup: false).tag(item.id) }
                    }
                }
            } else {
                ForEach(items) { item in
                    ItemRow(model: model, item: item, showGroup: !model.selection.hasPrefix("group:")).tag(item.id)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(listTitle)
        .navigationSubtitle(items.count == 1 ? "1 item" : "\(items.count) items")
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let item = ids.first.flatMap(model.item) {
                if Capture.isCapture(item) { Button("Turn into Item …") { model.file(item) } }
                else { Button("Edit …") { model.edit(item) } }
                Button("Delete …", role: .destructive) { model.pendingDelete = item }
            }
        } primaryAction: { ids in
            if let item = ids.first.flatMap(model.item) { Capture.isCapture(item) ? model.file(item) : model.edit(item) }
        }
        .onDeleteCommand { if let item = model.currentItem { model.pendingDelete = item } }
        .overlay { if items.isEmpty { emptyList } }
    }

    @ViewBuilder private var emptyList: some View {
        if !query.isEmpty { ContentUnavailableView.search(text: search) }
        else if model.selection == "inbox" {
            ContentUnavailableView {
                Label("Inbox Is Empty", systemImage: "tray")
            } description: {
                Text("Copy a credential in any app and press ⌃⌥⌘V. It lands here with date and time, and the clipboard is cleared.")
            } actions: { Button("Capture Clipboard") { CaptureController.shared.show() } }
        } else if model.items.isEmpty {
            ContentUnavailableView {
                Label("Everything in One Place", systemImage: "key.horizontal.fill")
            } description: {
                Text("Add your first credential. Values live in the keychain and sync through iCloud.")
            } actions: { Button("New Item") { model.itemEditor = model.newItemDraft() } }
        } else {
            ContentUnavailableView("Nothing Here", systemImage: "checkmark.circle", description: Text("No item in this list right now."))
        }
    }

    // MARK: Projects

    private func profileList(_ profile: Profile) -> some View {
        List(selection: $model.selectedItem) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(profile.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                        .foregroundStyle(.secondary).textSelection(.enabled)
                    Text(profile.command.isEmpty ? "No start command yet" : profile.command)
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(profile.command.isEmpty ? .tertiary : .primary)
                        .textSelection(.enabled).lineLimit(2)
                    HStack {
                        Button(model.copied ? "Copied" : "Copy Command", systemImage: model.copied ? "checkmark" : "terminal") { model.copyLaunch(profile) }
                            .disabled(profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Coding Agents …", systemImage: "sparkles") { model.openAgentSetup(profile) }
                    }.controlSize(.small)
                }.padding(.vertical, 6).selectionDisabled()
            }
            Section("Values") {
                if profile.bindings.isEmpty {
                    Text("No values bound yet. Use Edit to add them.").foregroundStyle(.secondary).selectionDisabled()
                }
                ForEach(profile.bindings) { binding in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(binding.variable).font(.system(.body, design: .monospaced).weight(.semibold))
                        Text(model.label(binding)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }.padding(.vertical, 3).tag(binding.itemID)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(profile.name)
        .navigationSubtitle(profile.bindings.count == 1 ? "1 value" : "\(profile.bindings.count) values")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Edit Project …") { model.profileEditor = ProfileDraft(profile: profile, revision: model.configuration.revision) }
                    Divider()
                    Button("Delete Project …", role: .destructive) { deletingProfile = profile }
                } label: { Label("Project", systemImage: "ellipsis.circle") }
            }
        }
    }

    // MARK: Targets

    private var targets: [Targets.TargetStatus] { model.targetReport?.targets ?? [] }

    private var targetsList: some View {
        List(selection: $model.selectedTarget) {
            ForEach(targets, id: \.name) { target in
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).font(.headline)
                    Text(target.destination).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }.padding(.vertical, 3).tag(target.name)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Targets")
        .navigationSubtitle("Places outside your Macs that hold copies")
        .overlay {
            if targets.isEmpty {
                ContentUnavailableView("No Targets Yet", systemImage: "arrow.up.forward.app",
                                       description: Text("Create a target in Terminal with secretariat target add …, for example for a Cloudflare Worker or an .env file on a server."))
            }
        }
    }

    private func targetDetail(_ target: Targets.TargetStatus) -> some View {
        Form {
            Section {
                DetailHeader(symbol: "arrow.up.forward.app", color: .teal, title: target.name, subtitle: target.destination)
            }
            Section("Variables") {
                if target.variables.isEmpty { Text("No variable is mapped to this target yet.").foregroundStyle(.secondary) }
                ForEach(target.variables, id: \.variable) { variable in
                    LabeledContent {
                        StatusBadge(status: variable.status)
                    } label: {
                        Text(variable.variable).font(.system(.body, design: .monospaced))
                        Text(variable.reference)
                    }
                }
            }
            Section {
                LabeledContent("Last pushed", value: target.pushedAt ?? "Never")
                LabeledContent("Push from Terminal") {
                    Button("Copy Command", systemImage: "doc.on.doc") { model.copyText("secretariat push \(shellQuote(target.name))") }
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem { Button(role: .destructive) { deletingTarget = target.name } label: { Label("Delete", systemImage: "trash") } }
        }
    }

    // MARK: Templates

    private var templatesList: some View {
        List(selection: $model.selectedTemplate) {
            Section {
                ForEach(model.catalog.all) { template in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title).font(.headline)
                            Text(template.fields.count == 1 ? "1 field" : "\(template.fields.count) fields").font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: template.symbol).foregroundStyle(.tint) }
                    .padding(.vertical, 3).tag(template.id)
                }
            }
            if !model.hiddenBuiltins.isEmpty {
                Section("Hidden") {
                    ForEach(model.hiddenBuiltins) { template in
                        HStack {
                            Label(template.title, systemImage: template.symbol).foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore") { model.resetTemplate(template) }.controlSize(.small)
                        }.selectionDisabled()
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Templates")
        .navigationSubtitle("What each kind of item asks for")
        .toolbar {
            ToolbarItem {
                Button { model.templateEditor = TemplateDraft(template: Template(id: "", title: ""), isNew: true) } label: {
                    Label("New Template", systemImage: "plus")
                }
            }
        }
    }

    private func templateDetail(_ template: Template) -> some View {
        Form {
            Section {
                DetailHeader(symbol: template.symbol, color: .accentColor, title: template.title,
                             subtitle: template.explanation.isEmpty ? template.id : template.explanation)
                if template.isBuiltin { LabeledContent("Built-in", value: model.isOverridden(template) ? "Changed by you" : "Unchanged") }
                if template.identity { LabeledContent("Identity", value: "Every agent session knows these values") }
            }
            Section("Fields") {
                ForEach(template.fields, id: \.name) { spec in
                    LabeledContent {
                        Text([spec.kind.title, spec.required ? "required" : nil, spec.envSuffix.map { "→ _\($0)" }].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(spec.label)
                        Text(spec.name).font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItemGroup {
                if model.isOverridden(template) { Button("Reset to Default") { model.resetTemplate(template) } }
                Button("Edit") { model.templateEditor = TemplateDraft(template: template, isNew: false) }
                Button(role: .destructive) { deletingTemplate = template } label: { Label(template.isBuiltin ? "Hide" : "Delete", systemImage: "trash") }
            }
        }
    }

    // MARK: Detail column

    @ViewBuilder private var detail: some View {
        if model.selection == "history" {
            HistoryList(model: model)
        } else if model.selection == "screenshots" {
            if let shot = model.screenshots.first(where: { $0.id == model.selectedScreenshot }) {
                ScreenshotDetail(model: model, shot: shot).id(shot.id)
            } else {
                ContentUnavailableView("No Screenshot Selected", systemImage: "photo.on.rectangle", description: Text("Select a screenshot to see it with its note."))
            }
        } else if model.selection == "targets" && query.isEmpty {
            if let target = targets.first(where: { $0.name == model.selectedTarget }) { targetDetail(target) }
            else { ContentUnavailableView("No Target Selected", systemImage: "arrow.up.forward.app") }
        } else if model.selection == "templates" && query.isEmpty {
            if let id = model.selectedTemplate, model.catalog.isKnown(id) { templateDetail(model.template(id)) }
            else { ContentUnavailableView("No Template Selected", systemImage: "square.grid.2x2") }
        } else if let item = model.currentItem {
            ItemDetail(model: model, item: item, delete: { model.pendingDelete = item }).id(item.id)
        } else {
            ContentUnavailableView("No Item Selected", systemImage: "key.horizontal", description: Text("Select an item to see its fields."))
        }
    }
}

/// Reminders-style smart list: colored icon, count, title.
struct SmartTile: View {
    let title: String
    let symbol: String
    let color: Color
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(selected ? color : .white)
                        .frame(width: 26, height: 26).background(selected ? AnyShapeStyle(.white) : AnyShapeStyle(color.gradient), in: Circle())
                    Spacer()
                    Text("\(count)").font(.title2.bold()).monospacedDigit()
                }
                Text(title).font(.callout.weight(.semibold)).foregroundStyle(selected ? .white : .secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selected ? .white : .primary)
            .background(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.quaternary.opacity(0.6)), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)")
    }
}

/// Notes-style row: bold title, then date and kind.
struct ItemRow: View {
    let model: AppModel
    let item: ItemMeta
    let showGroup: Bool

    private var title: String {
        if Capture.isCapture(item) {
            let name = Capture.name(of: item).replacingOccurrences(of: "-", with: " ")
            return name.isEmpty ? "Untitled capture" : name
        }
        let rest = item.path.dropFirst(item.group.count).drop { $0 == "/" }
        return rest.isEmpty ? String(item.path.split(separator: "/").last ?? "") : String(rest)
    }
    private var date: String? {
        if Capture.isCapture(item) { return Capture.capturedAt(item).flatMap(captureDate) }
        return item.rotated.flatMap(shortDate)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.template(item.kind).symbol).foregroundStyle(.tint).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    if let date { Text(date).foregroundStyle(.primary.opacity(0.75)) }
                    Text(showGroup && !Capture.isCapture(item) ? item.group : model.template(item.kind).title).foregroundStyle(.secondary)
                }.font(.subheadline).lineLimit(1)
            }
            Spacer(minLength: 6)
            if item.needsApproval { Image(systemName: "touchid").foregroundStyle(.pink).help("Needs Touch ID before a program uses it") }
            ExpiryBadge(date: item.expires)
        }.padding(.vertical, 3)
    }
}

private func shortDate(_ day: String) -> String? {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
    return f.date(from: day)?.formatted(date: .numeric, time: .omitted)
}
private func captureDate(_ stamp: String) -> String? {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: stamp)?.formatted(date: .abbreviated, time: .shortened)
}

/// Large icon and title at the top of a detail form.
struct DetailHeader: View {
    let symbol: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.white)
                .frame(width: 44, height: 44).background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title2.bold()).textSelection(.enabled).lineLimit(2)
                Text(subtitle).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(.vertical, 4)
    }
}

struct ItemDetail: View {
    let model: AppModel
    let item: ItemMeta
    let delete: () -> Void
    @State private var revealed: [String: String] = [:]
    @State private var copiedField: String?

    private var template: Template { model.template(item.kind) }

    var body: some View {
        Form {
            Section {
                DetailHeader(symbol: template.symbol, color: Capture.isCapture(item) ? .blue : .accentColor, title: item.path,
                             subtitle: template.title)
            }
            if Capture.isCapture(item) {
                Section {
                    Text("Captured from the clipboard. Give it a provider and project to use it; until then no program gets it.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Turn into Item …", systemImage: "arrow.right.doc.on.clipboard") { model.file(item) }
                        .buttonStyle(.borderedProminent)
                }
            }
            Section("Fields") {
                ForEach(item.fields) { field in fieldRow(field) }
            }
            Section("Details") {
                if !item.source.isEmpty { LabeledContent("Source") { Text(item.source).textSelection(.enabled) } }
                if let expires = item.expires {
                    LabeledContent("Expires") { HStack { Text(expires); ExpiryBadge(date: expires) } }
                }
                if let rotated = item.rotated { LabeledContent("Last changed", value: rotated) }
                let usages = model.usages(of: item.id)
                LabeledContent("Used in", value: usages.isEmpty ? "Nowhere yet" : usages.joined(separator: ", "))
                LabeledContent("Touch ID", value: item.needsApproval ? "Required before a program uses it" : "Not required")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItemGroup {
                if !Capture.isCapture(item) { Button("Edit") { model.edit(item) } }
                Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private func fieldRow(_ field: ItemField) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                switch field.kind {
                case .identifier:
                    Text(field.value ?? "").textSelection(.enabled).lineLimit(2)
                    copyButton(field) { field.value }
                case .secret, .personal:
                    Text(revealed[field.name] ?? "••••••••").font(.system(.body, design: .monospaced))
                        .foregroundStyle(revealed[field.name] == nil ? .tertiary : .primary).textSelection(.enabled).lineLimit(3)
                    Button {
                        if revealed[field.name] == nil { revealed[field.name] = model.secretValue(item, field, for: "show") }
                        else { revealed[field.name] = nil }
                    } label: { Image(systemName: revealed[field.name] == nil ? "eye" : "eye.slash") }
                        .buttonStyle(.borderless).help(revealed[field.name] == nil ? "Show" : "Hide")
                    copyButton(field, secret: true) { model.secretValue(item, field, for: "copy") }
                case .file:
                    Label(field.fileName ?? "File", systemImage: "doc").lineLimit(1)
                    Button("Export …") { model.exportFile(item, field) }
                }
            }
        } label: {
            Text(template.spec(field.name)?.label ?? field.name)
            Text("\(field.name) · \(field.kind.title)")
        }
    }

    private func copyButton(_ field: ItemField, secret: Bool = false, value: @escaping () -> String?) -> some View {
        Button {
            guard let text = value() else { return }
            if secret { model.copySecret(text) } else { model.copyText(text) }
            copiedField = field.name
        } label: { Image(systemName: copiedField == field.name ? "checkmark" : "doc.on.doc") }
            .buttonStyle(.borderless)
            .help(secret ? "Copy (the clipboard is cleared after 60 seconds)" : "Copy")
    }
}
extension MainView {
    /// Visible during the trial and after it; gone once licensed. Nothing is ever blocked.
    var licenseBadge: String? {
        switch model.license {
        case .licensed: nil
        case .trial(let days): "Trial · \(days) day\(days == 1 ? "" : "s") left"
        case .expired: "Trial ended · Buy license"
        }
    }
}

struct LicenseView: View {
    let model: AppModel
    @State private var text = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Secretariat License").font(.title2.bold())
            switch model.license {
            case .licensed(let email):
                Label(email.isEmpty ? "This build doesn't check licenses." : "Licensed to \(email). Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .trial(let days):
                Text("You're trying Secretariat: \(days) day\(days == 1 ? "" : "s") left. Everything works during the trial and afterwards — a license keeps the project going.")
            case .expired:
                Text("The 14-day trial has ended. Everything keeps working; please buy a license if Secretariat is useful to you.")
            }
            if case .licensed = model.license {} else {
                Text("Paste the license block from your purchase email. It is stored in your iCloud Keychain and covers all your Macs.")
                    .font(.callout).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .accessibilityLabel("License")
                if let error { Text(error).foregroundStyle(.red).font(.callout) }
            }
            HStack {
                if case .licensed = model.license {} else {
                    Button("Buy License (39 €)") { openURL(Licensing.buyURL) }
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                if case .licensed = model.license {} else {
                    Button("Activate") {
                        do { try model.activateLicense(text); error = nil; dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.keyboardShortcut(.defaultAction).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24).frame(width: 520)
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

struct TagBadge: View {
    let title: String
    var body: some View {
        Text(title).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 1)
            .foregroundStyle(.secondary).background(.quaternary, in: Capsule())
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
