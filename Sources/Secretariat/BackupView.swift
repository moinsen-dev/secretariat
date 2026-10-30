import AppKit
import SwiftUI
import SecretariatCore

/// A recovery key that exists only in this sheet until the user confirmed they kept it.
struct BackupSetupDraft: Identifiable {
    let id = UUID()
    let recoveryKey = RecoveryKey.generate()
    /// Replacing an existing key: older backups keep needing the old one.
    let replacing: Bool
    /// Two groups, picked at random, the user types back to show the key was kept.
    let asked: [Int] = Array((0..<11).shuffled().prefix(2)).sorted()
    var groups: [String] { recoveryKey.split(separator: "-").map(String.init) }
}

extension AppModel {
    /// Backs up when set up and something changed (or none today yet), off the main thread; then refreshes the status.
    /// A reload during a running backup isn't dropped: it runs once more afterwards.
    func backUpAutomatically() {
        guard !backingUp else { backupAgain = true; return }
        backingUp = true
        let paths = paths
        Task {
            let status = await Task.detached { () -> Backup.Status in
                let vault = Vault(paths: paths)
                Backup.automatic(vault: vault)
                return Backup.status(vault: vault)
            }.value
            backupStatus = status
            backingUp = false
            if backupAgain { backupAgain = false; backUpAutomatically() }
        }
    }

    func backUpNow() {
        let paths = paths
        backingUp = true
        Task {
            let result = await Task.detached { () -> Result<Backup.Status, Error> in
                let vault = Vault(paths: paths)
                return Result { try Backup.write(vault: vault); return Backup.status(vault: vault) }
            }.value
            backingUp = false
            switch result {
            case .success(let status): backupStatus = status
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    /// Saves the public key of a confirmed recovery key and makes the first backup right away; after a suspected
    /// leak it can also remove the backups sealed to the old key.
    func finishBackupSetup(_ draft: BackupSetupDraft, removeOld: Bool = false) {
        guard perform({ _ = try Backup.setUp(vault: vault, recoveryKey: draft.recoveryKey) }) else { return }
        backupSetup = nil
        backingUp = true
        let paths = paths
        Task {
            // The first backup with the new key comes first; old-key backups go only once it exists.
            let result = await Task.detached { () -> Result<Backup.Status, Error> in
                let vault = Vault(paths: paths)
                return Result {
                    try Backup.write(vault: vault)
                    if removeOld, let key = Backup.status(vault: vault).key { Backup.removeBackups(notSealedTo: key, vault: vault) }
                    return Backup.status(vault: vault)
                }
            }.value
            backingUp = false
            switch result {
            case .success(let status): backupStatus = status
            case .failure(let error): errorMessage = "The first backup with the new key failed, so no old backup was removed. \(error.localizedDescription)"
            }
        }
    }

    func saveEmergencyKit(_ draft: BackupSetupDraft) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Secretariat Recovery Key.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let keyID = (try? RecoveryKey.privateKey(RecoveryKey.decode(draft.recoveryKey)).publicKey).map(RecoveryKey.keyID) ?? "?"
        let text = """
        Secretariat · Recovery Key
        Created \(Date().formatted(date: .long, time: .shortened)) on \(Host.current().localizedName ?? "this Mac") · key \(keyID)

            \(draft.recoveryKey)

        This key opens your Secretariat backups. Secretariat doesn't keep it anywhere.
        Keep this sheet outside your Macs: printed, or in your password manager.
        Without it, no one can read a backup, including you.

        To restore: Secretariat → Library → Backup → Restore …, choose a backup, enter this key.

        """
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Middle column: state and actions

struct BackupSummary: View {
    @Bindable var model: AppModel

    var body: some View {
        let status = model.backupStatus
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let problem = status?.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let status, status.configured {
                    Label("Backup is on", systemImage: "checkmark.shield.fill").font(.title3.weight(.semibold)).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 6) {
                        row("Last backup", status.last.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "none yet")
                        row("Where", status.location == "icloud" ? "iCloud Drive (Secretariat)" : "This Mac only")
                        row("Kept", "\(status.files.count) \(status.files.count == 1 ? "file" : "files") · newest 30 per Mac")
                        row("Recovery key", status.key ?? "?")
                    }
                    if status.location != "icloud" {
                        Label("iCloud Drive isn't available, so backups stay on this Mac. Turn on iCloud Drive to keep them off the Mac.",
                              systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
                    }
                    HStack {
                        Button("Back Up Now") { model.backUpNow() }.disabled(model.backingUp)
                        Button("Restore …") { model.showRestore = true }
                    }
                    KeyCheck(model: model)
                    if model.backingUp { ProgressView().controlSize(.small) }
                    Divider()
                    Text("Backups happen on their own: when Secretariat starts, after changes, and once a day from the command line. Each one is sealed so that only your recovery key opens it; this Mac can write backups but can't read them.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("New Recovery Key …") { model.backupSetup = BackupSetupDraft(replacing: true) }
                        .help("Future backups use the new key. Older backups still need the old one, unless you remove them.")
                } else {
                    Label("Backup isn't set up", systemImage: "exclamationmark.shield").font(.title3.weight(.semibold)).foregroundStyle(.orange)
                    Text("Secretariat can back up all items with their values, your projects, targets, templates and screenshot keys to iCloud Drive, automatically and encrypted. You get a recovery key once; only it opens a backup. Keep it outside your Macs.")
                        .foregroundStyle(.secondary)
                    Button("Set Up Backup …") { model.backupSetup = BackupSetupDraft(replacing: false) }
                        .buttonStyle(.borderedProminent)
                    Button("Restore …") { model.showRestore = true }
                        .help("Restore from a backup made on another Mac or before a reinstall.")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Backup")
        .navigationSubtitle(status?.configured == true ? "On" : "Off")
        .task { model.backUpAutomatically() }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
            Text(value).textSelection(.enabled)
        }
    }
}

// MARK: - Detail column: the backup files

struct BackupList: View {
    let model: AppModel

    var body: some View {
        let files = model.backupStatus?.files ?? []
        List(files, id: \.name) { file in
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.day)
                    Text(file.mac + (file.inCloudOnly ? " · in iCloud, loads when opened" : "")).font(.caption).foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: file.inCloudOnly ? "icloud.and.arrow.down" : "doc.badge.lock") }
        }
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("No Backups", systemImage: "externaldrive.badge.icloud",
                                       description: Text(model.backupStatus?.configured == true ? "The first one is on its way." : "Set up backup to start."))
            }
        }
    }
}

