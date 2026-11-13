import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SecretariatCore

/// A browser's password export (CSV) on its way into the vault: preview without values, import, then the CSV to the trash.
struct PasswordImportDraft: Identifiable {
    let id = UUID()
    let file: URL
    var plan: PasswordImport.Plan
    var saved = 0
    var working = false
    var imported: [String]?
    var trashed = false
    var error: String?
}

extension AppModel {
    func choosePasswordFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a password export, e.g. “Google Passwords.csv” (Chrome → Google Password Manager → Settings → Export passwords)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let paths = paths
        Task {
            let result = await Task.detached { () -> Result<PasswordImport.Plan, Error> in
                Result {
                    guard let data = FileManager.default.contents(atPath: url.path), let text = String(data: data, encoding: .utf8) else {
                        throw SecretariatError("The file can't be read as text.")
                    }
                    return try PasswordImport.plan(PasswordImport.rows(text), vault: Vault(paths: paths), source: "Imported from \(url.lastPathComponent)")
                }
            }.value
            switch result {
            case .success(let plan): passwordImport = PasswordImportDraft(file: url, plan: plan)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    func importPasswords() {
        guard let draft = passwordImport, !draft.working else { return }
        passwordImport?.working = true; passwordImport?.error = nil
        let paths = paths, plan = draft.plan, file = draft.file.path
        Task {
            let result = await Task.detached { () -> Result<[String], Error> in
                Result {
                    try PasswordImport.apply(plan, vault: Vault(paths: paths), file: file) { count in
                        Task { @MainActor in self.passwordImport?.saved = count }
                    }
                }
            }.value
            passwordImport?.working = false
            switch result {
            case .success(let saved): passwordImport?.imported = saved
            case .failure(let error): passwordImport?.error = error.localizedDescription
            }
            reload()
        }
    }

    func trashPasswordFile() {
        guard let file = passwordImport?.file else { return }
        do { try FileManager.default.trashItem(at: file, resultingItemURL: nil); passwordImport?.trashed = true }
        catch { passwordImport?.error = "Couldn't move the file to the trash: \(error.localizedDescription)" }
    }
}

struct PasswordImportSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var draft: PasswordImportDraft? { model.passwordImport }

    var body: some View {
        if let draft {
            Form {
                Section {
                    HStack(spacing: 14) {
                        KindIcon(symbol: "person.badge.key.fill", color: .blue, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import Passwords").font(.title2.weight(.semibold))
                            Text(draft.file.lastPathComponent).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                if let error = draft.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
                if let imported = draft.imported {
                    done(imported.count, draft)
                } else {
                    preview(draft)
                }
            }
            .formStyle(.grouped)
            .toolbar {
                if draft.imported == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { model.passwordImport = nil; dismiss() }.keyboardShortcut(.cancelAction).disabled(draft.working)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(draft.plan.new.count == 1 ? "Import 1 Login" : "Import \(draft.plan.new.count) Logins") { model.importPasswords() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(draft.plan.new.isEmpty || draft.working)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { model.passwordImport = nil; dismiss() }.keyboardShortcut(.defaultAction)
                    }
                }
            }
            .frame(minWidth: 540, idealWidth: 580, minHeight: 480, idealHeight: 620)
        }
    }

    @ViewBuilder private func preview(_ draft: PasswordImportDraft) -> some View {
        let plan = draft.plan
        Section {
            LabeledContent("New logins", value: "\(plan.new.count)")
            LabeledContent("Already in Secretariat", value: "\(plan.alreadyThere.count)")
            if !plan.differs.isEmpty { LabeledContent("Different password than stored", value: "\(plan.differs.count)") }
            if plan.duplicates > 0 { LabeledContent("Repeated in the file", value: "\(plan.duplicates)") }
            if plan.withoutPassword > 0 { LabeledContent("Without password (skipped)", value: "\(plan.withoutPassword)") }
            if plan.unusable > 0 { LabeledContent("Without address or name (skipped)", value: "\(plan.unusable)") }
        } header: { Text("\(plan.rows) rows") } footer: {
            Text("Each login becomes a “Website login” item. Passwords and notes are “only for me”: no program ever gets them. Nothing that is already stored is changed.")
        }
        if draft.working {
            Section {
                ProgressView(value: Double(draft.saved), total: Double(max(plan.new.count, 1))) {
                    Text("Saving \(draft.saved) of \(plan.new.count) …")
                }
            }
        }
        if !plan.differs.isEmpty {
            Section {
                ForEach(plan.differs, id: \.self) { Text($0) }
            } header: { Text("Left alone") } footer: {
                Text("These logins exist with a different password. Check them by hand; the import does not overwrite them.")
            }
        }
        if !plan.new.isEmpty {
            Section("New") {
                ForEach(plan.new) { login in
                    LabeledContent(login.meta.path, value: login.username)
                }
            }
        }
    }

    @ViewBuilder private func done(_ count: Int, _ draft: PasswordImportDraft) -> some View {
        Section {
            Label(count == 1 ? "1 login imported." : "\(count) logins imported.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
        Section {
            if draft.trashed {
                Label("The CSV is in the trash. Empty the trash to remove it for good.", systemImage: "trash")
            } else {
                Text("“\(draft.file.lastPathComponent)” still holds every password in plain text.")
                Button("Move CSV to Trash", systemImage: "trash") { model.trashPasswordFile() }
            }
        } header: { Text("The export file") }
    }
}
