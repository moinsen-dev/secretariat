import AppKit
import LocalAuthentication
import SecretariatCore
import SwiftUI
import UniformTypeIdentifiers

// Secretariat in a team: own code, members, sharing and opening packages, offboarding.
// Everything here is app-only on purpose: no CLI command or agent can share, add members or open packages.

struct ShareDraft: Identifiable {
    let id = UUID()
    var items: Set<UUID>
    var recipients: Set<String> = []
    var search = ""
    var error: String?
    var working = false
}
struct OpenedShare: Identifiable {
    let id = UUID()
    let opened: Team.Opened
    let fileName: String
    var selected: Set<String>
    var result: Team.Imported?
    var error: String?
}
struct AddMemberDraft: Identifiable {
    let id = UUID()
    var code = ""
    var name = ""
    var error: String?
}
struct Offboarding: Identifiable {
    let id = UUID()
    let member: Team.Member
    let affected: [Team.Shared]
}

extension UTType {
    static let secretariatShare = UTType(exportedAs: "dev.moinsen.secretariat.share", conformingTo: .data)
}

extension AppModel {
    func loadTeam() {
        let vault = Vault(paths: paths)
        teamMembers = Team.members(vault: vault, managed: ManagedSettings(paths: paths))
        ownName = Team.ownName(vault: vault)
        if let key = try? Team.privateKey(vault: vault) {
            ownCode = (try? Team.ownCode(vault: vault)) ?? ""
            ownFingerprint = Team.fingerprint(key.publicKey.rawRepresentation)
        }
    }

    func copyOwnCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ownCode, forType: .string)
    }
    func renameSelf(_ name: String) {
        do { try Team.setOwnName(name, vault: Vault(paths: paths)); loadTeam() } catch { errorMessage = error.localizedDescription }
    }
    func resetOwnCode() {
        do { try Team.resetKey(vault: Vault(paths: paths)); loadTeam() } catch { errorMessage = error.localizedDescription }
    }
    func addMember(_ draft: AddMemberDraft) {
        do {
            let name = draft.name.trimmingCharacters(in: .whitespaces)
            let member = try Team.addMember(code: draft.code, name: name.isEmpty ? nil : name, vault: Vault(paths: paths))
            addMemberDraft = nil; loadTeam(); selectedMember = member.keyID
        } catch { addMemberDraft?.error = error.localizedDescription }
    }
    func removeMember(_ member: Team.Member) {
        do {
            let affected = try Team.removeMember(member, vault: Vault(paths: paths))
            loadTeam(); selectedMember = nil
            if !affected.isEmpty { offboarding = Offboarding(member: member, affected: affected) }
        } catch { errorMessage = error.localizedDescription }
    }
    func markForRotation(_ offboarding: Offboarding) {
        do {
            try Team.markForRotation(offboarding.affected.map(\.item), reason: "\(offboarding.member.name) left the team", vault: Vault(paths: paths))
            self.offboarding = nil; reload()
        } catch { errorMessage = error.localizedDescription }
    }

    func startShare(_ item: ItemMeta?) {
        shareDraft = ShareDraft(items: item.map { [$0.id] } ?? [])
    }

    /// Touch ID (or the Mac password) every time, then the save panel; the record of who got what is written only
    /// once the file exists.
    func share(_ draft: ShareDraft) {
        let chosen = items.filter { draft.items.contains($0.id) }.sorted { $0.path < $1.path }
        let recipients = teamMembers.filter { draft.recipients.contains($0.keyID) }
        guard !chosen.isEmpty, !recipients.isEmpty else { return }
        shareDraft?.working = true; shareDraft?.error = nil
        let names = recipients.map(\.name).joined(separator: ", ")
        Task {
            do {
                let context = LAContext()
                guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                       localizedReason: "share \(chosen.count) item\(chosen.count == 1 ? "" : "s") with \(names)") else { return }
                let vault = Vault(paths: paths)
                let stored = try chosen.map { Backup.StoredItem(meta: $0, secrets: try vault.items.secrets(id: $0.id)) }
                let data = try Team.package(items: stored, to: recipients, vault: vault)
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.secretariatShare]
                let who = recipients.count == 1 ? recipients[0].name : "\(recipients.count) people"
                // No item names in the file name: it travels through mail and chat (threat model: names never outside the sealed part).
                let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
                panel.nameFieldStringValue = "Secretariat share for \(who), \(day).\(Team.fileExtension)"
                panel.message = "Send this file to \(names) by mail, chat or AirDrop. Only they can open it."
                guard panel.runModal() == .OK, let url = panel.url else { shareDraft?.working = false; return }
                guard FileManager.default.createFile(atPath: url.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
                    throw SecretariatError("The file could not be written to \(url.path).")
                }
                try Team.recordShared(stored, to: recipients, vault: vault)
                shareDraft = nil
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
                shareDraft?.working = false
            } catch {
                shareDraft?.working = false; shareDraft?.error = error.localizedDescription
            }
        }
    }

    func chooseShareFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.secretariatShare]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a share package someone sent you."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openShare(url)
    }

    func openShare(_ url: URL) {
        do {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= 5 * 1024 * 1024 else { throw SecretariatError("This file is too large to be a share package.") }
            let opened = try Team.open(try Data(contentsOf: url), vault: Vault(paths: paths), managed: ManagedSettings(paths: paths))
            let present = Set(items.map { $0.path.lowercased() })
            openedShare = OpenedShare(opened: opened, fileName: url.lastPathComponent,
                                      selected: Set(opened.items.map(\.meta.path).filter { !present.contains($0.lowercased()) }))
            NSApplication.shared.activate(ignoringOtherApps: true)
        } catch { errorMessage = error.localizedDescription }
    }

    func importShare(_ share: OpenedShare) {
        do {
            let result = try Team.importItems(share.opened, only: share.selected, vault: Vault(paths: paths))
            reload()
            openedShare?.result = result
        } catch { openedShare?.error = error.localizedDescription }
    }
}

