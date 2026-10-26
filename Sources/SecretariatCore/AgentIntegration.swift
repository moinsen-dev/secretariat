import Foundation
import Darwin

public struct AgentError: LocalizedError, Sendable {
    public let code: String
    public let message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
}

// MARK: - Machine-readable results (names and identifiers only, never secret values)

public struct FieldInfo: Encodable, Sendable {
    public let name: String
    public let kind: String
    public let value: String?
    public let fileName: String?
    init(_ field: ItemField) {
        name = field.name; kind = field.kind.rawValue
        value = field.kind == .identifier ? field.value : nil; fileName = field.fileName
    }
}
public struct ItemInfo: Encodable, Sendable {
    public let path: String
    public let kind: String
    public let fields: [FieldInfo]
    public let expires: String?
    public let rotated: String?
    public let source: String
    public let usedBy: [String]
    init(_ item: ItemMeta, usedBy: [String]) {
        path = item.path; kind = item.kind.rawValue; fields = item.fields.map(FieldInfo.init)
        expires = item.expires; rotated = item.rotated; source = item.source; self.usedBy = usedBy
    }
}
public struct ItemList: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = true
    public let items: [ItemInfo]
}
public struct ItemResult: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = true
    public let item: ItemInfo
}
public struct ProfileInfo: Encodable, Sendable {
    public let name: String
    public let directory: String
    public let variables: [String]
    public let bindings: [String: String]
    init(_ profile: Profile, references: [String: String]) {
        name = profile.name; directory = profile.directory
        variables = profile.bindings.map(\.variable).sorted(); bindings = references
    }
}
public struct ProfileList: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = true
    public let profiles: [ProfileInfo]
}
public struct ProfileDescription: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = true
    public let profile: ProfileInfo
}
public struct VariableCheck: Encodable, Sendable {
    public let variable: String
    public let reference: String
    public let status: String
    public let keychainStatus: Int32?
}
public struct ProfileCheck: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok: Bool
    public let profile: String
    public let directoryExists: Bool
    public let variables: [VariableCheck]
}
public struct AgentFailure: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = false
    public let error: AgentErrorInfo
    public struct AgentErrorInfo: Encodable, Sendable {
        public let code: String
        public let message: String
    }
    public init(_ error: Error) {
        if let error = error as? AgentError {
            self.error = .init(code: error.code, message: error.message)
        } else if let error = error as? SecretariatError {
            // Our own messages name paths and fields, never values.
            self.error = .init(code: "invalid", message: error.message)
        } else {
            // A provider error may include its input. Keep machine responses independent of it.
            self.error = .init(code: "operation_failed", message: "Die Aktion konnte nicht abgeschlossen werden. Bitte die Konfiguration und Zugriffsrechte prüfen.")
        }
    }
}

public struct AgentService {
    public let vault: Vault
    public init(vault: Vault) { self.vault = vault }
    public init(paths: AppPaths = AppPaths()) { vault = Vault(paths: paths) }
    var configuration: ConfigurationStore { vault.configuration }

    func reference(_ binding: Binding, in items: [ItemMeta]) -> String {
        guard let item = items.first(where: { $0.id == binding.itemID }) else { return "(fehlt)/\(binding.field)" }
        return "\(item.path)/\(binding.field)"
    }
    func info(_ profile: Profile, items: [ItemMeta]) -> ProfileInfo {
        ProfileInfo(profile, references: Dictionary(uniqueKeysWithValues: profile.bindings.map { ($0.variable, reference($0, in: items)) }))
    }

    public func profiles() throws -> ProfileList {
        let items = (try? vault.list()) ?? []
        return ProfileList(profiles: try configuration.load().profiles.sorted { $0.name < $1.name }.map { info($0, items: items) })
    }
    public func profile(named name: String) throws -> Profile {
        guard let profile = try configuration.load().profiles.first(where: { $0.name == name }) else {
            throw AgentError("profile_not_found", "Profil nicht gefunden. Verfügbare Profile: secretariat profiles --json")
        }
        return profile
    }
    public func describe(_ name: String) throws -> ProfileDescription {
        ProfileDescription(profile: info(try profile(named: name), items: (try? vault.list()) ?? []))
    }
    public func check(_ name: String) throws -> ProfileCheck {
        let profile = try profile(named: name)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: profile.directory, isDirectory: &isDirectory) && isDirectory.boolValue
        let items = (try? vault.list()) ?? []
        let variables = profile.bindings.sorted { $0.variable < $1.variable }.map { binding in
            var status = "available"
            var keychainStatus: Int32?
            do { _ = try vault.value(itemID: binding.itemID, field: binding.field) }
            catch let error as AgentError { status = error.code == "personal_field" ? "personal" : "missing" }
            catch CredentialError.notFound { status = "missing" }
            catch CredentialError.unavailable(let code) { status = "unavailable"; keychainStatus = code }
            catch { status = "unavailable" }
            return VariableCheck(variable: binding.variable, reference: reference(binding, in: items), status: status, keychainStatus: keychainStatus)
        }
        return ProfileCheck(ok: exists && variables.allSatisfy { $0.status == "available" }, profile: name,
                            directoryExists: exists, variables: variables)
    }
}

// Security.framework can stall even for a noninteractive lookup. Keep agent calls
// bounded; exiting the CLI also cancels its pending OS request.
final class CheckWatchdog: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let output: Data
    init(output: String) { self.output = Data((output + "\n").utf8) }
    func start() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [self] in
            lock.lock()
            if completed { lock.unlock(); return }
            completed = true
            FileHandle.standardOutput.write(output)
            Darwin.exit(2)
        }
    }
    @discardableResult func finish() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let wasActive = !completed; completed = true
        return wasActive
    }
}
