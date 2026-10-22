import AppKit
import Observation
import SecretariatCore

struct SecretDraft: Identifiable {
    let id = UUID()
    var existingID: UUID?
    var name = ""
    var value = ""
    var revision = 0
}
struct ProfileDraft: Identifiable {
    let id = UUID()
    var profile = Profile()
    var revision = 0
}

@Observable
final class AppModel {
    let paths = AppPaths()
    var configuration = Configuration()
    var selection = "keys"
    var errorMessage: String?
    var loadFailed = false
    var secretEditor: SecretDraft?
    var profileEditor: ProfileDraft?
    var copied = false

    init() { reload() }
    var vault: Vault { Vault(paths: paths, expectedRevision: configuration.revision) }
    var currentProfile: Profile? { configuration.profiles.first { $0.id.uuidString == selection } }
    var launcherPath: String {
        let installed = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/secretariat")
        if installed.resolvingSymlinksInPath().path == Bundle.main.executableURL?.path { return installed.path }
        return Bundle.main.executableURL?.path ?? "secretariat"
    }

    func reload() {
        do {
            configuration = try ConfigurationStore(paths: paths).load()
            loadFailed = false
        } catch { loadFailed = true; errorMessage = error.localizedDescription }
    }
    @discardableResult func perform(_ action: () throws -> Void) -> Bool {
        do { try action(); reload(); copied = false; return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func saveSecret(_ draft: SecretDraft) -> Bool {
        perform {
            let vault = Vault(paths: paths, expectedRevision: draft.revision)
            if let id = draft.existingID {
                try vault.updateSecret(id: id, name: draft.name, newValue: draft.value.isEmpty ? nil : draft.value)
            } else { try vault.addSecret(name: draft.name, value: draft.value) }
        }
    }
    func saveProfile(_ profile: Profile, expectedRevision: Int) -> Bool {
        let saved = perform { try Vault(paths: paths, expectedRevision: expectedRevision).saveProfile(profile) }
        if saved { selection = profile.id.uuidString }
        return saved
    }
    func deleteSecret(_ secret: SecretReference) { perform { try vault.deleteSecret(id: secret.id) } }
    func deleteProfile(_ profile: Profile) {
        if perform({ try vault.deleteProfile(id: profile.id) }) { selection = "keys" }
    }
    func copyLaunch(_ profile: Profile) {
        guard !profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Bitte im Profil einen Startbefehl eintragen."; return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(launchCommand(profile: profile, executable: launcherPath), forType: .string)
        copied = true
    }
    func usages(of id: UUID) -> [String] {
        configuration.profiles.filter { $0.bindings.contains { $0.secretID == id } }.map(\.name)
    }
}