/// Opens share packages handed to the app by Finder (double-click) or `open`.
final class ShareOpener: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    var pending: [URL] = []
    func application(_ application: NSApplication, open urls: [URL]) {
        let shares = urls.filter { $0.pathExtension == Team.fileExtension }
        guard let model else { pending += shares; return }
        shares.first.map(model.openShare)
    }
}

// MARK: - Library → Team (middle column)

struct TeamSummary: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selectedMember) {
            ListTitle(title: "Team", count: model.teamMembers.count, color: .primary).selectionDisabled()
            Section {
                HStack(spacing: 10) {
                    KindIcon(symbol: "person.crop.circle.fill", color: .teal, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.ownName).font(.body.weight(.semibold)).lineLimit(1)
                        Text("You · your share code").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .tag(TeamSummary.selfTag)
            }
            Section("Members") {
                if model.teamMembers.isEmpty {
                    Text("No members yet. Add a colleague with their share code.").foregroundStyle(.secondary).selectionDisabled()
                }
                ForEach(model.teamMembers) { member in
                    HStack(spacing: 10) {
                        KindIcon(symbol: "person.fill", color: member.managed ? .indigo : .blue, size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(member.name).font(.body.weight(.semibold)).lineLimit(1)
                            Text(member.managed ? "Managed by your organization" : "\(Team.sharedWith(member, vault: Vault(paths: model.paths)).count) shared")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(member.keyID)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Team")
        .hidingToolbarTitle()
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button { model.addMemberDraft = AddMemberDraft() } label: { Label("Add Member", systemImage: "plus.circle.fill") }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Open Share …") { model.chooseShareFile() }.buttonStyle(.borderless)
            }
            .foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
    static let selfTag = "self"
}

/// Detail for "You": the code to hand out, its fingerprint, name and a new code.
struct OwnCodeDetail: View {
    @Bindable var model: AppModel
    @State private var editingName = false
    @State private var newName = ""
    @State private var confirmReset = false
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "person.crop.circle.fill", color: .teal, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.ownName).font(.title.bold())
                        Text("Your share code").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button(copied ? "Copied" : "Copy Code") { model.copyOwnCode(); copied = true }.glassButton()
                    Menu {
                        Button("Change Name …") { newName = model.ownName; editingName = true }
                        Divider()
                        Button("New Code …", role: .destructive) { confirmReset = true }
                    } label: { Image(systemName: "ellipsis") }
                        .menuIndicator(.hidden).fixedSize().glassButton().accessibilityLabel("More")
                }.padding(.vertical, 6)
            }
            Section {
                Text(model.ownCode).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .accessibilityLabel("Your share code")
                LabeledContent("Fingerprint") { Text(model.ownFingerprint).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
            } footer: {
                Text("Send the code to colleagues by mail or chat; they add you under Team. The code is public: it only lets them send you packages. Compare the fingerprint with them once by phone or in person.")
            }
        }
        .formStyle(.grouped)
        .alert("Your name in your code", isPresented: $editingName) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { model.renameSelf(newName) }
        } message: { Text("Colleagues see this name when they add you. Send them your code again afterwards.") }
        .confirmationDialog("Create a new share code?", isPresented: $confirmReset) {
            Button("New Code", role: .destructive) { model.resetOwnCode() }
        } message: {
            Text("Packages sent to your old code can no longer be opened. Every colleague has to add your new code.")
        }
    }
}

