import Foundation

// Key names and profile management for agents. Everything goes through the same Vault as the app
// (lock, validation, revision). Key values never pass through here: there is deliberately no command
// that sets or reads a value — those stay in the app.

public struct KeyInfo: Encodable, Sendable {
    public let name: String
    public let id: UUID
    public let profiles: [String]
}
public struct KeyList: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let keys: [KeyInfo]
}
public struct ProfileRemoved: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let removed: String
}

extension AgentService {
    var vault: Vault { Vault(configuration: configuration, credentials: credentials) }

    /// Key names (never values): the configuration plus keys that arrived from other Macs.
    public func keys() throws -> KeyList {
        try vault.importSyncedKeys()
        let config = try configuration.load()
        return KeyList(keys: config.secrets.sorted { $0.name.lowercased() < $1.name.lowercased() }.map { secret in
            KeyInfo(name: secret.name, id: secret.id,
                    profiles: config.profiles.filter { $0.bindings.contains { $0.secretID == secret.id } }.map(\.name).sorted())
        })
    }

    /// Rename a key on this Mac; the new name reaches the other Macs through the synced item's label.
    public func renameKey(_ oldName: String, to newName: String) throws -> KeyList {
        try vault.importSyncedKeys()
        guard let secret = try configuration.load().secrets.first(where: { $0.name == oldName }) else {
            throw AgentError("key_not_found", "Schlüssel nicht gefunden. Vorhandene Namen: secretariat keys --json")
        }
        do { try vault.updateSecret(id: secret.id, name: newName, newValue: nil) }
        catch let error as SecretariatError { throw AgentError("invalid_key", error.message) }
        return try keys()
    }

    public func createProfile(name: String, directory: String, command: String?) throws -> ProfileDescription {
        if (try? profile(named: name)) != nil {
            throw AgentError("profile_exists", "Ein Profil mit diesem Namen gibt es schon. Ändern: secretariat profile set \(name) …")
        }
        try mutate { try vault.saveProfile(Profile(name: name, directory: absolute(directory), command: command ?? "")) }
        return try describe(name)
    }

    public func updateProfile(name: String, directory: String?, command: String?) throws -> ProfileDescription {
        var changed = try profile(named: name)
        if let directory { changed.directory = absolute(directory) }
        if let command { changed.command = command }
        try mutate { try vault.saveProfile(changed) }
        return try describe(name)
    }

    /// Map an environment variable to a key by its name; an existing mapping of the variable is replaced.
    public func bind(profile name: String, variable: String, key keyName: String) throws -> ProfileDescription {
        var changed = try profile(named: name)
        try vault.importSyncedKeys()
        let secrets = try configuration.load().secrets
        guard let secret = secrets.first(where: { $0.name == keyName })
                ?? secrets.first(where: { $0.name.lowercased() == keyName.lowercased() }) else {
            throw AgentError("key_not_found", "Schlüssel nicht gefunden. Vorhandene Namen: secretariat keys --json. Neue Schlüssel legt der Nutzer in der Secretariat-App an.")
        }
        if let index = changed.bindings.firstIndex(where: { $0.variable == variable }) {
            changed.bindings[index].secretID = secret.id
        } else {
            changed.bindings.append(Binding(variable: variable, secretID: secret.id))
        }
        try mutate { try vault.saveProfile(changed) }
        return try describe(name)
    }

    public func unbind(profile name: String, variable: String) throws -> ProfileDescription {
        var changed = try profile(named: name)
        guard changed.bindings.contains(where: { $0.variable == variable }) else {
            throw AgentError("variable_not_bound", "Diese Variable ist dem Profil nicht zugeordnet.")
        }
        changed.bindings.removeAll { $0.variable == variable }
        try mutate { try vault.saveProfile(changed) }
        return try describe(name)
    }

    public func deleteProfile(name: String) throws -> ProfileRemoved {
        let existing = try profile(named: name)
        try mutate { try vault.deleteProfile(id: existing.id) }
        return ProfileRemoved(removed: name)
    }

    private func absolute(_ path: String) -> String {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath,
            relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
            .standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Validation messages describe names and paths only, never values, so agents may see them.
    private func mutate(_ change: () throws -> Void) throws {
        do { try change() } catch let error as SecretariatError { throw AgentError("invalid_profile", error.message) }
    }
}

enum ProfileCommand {
    static let usage = """
    Aufruf:
      secretariat keys [--json]
      secretariat profile create PROFIL --dir ORDNER [--command BEFEHL] [--json]
      secretariat profile set PROFIL [--dir ORDNER] [--command BEFEHL] [--json]
      secretariat profile bind PROFIL VARIABLE SCHLÜSSELNAME [--json]
      secretariat profile unbind PROFIL VARIABLE [--json]
      secretariat profile delete PROFIL [--json]
      secretariat key rename ALTER_NAME NEUER_NAME [--json]
      secretariat import DATEI VARIABLE[=SCHLÜSSELNAME] … [--profile PROFIL] [--replace] [--json]
    """

