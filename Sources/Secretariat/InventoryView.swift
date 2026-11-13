import AppKit
import SwiftUI
import SecretariatCore

/// What the inventory shows: a finding, a decision, the open ones, or all.
enum InventoryFilter: Hashable {
    case open, all, finding(LoginAudit.Finding), decision(LoginAudit.Decision), closing(AccountDeletion.Difficulty)
    var title: String {
        switch self {
        case .open: "To Review"
        case .all: "All Logins"
        case .finding(let f): f.title
        case .decision(.keep): "Kept"
        case .decision(.close): "To Close"
        case .decision(.change): "To Change"
        case .closing(let d): d.title
        }
    }
    func matches(_ entry: LoginAudit.Entry) -> Bool {
        switch self {
        case .open: entry.decision == nil && !entry.findings.isEmpty
        case .all: true
        case .finding(let f): entry.findings.contains(f)
        case .decision(let d): entry.decision == d
        case .closing(let d): entry.deletion?.difficulty == d
        }
    }
    static let pickable: [InventoryFilter] = [.open, .all] + LoginAudit.Finding.allCases.map { .finding($0) }
        + LoginAudit.Decision.allCases.map { .decision($0) } + AccountDeletion.Difficulty.allCases.map { .closing($0) }
}

struct InventoryState {
    var entries: [LoginAudit.Entry] = []
    var facts: [UUID: LoginAudit.Facts] = [:]
    var online = LoginAudit.Online()
    var loading = false
    var checking: (done: Int, total: Int)?
    var filter = InventoryFilter.open
    /// Only logins found in this browser profile (nil: all).
    var origin: String?
}

extension AppModel {
    /// Reads every login's password once (in the background) and keeps only the facts.
    func loadInventory() {
        guard !inventory.loading else { return }
        inventory.loading = true
        let paths = paths
        Task {
            let (facts, online) = await Task.detached { () -> ([UUID: LoginAudit.Facts], LoginAudit.Online) in
                let vault = Vault(paths: paths)
                let items = (try? vault.list()) ?? []
                return (LoginAudit.facts(items, vault: vault), LoginAudit.loadOnline(paths))
            }.value
            inventory.facts = facts; inventory.online = online; inventory.loading = false
            rebuildInventory()
        }
    }

    func rebuildInventory() {
        inventory.entries = LoginAudit.entries(items, facts: inventory.facts, online: inventory.online)
    }

    var inventoryOrigins: [String] {
        Array(Set(inventory.entries.flatMap(\.origins))).sorted()
    }

    func inventoryEntries(_ filter: InventoryFilter) -> [LoginAudit.Entry] {
        inventory.entries.filter { entry in
            filter.matches(entry) && (inventory.origin.map { o in entry.origins.contains(o) } ?? true)
        }
    }

    func checkInventoryOnline() {
        guard inventory.checking == nil else { return }
        let items = items, facts = inventory.facts, online = inventory.online, paths = paths
        inventory.checking = (0, 1)
        Task {
            let result = await LoginAudit.checkOnline(items, facts: facts, online: online) { done, total in
                Task { @MainActor in self.inventory.checking = (done, total) }
            }
            try? LoginAudit.saveOnline(result, paths: paths)
            inventory.online = result; inventory.checking = nil
            rebuildInventory()
        }
    }

    func decide(_ entry: LoginAudit.Entry, _ decision: LoginAudit.Decision?) {
        do {
            try LoginAudit.decide(entry.item, decision, vault: vault)
            reload()
            rebuildInventory()
        } catch { errorMessage = error.localizedDescription }
    }
}

/// Middle column: profile and list choice, online check, the logins.
struct InventoryList: View {
    @Bindable var model: AppModel