// MARK: - detail: one member

struct MemberDetail: View {
    @Bindable var model: AppModel
    let member: Team.Member
    @State private var confirmRemove = false

    private var shared: [Team.Shared] { Team.sharedWith(member, vault: Vault(paths: model.paths)) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "person.fill", color: member.managed ? .indigo : .blue, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name).font(.title.bold())
                        Text(member.managed ? "Managed by your organization" : "Team member").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !member.managed {
                        Menu {
                            Button("Remove from Team …", role: .destructive) { confirmRemove = true }
                        } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Member options") }
                        .menuStyle(.borderlessButton).fixedSize()
                    }
                }.padding(.vertical, 6)
            }
            Section {
                LabeledContent("Fingerprint") { Text(Team.fingerprint(member.key)).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
            } footer: {
                Text("Compare it with \(member.name) by phone or in person. If it differs, the code was changed on the way: remove the member.")
            }
            Section("Shared with \(member.name)") {
                if shared.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(shared, id: \.item) { entry in
                        LabeledContent(entry.path) { Text(entry.at.formatted(date: .abbreviated, time: .omitted)) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Remove \(member.name) from your team?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { model.removeMember(member) }
        } message: {
            Text("You can't send them packages any more. What they already received stays with them; the next step shows which keys to rotate.")
        }
    }
}

// MARK: - sheets

struct AddMemberSheet: View {
    @Bindable var model: AppModel
    @State var draft: AddMemberDraft
    @Environment(\.dismiss) private var dismiss
    @FocusState private var codeFocused: Bool

    private var parsed: (name: String, key: Data)? { try? Team.parse(code: draft.code) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "person.badge.plus", color: .blue, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Member").font(.title2.weight(.semibold))
                        Text("Paste the share code a colleague sent you.").foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }
            if let error = draft.error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            Section {
                TextField("Share code", text: $draft.code, prompt: Text("stc1:…"), axis: .vertical)
                    .lineLimit(2...4).font(.system(.body, design: .monospaced)).focused($codeFocused)
                    .accessibilityLabel("Share code")
                TextField("Name", text: $draft.name, prompt: Text(parsed?.name ?? "Optional"))
                    .accessibilityLabel("Name")
            } footer: {
                if let parsed {
                    Text("Fingerprint \(Team.fingerprint(parsed.key)). Compare it with \(parsed.name) by phone or in person before you share anything.")
                } else if !draft.code.isEmpty {
                    Text("This is not a complete share code yet.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { codeFocused = true }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { model.addMemberDraft = draft; model.addMember(draft); if model.addMemberDraft == nil { dismiss() } else { draft.error = model.addMemberDraft?.error } }
                    .keyboardShortcut(.defaultAction).disabled(parsed == nil)
            }
        }
        .frame(width: 520, height: 400)
    }
}

struct ShareSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var draft: ShareDraft { model.shareDraft ?? ShareDraft(items: []) }
    private var query: String { draft.search.trimmingCharacters(in: .whitespaces).lowercased() }
    private var candidates: [ItemMeta] {
        model.items.filter { query.isEmpty || $0.path.lowercased().contains(query) || draft.items.contains($0.id) }.sorted { $0.path < $1.path }
    }
    private func toggle(_ id: UUID) { if draft.items.contains(id) { model.shareDraft?.items.remove(id) } else { model.shareDraft?.items.insert(id) } }
    private func toggle(member: String) {
        if draft.recipients.contains(member) { model.shareDraft?.recipients.remove(member) } else { model.shareDraft?.recipients.insert(member) }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "square.and.arrow.up.fill", color: .teal, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share with Your Team").font(.title2.weight(.semibold))
                        Text("Sealed to each person's code. Only they can open the file.").foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }
            if let error = draft.error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            Section("With") {
                if model.teamMembers.isEmpty {
                    Text("Add a member first (Library → Team).").foregroundStyle(.secondary)
                }
                ForEach(model.teamMembers) { member in
                    Toggle(isOn: Binding(get: { draft.recipients.contains(member.keyID) }, set: { _ in toggle(member: member.keyID) })) {
                        Text(member.name)
                        Text(Team.fingerprint(member.key))
                    }
                    .accessibilityLabel("Share with \(member.name)")
                }
            }
            Section {
                TextField("Search", text: Binding(get: { draft.search }, set: { model.shareDraft?.search = $0 }), prompt: Text("Filter items"))
                    .accessibilityLabel("Filter items")
                ForEach(candidates) { item in
                    Toggle(isOn: Binding(get: { draft.items.contains(item.id) }, set: { _ in toggle(item.id) })) {
                        Text(item.path)
                        Text(item.fields.filter { $0.kind != .identifier }.map(\.name).joined(separator: ", "))
                    }
                    .accessibilityLabel("Include \(item.path)")
                }
            } header: { Text("Items (\(draft.items.count))") } footer: {
                Text("Every value of the chosen items travels in the package, also fields marked “only for me”. You confirm with Touch ID.")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.shareDraft = nil; dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Share …") { model.share(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.items.isEmpty || draft.recipients.isEmpty || draft.working)
            }
        }
        .frame(minWidth: 540, idealWidth: 560, minHeight: 480, idealHeight: 600)
    }
}