// MARK: - Setting up: show the key, have it kept, confirm

struct BackupSetupView: View {
    let model: AppModel
    let draft: BackupSetupDraft
    @State private var answers = ["", ""]
    @State private var removeOld = false
    @Environment(\.dismiss) private var dismiss

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1").replacingOccurrences(of: "L", with: "1")
    }
    private var confirmed: Bool { zip(draft.asked, answers).allSatisfy { draft.groups[$0] == normalized($1) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.replacing ? "New Recovery Key" : "Your Recovery Key").font(.title2.weight(.semibold))
            Text("This key opens your backups. Secretariat shows it only now and doesn't keep it. Save the emergency sheet or put the key into your password manager, outside this Mac.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if draft.replacing {
                Label("Backups made so far still need your previous key.", systemImage: "info.circle").font(.callout)
            }
            Text(draft.recoveryKey.replacingOccurrences(of: "-", with: " "))
                .font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Recovery key")
            HStack {
                Button("Save Emergency Sheet …") { model.saveEmergencyKit(draft) }
                Button("Copy") { model.copySecret(draft.recoveryKey) }.help("Copies the key; the clipboard is cleared after a minute.")
            }
            Divider()
            Text("To confirm you kept it, type groups \(draft.asked[0] + 1) and \(draft.asked[1] + 1) from your saved copy:").font(.callout)
            HStack {
                ForEach(0..<2, id: \.self) { k in
                    TextField("Group \(draft.asked[k] + 1)", text: $answers[k]).font(.system(.body, design: .monospaced)).frame(width: 120)
                }
            }
            if draft.replacing {
                Toggle("Delete backups made with the old key (if it may have leaked)", isOn: $removeOld)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(draft.replacing ? "Use New Key" : "Turn On Backup") { model.finishBackupSetup(draft, removeOld: removeOld) }
                    .keyboardShortcut(.defaultAction).disabled(!confirmed)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

// MARK: - Restoring: choose a file, enter the key, see what's in it, bring back what's missing

struct RestoreView: View {
    let model: AppModel
    @State private var file: URL?
    @State private var key = ""
    @State private var opened: (header: Backup.Header, payload: Backup.Payload)?
    @State private var restored: Backup.Restored?
    @State private var additions: [String] = []
    @State private var keepKey = true
    @State private var problem: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Restore from Backup").font(.title2.weight(.semibold))
            Text("Items, projects, targets, templates and screenshot keys that are missing here come back. Everything that exists stays exactly as it is.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Choose Backup …") { choose() }
                Text(file?.lastPathComponent ?? "No backup chosen").foregroundStyle(file == nil ? .secondary : .primary).lineLimit(1)
            }
            SecureField("Recovery key", text: $key).font(.system(.body, design: .monospaced))
            if let problem { Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout) }
            if let opened {
                let p = opened.payload
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backup from \(opened.header.mac), \(opened.header.created.formatted(date: .abbreviated, time: .shortened))").font(.headline)
                    Text("\(p.items.count) items · \(p.profiles.count) projects · \(p.targets.count) targets · \(p.templates.count) templates · \(p.screenshotKeys.count) screenshot keys")
                        .foregroundStyle(.secondary)
                    if restored == nil {
                        Text(additions.isEmpty ? "Nothing is missing here; a restore would change nothing." : "These come back (\(additions.count)):").font(.callout)
                        if !additions.isEmpty {
                            ScrollView { Text(additions.joined(separator: "\n")).font(.system(.callout, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }
                                .frame(maxHeight: 140)
                        }
                        if model.backupStatus?.configured != true {
                            Toggle("Use this recovery key for new backups on this Mac", isOn: $keepKey)
                        }
                    }
                }
            }
            if let restored {
                Label("Brought back: \(restored.items) items, \(restored.profiles) projects, \(restored.targets) targets, \(restored.templates) templates, \(restored.screenshotKeys) screenshot keys."
                      + (restored.skipped.isEmpty ? "" : " Left alone (same name, different entry here): \(restored.skipped.joined(separator: ", ")).")
                      + (restored.failed.isEmpty ? "" : " Could not bring back: \(restored.failed.joined(separator: "; ")).") ,
                      systemImage: "checkmark.circle").foregroundStyle(.green).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(restored == nil ? "Cancel" : "Done", role: .cancel) { dismiss() }
                if restored == nil {
                    if opened == nil {
                        Button("Open") { open() }.keyboardShortcut(.defaultAction).disabled(file == nil || key.isEmpty)
                    } else {
                        Button("Restore") { restore() }.keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 560)
        .onChange(of: key) { opened = nil; problem = nil }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let directory = model.backupStatus?.directory { panel.directoryURL = URL(fileURLWithPath: directory) }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        file = url; opened = nil; problem = nil
    }
    private func open() {
        guard let file else { return }
        do {
            let result = try Backup.open(file, recoveryKey: key)
            opened = result; problem = nil
            additions = Backup.additions(result.1, to: Vault(paths: model.paths))
        }
        catch { opened = nil; problem = error.localizedDescription }
    }
    private func restore() {
        guard let opened else { return }
        do {
            let vault = Vault(paths: model.paths)
            restored = try Backup.restore(opened.payload, into: vault)
            // A new Mac (or one that lost the backup key): keep backing up with the key that was just entered.
            if model.backupStatus?.configured != true, keepKey { _ = try Backup.setUp(vault: vault, recoveryKey: key) }
            key = ""
            model.reload()
        } catch { problem = error.localizedDescription }
    }
}

/// Checks a typed recovery key against the current backup key, without opening a backup.
struct KeyCheck: View {
    let model: AppModel
    @State private var key = ""
    @State private var result: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check your recovery key").font(.headline)
            HStack {
                SecureField("Recovery key", text: $key).font(.system(.body, design: .monospaced))
                Button("Check") {
                    result = (try? Backup.matches(key, vault: Vault(paths: model.paths))) ?? false
                    key = ""
                }.disabled(key.isEmpty)
            }
            if let result {
                Label(result ? "This key opens your backups." : "This key does not match your backups.",
                      systemImage: result ? "checkmark.circle" : "xmark.octagon").foregroundStyle(result ? .green : .red)
            }
        }
        .onChange(of: key) { if !key.isEmpty { result = nil } }
    }
}