    var body: some View {
        let entries = model.inventoryEntries(model.inventory.filter)
        List(selection: $model.selectedItem) {
            ListTitle(title: model.inventory.filter.title, count: entries.count, color: .indigo)
            Section {
                Picker("List", selection: $model.inventory.filter) {
                    ForEach(InventoryFilter.pickable, id: \.self) { filter in
                        Text("\(filter.title) (\(model.inventoryEntries(filter).count))").tag(filter)
                    }
                }
                Picker("Found in", selection: $model.inventory.origin) {
                    Text("All profiles").tag(String?.none)
                    ForEach(model.inventoryOrigins, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                onlineRow
            }
            .selectionDisabled()
            ForEach(entries) { entry in
                InventoryRow(entry: entry).tag(entry.id)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Inventory")
        .hidingToolbarTitle()
        .overlay {
            if model.inventory.loading && model.inventory.entries.isEmpty {
                ProgressView("Reading logins …")
            } else if entries.isEmpty {
                ContentUnavailableView("Nothing Here", systemImage: "checkmark.circle",
                                       description: Text(model.inventory.entries.isEmpty ? "No website logins yet. Import them with File → Import Passwords (CSV) …" : "No login in this list."))
            }
        }
        // Fresh facts each time the list opens: imports and edits since the last visit are included.
        .task { model.loadInventory() }
        .onChange(of: model.items.map(\.id)) { _, _ in model.rebuildInventory() }
    }

    @ViewBuilder private var onlineRow: some View {
        if let checking = model.inventory.checking {
            ProgressView(value: Double(checking.done), total: Double(max(checking.total, 1))) {
                Text("Checking domains and leaks … \(checking.done) of \(checking.total)")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(model.inventory.online.checked.map { "Checked online \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Leaks and domains not checked yet")
                    Spacer()
                    Button("Check Online") { model.checkInventoryOnline() }
                        .disabled(model.inventory.loading || model.inventory.facts.isEmpty)
                }
                Text("Asks DNS whether each domain still exists, and Have I Been Pwned with the first 5 characters of each password's hash. No password leaves the Mac.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct InventoryRow: View {
    let entry: LoginAudit.Entry

    var body: some View {
        HStack(spacing: 10) {
            KindIcon(symbol: "person.badge.key.fill", color: entry.decision == .keep ? .green : entry.findings.isEmpty ? .gray : .orange, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.host ?? entry.item.path).lineLimit(1)
                HStack(spacing: 6) {
                    if !entry.username.isEmpty { Text(entry.username).lineLimit(1) }
                    ForEach(LoginAudit.Finding.allCases.filter { entry.findings.contains($0) }, id: \.self) { finding in
                        Image(systemName: finding.symbol).help(finding.title).accessibilityLabel(finding.title)
                    }
                    if let guide = entry.deletion { Text(guide.difficulty.rawValue).foregroundStyle(guide.difficulty == .easy ? .green : .secondary) }
                    if let decision = entry.decision { Text(decision.title).foregroundStyle(.tint) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Right column: what was found, the decision, and the item itself.
struct InventoryDetail: View {
    @Bindable var model: AppModel
    let entry: LoginAudit.Entry

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    if entry.findings.isEmpty {
                        Label("Nothing found", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                    ForEach(LoginAudit.Finding.allCases.filter { entry.findings.contains($0) }, id: \.self) { finding in
                        Label(text(finding), systemImage: finding.symbol)
                    }
                    if !entry.origins.isEmpty { LabeledContent("Found in", value: entry.origins.joined(separator: ", ")) }
                } header: { Text("Inventory") }
                Section {
                    Picker("Decision", selection: Binding(get: { entry.decision }, set: { model.decide(entry, $0) })) {
                        Text("Open").tag(LoginAudit.Decision?.none)
                        ForEach(LoginAudit.Decision.allCases, id: \.self) { Text($0.title).tag(LoginAudit.Decision?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        if let url = LoginAudit.changePasswordURL(entry) {
                            Button("Change Password …", systemImage: "key") { NSWorkspace.shared.open(url) }
                                .help("Opens the site's standard page for changing passwords")
                        }
                        if entry.deletion == nil, let url = LoginAudit.closeAccountURL(entry) {
                            Button("How to Close …", systemImage: "magnifyingglass") { NSWorkspace.shared.open(url) }
                                .help("Searches the web for how to delete this account")
                        }
                        Spacer()
                        Button("Delete Entry …", systemImage: "trash", role: .destructive) { model.pendingDelete = entry.item }
                            .help("Removes the login from Secretariat; the account on the site stays as it is")
                    }
                } footer: {
                    Text("Close the account on the site first, then delete the entry here. Keep marks logins you checked and still need.")
                }
                if let guide = entry.deletion {
                    Section {
                        LabeledContent(guide.difficulty.title) {
                            Button("Open Deletion Page …", systemImage: "arrow.up.forward.square") {
                                if let url = URL(string: guide.url) { NSWorkspace.shared.open(url) }
                            }
                        }
                        Text(guide.difficulty.explanation).foregroundStyle(.secondary)
                        if let notes = guide.notes { Text(notes).foregroundStyle(.secondary).textSelection(.enabled) }
                        if let email = guide.email {
                            LabeledContent("Write to", value: email).textSelection(.enabled)
                        }
                    } header: { Text("How to close") } footer: {
                        Text("Deletion guide for \(guide.name) from JustDeleteMe (MIT License).")
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(height: formHeight)
            Divider()
            ItemDetail(model: model, item: entry.item, delete: { model.pendingDelete = entry.item })
        }
    }

    private var formHeight: CGFloat {
        let guide = entry.deletion.map { 150 + ($0.notes == nil ? 0 : 60) + ($0.email == nil ? 0 : 28) } ?? 0
        return CGFloat(250 + max(entry.findings.count - 1, 0) * 28 + (entry.origins.isEmpty ? 0 : 28) + guide)
    }

    private func text(_ finding: LoginAudit.Finding) -> String {
        switch finding {
        case .local: "Local address (router, test server); usually safe to delete"
        case .reused: "Same password as " + entry.reusedWith.prefix(3).joined(separator: ", ") + (entry.reusedWith.count > 3 ? " and \(entry.reusedWith.count - 3) more" : "")
        case .weak: "Weak password: short or only one kind of character"
        case .leaked: "This password appears \((entry.leakCount ?? 0).formatted()) times in known leaks"
        case .domainGone: "\(entry.site ?? "The domain") no longer exists; the account is likely gone"
        }
    }
}