struct OpenShareSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var trustUnknown = false

    private var share: OpenedShare? { model.openedShare }
    private func present(_ path: String) -> Bool { model.items.contains { $0.path.lowercased() == path.lowercased() } }

    var body: some View {
        if let share {
            Form {
                Section {
                    HStack(spacing: 14) {
                        KindIcon(symbol: share.opened.sender == nil ? "exclamationmark.shield.fill" : "checkmark.seal.fill",
                                 color: share.opened.sender == nil ? .orange : .green, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(share.opened.sender.map { "From \($0.name)" } ?? "From an unknown sender").font(.title2.weight(.semibold))
                            Text("\(share.opened.items.count) item\(share.opened.items.count == 1 ? "" : "s") · \(share.opened.header.created.formatted(date: .abbreviated, time: .shortened))")
                                .foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                } footer: {
                    if share.opened.sender == nil {
                        Text("The package says it comes from “\(share.opened.header.sender)”, fingerprint \(Team.fingerprint(share.opened.header.senderKey)). That key is not in your team. Import only if you expected this file and checked the fingerprint with the sender.")
                            .foregroundStyle(.orange)
                    }
                }
                if let error = share.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
                if let result = share.result {
                    Section("Imported") {
                        if !result.added.isEmpty { LabeledContent("Added", value: "\(result.added.count)") }
                        if !result.skipped.isEmpty { LabeledContent("Already here, left unchanged", value: result.skipped.joined(separator: ", ")) }
                        ForEach(result.failed, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    }
                } else {
                    Section {
                        ForEach(share.opened.items, id: \.meta.id) { stored in
                            let exists = present(stored.meta.path)
                            Toggle(isOn: Binding(get: { share.selected.contains(stored.meta.path) }, set: { on in
                                if on { model.openedShare?.selected.insert(stored.meta.path) } else { model.openedShare?.selected.remove(stored.meta.path) }
                            })) {
                                Text(stored.meta.path)
                                Text(exists ? "Already here, stays unchanged" : model.template(stored.meta.kind).title
                                     + (stored.meta.needsApproval ? " · Touch ID" : ""))
                            }
                            .disabled(exists)
                            .accessibilityLabel("Import \(stored.meta.path)")
                        }
                    } header: { Text("Items") } footer: {
                        Text("New items are saved with “Shared by …” as their source. Existing items are never overwritten.")
                    }
                    if share.opened.sender == nil {
                        Section { Toggle("I expected this file and checked the fingerprint", isOn: $trustUnknown).accessibilityLabel("Trust unknown sender") }
                    }
                }
            }
            .formStyle(.grouped)
            .toolbar {
                if share.result == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.openedShare = nil; dismiss() }.keyboardShortcut(.cancelAction) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(share.opened.sender == nil ? "Import Anyway" : "Import") { model.importShare(share) }
                            .keyboardShortcut(.defaultAction)
                            .disabled(share.selected.isEmpty || (share.opened.sender == nil && !trustUnknown))
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { model.openedShare = nil; dismiss() }.keyboardShortcut(.defaultAction) }
                }
            }
            .frame(minWidth: 520, idealWidth: 560, minHeight: 420, idealHeight: 520)
        }
    }
}