    struct Parsed {
        var positional: [String] = []
        var options: [String: String] = [:]
        var json = false
    }

    static func parse(_ arguments: ArraySlice<String>, valueOptions: Set<String>) throws -> Parsed {
        var parsed = Parsed()
        var rest = arguments[...]
        while let arg = rest.popFirst() {
            if arg == "--json" {
                guard !parsed.json else { throw AgentError("invalid_arguments", usage) }
                parsed.json = true
            } else if valueOptions.contains(arg) {
                guard parsed.options[arg] == nil, let value = rest.popFirst() else { throw AgentError("invalid_arguments", usage) }
                parsed.options[arg] = value
            } else if arg.hasPrefix("--") {
                throw AgentError("invalid_arguments", usage)
            } else {
                parsed.positional.append(arg)
            }
        }
        return parsed
    }

    /// `keys …` and `profile …`. Returns the exit code; prints JSON or a short human summary.
    static func execute(_ arguments: [String], service: AgentService) throws -> Int32 {
        let machine = arguments.contains("--json")
        do {
            let output: (json: String, text: String)
            if arguments.first == "import" {
                var rest = Array(arguments.dropFirst())
                let replace = rest.contains("--replace"); rest.removeAll { $0 == "--replace" }
                let p = try parse(rest[...], valueOptions: ["--profile"])
                guard p.positional.count >= 2 else { throw AgentError("invalid_arguments", usage) }
                let result = try service.importKeys(file: p.positional[0], requests: Array(p.positional.dropFirst()),
                                                    profile: p.options["--profile"], replace: replace)
                output = (try AgentCommand.json(result), result.imported.map {
                    "\($0.variable) → \($0.key) (\($0.action == "created" ? "neu" : "ersetzt"))"
                }.joined(separator: "\n") + (result.profile.map { "\nProfil: \($0)" } ?? ""))
            } else if arguments.first == "key" {
                let p = try parse(arguments.dropFirst(), valueOptions: [])
                guard p.positional.count == 3, p.positional[0] == "rename" else { throw AgentError("invalid_arguments", usage) }
                let result = try service.renameKey(p.positional[1], to: p.positional[2])
                output = (try AgentCommand.json(result), "Umbenannt: \(p.positional[1]) → \(p.positional[2])")
            } else if arguments.first == "keys" {
                let p = try parse(arguments.dropFirst(), valueOptions: [])
                guard p.positional.isEmpty else { throw AgentError("invalid_arguments", usage) }
                let result = try service.keys()
                output = (try AgentCommand.json(result), result.keys.isEmpty
                    ? "Noch keine Schlüssel. Bitte in der Secretariat-App anlegen."
                    : result.keys.map { "\($0.name)\t\($0.profiles.joined(separator: ", "))" }.joined(separator: "\n"))
            } else {
                let action = arguments.dropFirst().first ?? ""
                let p = try parse(arguments.dropFirst(2), valueOptions: ["--dir", "--command"])
                switch (action, p.positional.count) {
                case ("create", 1):
                    guard let dir = p.options["--dir"] else { throw AgentError("invalid_arguments", usage) }
                    output = try described(service.createProfile(name: p.positional[0], directory: dir, command: p.options["--command"]))
                case ("set", 1):
                    guard !p.options.isEmpty else { throw AgentError("invalid_arguments", usage) }
                    output = try described(service.updateProfile(name: p.positional[0], directory: p.options["--dir"], command: p.options["--command"]))
                case ("bind", 3):
                    guard p.options.isEmpty else { throw AgentError("invalid_arguments", usage) }
                    output = try described(service.bind(profile: p.positional[0], variable: p.positional[1], key: p.positional[2]))
                case ("unbind", 2):
                    guard p.options.isEmpty else { throw AgentError("invalid_arguments", usage) }
                    output = try described(service.unbind(profile: p.positional[0], variable: p.positional[1]))
                case ("delete", 1):
                    guard p.options.isEmpty else { throw AgentError("invalid_arguments", usage) }
                    let result = try service.deleteProfile(name: p.positional[0])
                    output = (try AgentCommand.json(result), "Profil entfernt: \(result.removed)")
                default:
                    throw AgentError("invalid_arguments", usage)
                }
            }
            print(machine ? output.json : output.text)
            return 0
        } catch {
            if machine { print(try AgentCommand.json(AgentFailure(error))); return 1 }
            throw error
        }
    }

    private static func described(_ result: ProfileDescription) throws -> (json: String, text: String) {
        let p = result.profile
        return (try AgentCommand.json(result),
                "\(p.name)\nOrdner: \(p.directory)\nVariablen: \(p.variables.isEmpty ? "–" : p.variables.joined(separator: ", "))")
    }
}
