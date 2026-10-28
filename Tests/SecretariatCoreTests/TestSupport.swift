import Foundation
@testable import SecretariatCore

final class MemoryItems: ItemStore {
    var metas: [UUID: ItemMeta] = [:]
    var values: [UUID: [String: String]] = [:]
    var secretReads = 0
    var denied = false
    func list() throws -> [ItemMeta] { metas.values.sorted { $0.path < $1.path } }
    func secrets(id: UUID) throws -> [String: String] {
        secretReads += 1
        if denied { throw CredentialError.unavailable(-25293) }
        guard let v = values[id] else { throw CredentialError.notFound }
        return v
    }
    func save(_ meta: ItemMeta, secrets: [String: String]?) throws {
        metas[meta.id] = meta
        if let secrets { values[meta.id] = secrets } else if values[meta.id] == nil { values[meta.id] = [:] }
    }
    func delete(id: UUID) throws { metas[id] = nil; values[id] = nil }
}

/// Vault on a temporary home with an in-memory item store, one secret item and one profile.
struct AgentFixture {
    let root: URL
    let items = MemoryItems()
    let approver = SwitchApprover()
    let vault: Vault
    let profile: Profile
    let item: ItemMeta
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("secretariat-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let paths = AppPaths(directory: root.appendingPathComponent("vault"))
        vault = Vault(configuration: ConfigurationStore(paths: paths), items: items, approver: approver, audit: AuditLog(url: paths.auditLog))
        item = ItemMeta(path: "moinsen/test/api", kind: "api",
                        fields: [ItemField(name: "key_id", kind: .identifier, value: "KEY-123"), ItemField(name: "secret", kind: .secret),
                                 ItemField(name: "password", kind: .personal)])
        try vault.save(item, secrets: ["secret": "never-output-this-value", "password": "personal-never-out"])
        profile = Profile(name: "agent-test", directory: root.path, command: "echo not-run",
                          bindings: [Binding(variable: "TEST_API_KEY", itemID: item.id, field: "secret")])
        try vault.saveProfile(profile)
    }
    var service: AgentService { AgentService(vault: vault) }
    func preview(_ profile: Profile? = nil) throws -> InstructionPlan {
        try ProjectInstructions.preview(profile: profile ?? self.profile, executable: "/tmp/App's folder/Secretariat")
    }
    /// Runs a CLI command in-process; returns exit code and the JSON output.
    @discardableResult func cli(_ arguments: String...) throws -> (Int32, String) {
        let (code, json, _) = try Commands.dispatch(arguments + ["--json"], service: service, executable: "/tmp/secretariat")
        return (code, json ?? "")
    }
    func code(_ arguments: String...) -> String? {
        do { _ = try Commands.dispatch(arguments, service: service, executable: "/tmp/secretariat"); return nil }
        catch let e as AgentError { return e.code } catch is SecretariatError { return "invalid" } catch { return "other" }
    }
    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

/// Approver for tests: records reasons, allows or denies on demand.
final class SwitchApprover: Approver, @unchecked Sendable {
    var allow = true
    var reasons: [String] = []
    func approve(_ reason: String) throws {
        reasons.append(reason)
        if !allow { throw AgentError("approval_denied", "denied: \(reason)") }
    }
}