struct OffboardingSheet: View {
    @Bindable var model: AppModel
    let offboarding: Offboarding
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "arrow.triangle.2.circlepath", color: .orange, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(offboarding.member.name) Has Left").font(.title2.weight(.semibold))
                        Text("They still have what you shared. Rotate these keys at the provider.").foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }
            Section {
                ForEach(offboarding.affected, id: \.item) { entry in
                    LabeledContent(entry.path) { Text(entry.at.formatted(date: .abbreviated, time: .omitted)) }
                }
            } header: { Text("Shared with \(offboarding.member.name)") } footer: {
                Text("Marked items show “Rotate” until you save a new value. After rotating, Targets lists every copy that still has the old one.")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Not Now") { model.offboarding = nil; dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Mark for Rotation") { model.markForRotation(offboarding); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 520, height: 420)
    }
}

/// In the item detail: who got this item, and whether its value changed since.
struct SharedWithSection: View {
    let model: AppModel
    let item: ItemMeta
    var body: some View {
        let shares = Team.shares(of: item.id, vault: Vault(paths: model.paths))
        if !shares.isEmpty || item.rotateReason != nil {
            Section("Team") {
                if let reason = item.rotateReason {
                    Label("Rotate: \(reason)", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
                }
                ForEach(shares, id: \.memberKey) { entry in
                    let changed = Team.changedSince(entry, vault: Vault(paths: model.paths))
                    LabeledContent("Shared with \(entry.member)") {
                        Text(entry.at.formatted(date: .abbreviated, time: .omitted) + (changed ? " · value changed since" : ""))
                            .foregroundStyle(changed ? .orange : .secondary)
                    }
                }
            }
        }
    }
}
