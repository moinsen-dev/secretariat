import Foundation
import Darwin

public struct AgentError: LocalizedError, Sendable {
    public let code: String
    public let message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
}

public struct ProfileInfo: Encodable, Sendable {
    public let name: String
    public let directory: String
    public let variables: [String]
    public init(_ profile: Profile) {
        name = profile.name; directory = profile.directory
        variables = profile.bindings.map(\.variable).sorted()
    }
}
public struct ProfileList: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let profiles: [ProfileInfo]
}
public struct ProfileDescription: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let profile: ProfileInfo
}
public struct VariableCheck: Encodable, Sendable {
    public let variable: String
    public let status: String
    public let keychainStatus: Int32?
}
public struct ProfileCheck: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok: Bool
    public let profile: String
    public let directoryExists: Bool
    public let variables: [VariableCheck]
}
public struct AgentFailure: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = false
    public let error: AgentErrorInfo
    public struct AgentErrorInfo: Encodable, Sendable {
        public let code: String
        public let message: String
    }
    public init(_ error: Error) {
        if let error = error as? AgentError {
            self.error = .init(code: error.code, message: error.message)
        } else {
            // A provider error may include its input. Keep machine responses independent of it.
            self.error = .init(code: "operation_failed", message: "Die Aktion konnte nicht abgeschlossen werden. Bitte die Konfiguration und Zugriffsrechte prüfen.")
        }
    }
}

public struct AgentService {
    public let configuration: ConfigurationStore
    public let credentials: any CredentialStore
    public init(configuration: ConfigurationStore, credentials: any CredentialStore) {
        self.configuration = configuration; self.credentials = credentials
    }
    public init(paths: AppPaths = AppPaths()) {
        configuration = ConfigurationStore(paths: paths)
        credentials = paths.credentialStore(allowInteraction: false)
    }
    public func profiles() throws -> ProfileList {
        ProfileList(profiles: try configuration.load().profiles.sorted { $0.name < $1.name }.map(ProfileInfo.init))
    }
    public func profile(named name: String) throws -> Profile {
        guard let profile = try configuration.load().profiles.first(where: { $0.name == name }) else {
            throw AgentError("profile_not_found", "Profil nicht gefunden. Verfügbare Profile: secretariat profiles --json")
        }
        return profile
    }
    public func describe(_ name: String) throws -> ProfileDescription { ProfileDescription(profile: ProfileInfo(try profile(named: name))) }
    public func check(_ name: String) throws -> ProfileCheck {
        let profile = try profile(named: name)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: profile.directory, isDirectory: &isDirectory) && isDirectory.boolValue
        let variables = profile.bindings.sorted { $0.variable < $1.variable }.map { binding in
            let status: String
            var keychainStatus: Int32?
            do {
                let value = try credentials.read(id: binding.secretID)
                status = value.isEmpty || value.utf8.contains(0) ? "invalid" : "available"
            } catch CredentialError.notFound { status = "missing" }
            catch CredentialError.unavailable(let code) { status = "unavailable"; keychainStatus = code }
            catch { status = "unavailable" }
            return VariableCheck(variable: binding.variable, status: status, keychainStatus: keychainStatus)
        }
        return ProfileCheck(ok: exists && variables.allSatisfy { $0.status == "available" }, profile: name,
                            directoryExists: exists, variables: variables)
    }
}

public enum AgentCommand {
    public static func handles(_ command: String?) -> Bool {
        ["profiles", "describe", "check", "instructions", "setup", "keys", "profile"].contains(command ?? "")
    }
    public static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    public static func execute(_ arguments: [String], service: AgentService, executable: String) throws -> Int32 {
        if ["keys", "profile"].contains(arguments.first ?? "") { return try ProfileCommand.execute(arguments, service: service) }
        let machine = arguments.contains("--json")
        do {
            let command = arguments.first ?? ""
            let flags = arguments.dropFirst().filter { $0.hasPrefix("--") }
            let allowed = command == "setup" ? ["--json", "--dry-run"] : ["--json"]
            guard Set(flags).count == flags.count, flags.allSatisfy(allowed.contains) else {
                throw AgentError("invalid_arguments", "Unbekannte oder doppelte Option. Hilfe: secretariat --help")
            }
            let positional = arguments.dropFirst().filter { !$0.hasPrefix("--") }
            guard positional.count == (command == "profiles" ? 0 : 1), command != "instructions" || !machine else {
                throw AgentError("invalid_arguments", "Aufruf: secretariat \(command)\(command == "profiles" ? " [--json]" : " PROFIL")")
            }
            switch command {
            case "profiles":
                let result = try service.profiles()
                if machine { print(try json(result)) }
                else if result.profiles.isEmpty { print("Noch keine Profile. Bitte ein Profil in Secretariat anlegen.") }
                else { result.profiles.forEach { print("\($0.name)\t\($0.directory)") } }
            case "describe":
                let result = try service.describe(positional[0])
                if machine { print(try json(result)) }
                else { print("\(result.profile.name)\nOrdner: \(result.profile.directory)\nVariablen: \(result.profile.variables.joined(separator: ", "))") }
            case "check":
                let timeout = AgentError("keychain_timeout", "Der Schlüsselbund antwortet nicht rechtzeitig. Bitte den Zugriff in der Secretariat-App prüfen und erneut versuchen.")
                let watchdog = CheckWatchdog(output: machine ? try json(AgentFailure(timeout)) : timeout.message)
                watchdog.start()
                defer { _ = watchdog.finish() }
                let result = try service.check(positional[0])
                guard watchdog.finish() else { return 2 }
                if machine { print(try json(result)) }
                else {
                    print("\(result.profile): \(result.ok ? "bereit" : "nicht bereit")")
                    if !result.directoryExists { print("Projektordner fehlt.") }
                    result.variables.forEach { print("\($0.variable): \($0.status)") }
                    if !result.ok { print("Bitte Ordner bzw. Schlüssel in Secretariat prüfen. Dieser Aufruf öffnet keine Authentifizierungsdialoge.") }
                }
                return result.ok ? 0 : 2
            case "instructions":
                print(ProjectInstructions.body(profile: try service.profile(named: positional[0]), executable: executable))
            case "setup":
                let plan = try ProjectInstructions.preview(profile: service.profile(named: positional[0]), executable: executable)
                let dryRun = flags.contains("--dry-run")
                if !dryRun { try ProjectInstructions.apply(plan) }
                let result = SetupResult(plan: plan, dryRun: dryRun)
                if machine { print(try json(result)) }
                else {
                    print(dryRun ? "Vorschau – keine Dateien geändert:" : "Projektanweisungen eingerichtet:")
                    result.files.forEach { print("\($0.name): \($0.changed ? (dryRun ? "wird aktualisiert" : "aktualisiert") : "unverändert")") }
                    if dryRun { print("\n\(plan.instructions)") }
                }
            default: throw AgentError("invalid_arguments", "Unbekannte Aktion.")
            }
            return 0
        } catch {
            if machine { print(try json(AgentFailure(error))); return 1 }
            throw error
        }
    }
}

// Security.framework can stall even for a noninteractive lookup. Keep agent calls
// bounded; exiting the CLI also cancels its pending OS request. This does not
// create a child process or change normal run/GUI authentication behavior.
private final class CheckWatchdog: @unchecked Sendable {
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
