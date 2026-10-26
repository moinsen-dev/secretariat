import Foundation

// Every CLI command except `run`. Output is JSON (--json) or a short human summary. Nothing here
// prints a secret value: values move file → keychain (import), keychain → program (run, push,
// inject), never to stdout.

public struct Done: Encodable, Sendable {
    public let schemaVersion = 2
    public let ok = true
    public let message: String
}

enum DotEnv {
    /// KEY=VALUE lines; `export ` prefix, comments, single/double quotes. The last assignment wins.
    static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key] = value(line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces))
        }
        return result
    }
    private static func value(_ rest: String) -> String {
        if let quote = rest.first, quote == "\"" || quote == "'" {
            var out = "", escaped = false
            for ch in rest.dropFirst() {
                if escaped { out.append(quote == "\"" ? (ch == "n" ? "\n" : ch == "t" ? "\t" : ch) : ch); escaped = false }
                else if ch == "\\" && quote == "\"" { escaped = true }
                else if ch == quote { return out }
                else { out.append(ch) }
            }
            return out
        }
        if let hash = rest.range(of: " #") { return rest[..<hash.lowerBound].trimmingCharacters(in: .whitespaces) }
        return rest
    }
}

struct Arguments {
    var positional: [String] = []
    var options: [String: [String]] = [:]
    var flags: Set<String> = []
    var json: Bool { flags.contains("--json") }
    func option(_ name: String) -> String? { options[name]?.last }

    init(_ arguments: ArraySlice<String>, values: Set<String> = [], flags allowed: Set<String> = [], usage: String) throws {
        var rest = arguments
        var afterDashes = false
        while let arg = rest.popFirst() {
            if afterDashes || !arg.hasPrefix("--") || arg == "--" { if arg == "--" { afterDashes = true } else { positional.append(arg) }; continue }
            if values.contains(arg) {
                guard let value = rest.popFirst() else { throw AgentError("invalid_arguments", usage) }
                options[arg, default: []].append(value)
            } else if arg == "--json" || allowed.contains(arg) {
                guard flags.insert(arg).inserted else { throw AgentError("invalid_arguments", usage) }
            } else { throw AgentError("invalid_arguments", "Unbekannte Option \(arg).\n\(usage)") }
        }
    }
}

public enum Commands {
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    static var usage: String { "Hilfe: secretariat --help" }

    public static func execute(_ arguments: [String], service: AgentService, executable: String) throws -> Int32 {
        let machine = arguments.contains("--json")
        do {
            let (code, json, text) = try dispatch(arguments, service: service, executable: executable)
            if let output = machine ? json : text { print(output) }
            return code
        } catch {
            if machine { print(try Self.json(AgentFailure(error))); return 1 }
            throw error
        }
    }

    // Returns exit code, JSON and human text.
    static func dispatch(_ all: [String], service: AgentService, executable: String) throws -> (Int32, String?, String?) {
        let vault = service.vault
        let command = all.first ?? ""
        let sub = all.dropFirst().first ?? ""
        func done(_ message: String) throws -> (Int32, String?, String?) { (0, try json(Done(message: message)), message) }
        func usedBy(_ id: UUID, _ config: Configuration) -> [String] {
            config.profiles.filter { $0.bindings.contains { $0.itemID == id } }.map(\.name)
                + config.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "ziel:\($0.name)" }
        }
        func show(_ item: ItemMeta) throws -> (Int32, String?, String?) {
            let config = try vault.configuration.load()
            let info = ItemInfo(item, usedBy: usedBy(item.id, config))
            let lines = ["\(item.path)  (\(item.kind.title))"] + item.fields.map {
                "  \($0.name)\t\($0.kind.title)\($0.kind == .identifier ? "\t\($0.value ?? "")" : $0.kind == .file ? "\t\($0.fileName ?? "")" : "")"
            } + (item.expires.map { ["  läuft ab: \($0)"] } ?? []) + (item.source.isEmpty ? [] : ["  Quelle: \(item.source)"])
            return (0, try json(ItemResult(item: info)), lines.joined(separator: "\n"))
        }
        func setIdentifiers(_ item: inout ItemMeta, _ assignments: [String]) throws {
            for assignment in assignments {
                guard let eq = assignment.firstIndex(of: "=") else { throw AgentError("invalid_arguments", "--set erwartet FELD=WERT.") }
                let name = String(assignment[..<eq]), value = String(assignment[assignment.index(after: eq)...])
                if let existing = item.field(name), existing.kind != .identifier {
                    throw AgentError("secret_field", "\(item.path)/\(name) ist geheim. Geheime Werte kommen per App, import oder import-file.")
                }
                item.fields.removeAll { $0.name == name }
                item.fields.append(ItemField(name: name, kind: .identifier, value: value))
            }
        }
        func binding(_ variable: String, _ reference: String) throws -> Binding {
            let (item, field) = try vault.resolve(try FieldReference(reference))
            guard field.kind.isUsable else { throw AgentError("personal_field", "\(reference) ist nur für den Nutzer bestimmt und lässt sich keinem Programm zuordnen.") }
            return Binding(variable: variable, itemID: item.id, field: field.name)
        }

        switch (command, sub) {
        // MARK: items
        case ("items", _):
            let a = try Arguments(all.dropFirst(), values: ["--expiring"], usage: usage)
            var list = try vault.list()
            if let days = a.option("--expiring").flatMap(Int.init) {
                let limit = Calendar.current.date(byAdding: .day, value: days, to: Date())!
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; let cutoff = f.string(from: limit)
                list = list.filter { ($0.expires ?? "9999") <= cutoff }
            }
            let config = try vault.configuration.load()
            let text = list.isEmpty ? "Keine Einträge." : list.map { item in
                "\(item.path)\t\(item.kind.rawValue)\t\(item.fields.map(\.name).joined(separator: ","))\(item.expires.map { "\tläuft ab \($0)" } ?? "")"
            }.joined(separator: "\n")
            return (0, try json(ItemList(items: list.map { ItemInfo($0, usedBy: usedBy($0.id, config)) })), text)

        case ("item", "show"):
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat item show PFAD") }
            return try show(try vault.item(path: a.positional[0]))

        case ("item", "create"), ("item", "set"):
            let a = try Arguments(all.dropFirst(2), values: ["--kind", "--set", "--unset", "--source", "--expires"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", usage) }
            var item: ItemMeta
            if sub == "create" {
                guard let raw = a.option("--kind"), let kind = ItemKind(rawValue: raw) else {
                    throw AgentError("invalid_arguments", "--kind \(ItemKind.allCases.map(\.rawValue).joined(separator: "|"))")
                }
                if (try? vault.item(path: a.positional[0])) != nil { throw AgentError("path_exists", "Es gibt schon einen Eintrag \(a.positional[0]).") }
                item = ItemMeta(path: a.positional[0], kind: kind)
            } else {
                item = try vault.item(path: a.positional[0])
                if let raw = a.option("--kind") { guard let kind = ItemKind(rawValue: raw) else { throw AgentError("invalid_arguments", usage) }; item.kind = kind }
            }
            try setIdentifiers(&item, a.options["--set"] ?? [])
            for name in a.options["--unset"] ?? [] {
                guard let field = item.field(name) else { throw AgentError("field_not_found", "\(item.path) hat kein Feld \(name).") }
                guard field.kind == .identifier else { throw AgentError("secret_field", "Geheime Felder entfernt nur der Nutzer in der App.") }
                item.fields.removeAll { $0.name == name }
            }
            if let source = a.option("--source") { item.source = source }
            if let expires = a.option("--expires") { item.expires = expires.isEmpty ? nil : expires }
            try vault.save(item)
            return try show(try vault.item(path: item.path))

        case ("item", "delete"):
            // Deleting real items is the user's call in the app; the CLI only cleans up test homes.
            guard vault.registryDirectory == nil, ProcessInfo.processInfo.environment["SECRETARIAT_HOME"] != nil else {
                throw AgentError("app_only", "Einträge löscht der Nutzer in der Secretariat-App.")
            }
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", usage) }
            try vault.delete(id: try vault.item(path: a.positional[0]).id)
            return try done("Eintrag entfernt: \(a.positional[0])")

        case ("item", "rename"):
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Aufruf: secretariat item rename PFAD NEUER_PFAD") }
            return try show(try vault.rename(path: a.positional[0], to: a.positional[1]))

        case ("get", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat get PFAD/FELD") }
            let (_, field) = try vault.resolve(try FieldReference(a.positional[0]))
            guard field.kind == .identifier, let value = field.value else {
                throw AgentError("secret_field", "\(a.positional[0]) ist \(field.kind.title) – den Wert gibt Secretariat nicht aus. Programme bekommen ihn per run.")
            }
            struct Value: Encodable { let schemaVersion = 2; let ok = true; let reference: String; let value: String }
            return (0, try json(Value(reference: a.positional[0], value: value)), value)

        case ("field", "move"):
            let a = try Arguments(all.dropFirst(2), flags: ["--replace"], usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Aufruf: secretariat field move PFAD/FELD PFAD/FELD") }
            try vault.moveField(from: try FieldReference(a.positional[0]), to: try FieldReference(a.positional[1]), replace: a.flags.contains("--replace"))
            return try done("Verschoben: \(a.positional[0]) → \(a.positional[1])")

        case ("import", _):
            let a = try Arguments(all.dropFirst(), values: ["--profile"], flags: ["--replace"], usage: usage)
            guard a.positional.count >= 2 else { throw AgentError("invalid_arguments", "Aufruf: secretariat import DATEI VARIABLE[=PFAD/FELD] …") }
            let file = (a.positional[0] as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: file), let text = String(data: data, encoding: .utf8) else {
                throw AgentError("file_unreadable", "Datei nicht lesbar: \(a.positional[0])")
            }
            let env = DotEnv.parse(text)
            let folder = URL(fileURLWithPath: file).deletingLastPathComponent().lastPathComponent
            let pairs = try a.positional.dropFirst().map { request -> (String, FieldReference) in
                guard let eq = request.firstIndex(of: "=") else {
                    let field = request.lowercased().replacingOccurrences(of: #"[^a-z0-9_]"#, with: "_", options: .regularExpression)
                    return (request, FieldReference(path: "imported/\(folder)", field: field.first?.isLetter == true ? field : "v_\(field)"))
                }
                return (String(request[..<eq]), try FieldReference(String(request[request.index(after: eq)...])))
            }
            let missing = pairs.filter { (env[$0.0] ?? "").isEmpty }.map(\.0)
            guard missing.isEmpty else { throw AgentError("variable_missing", "In der Datei fehlt oder leer: \(missing.joined(separator: ", "))") }
            var profile = try a.option("--profile").map { try service.profile(named: $0) }
            for (variable, reference) in pairs {
                try vault.setValue(reference, value: env[variable]!, source: "import aus \(a.positional[0])", replace: a.flags.contains("--replace"))
                if profile != nil {
                    profile!.bindings.removeAll { $0.variable == variable }
                    profile!.bindings.append(try binding(variable, reference.description))
                }
            }
            if let profile { try vault.saveProfile(profile) }
            vault.audit.record("import", ["file": a.positional[0], "fields": pairs.map { $0.1.description }.joined(separator: ",")])
            struct Imported: Encodable { let schemaVersion = 2; let ok = true; let imported: [String: String]; let profile: String? }
            let mapping = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, $0.1.description) })
            return (0, try json(Imported(imported: mapping, profile: profile?.name)),
                    pairs.map { "\($0.0) → \($0.1)" }.joined(separator: "\n") + (profile.map { "\nProfil: \($0.name)" } ?? ""))

        case ("import-file", _):
            let a = try Arguments(all.dropFirst(), flags: ["--replace"], usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Aufruf: secretariat import-file DATEI PFAD/FELD") }
            let path = (a.positional[0] as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: path), !data.isEmpty, data.count <= 256_000 else {
                throw AgentError("file_unreadable", "Datei nicht lesbar, leer oder größer als 250 KB: \(a.positional[0])")
            }
            let reference = try FieldReference(a.positional[1])
            try vault.setValue(reference, value: data.base64EncodedString(), kind: .file, fileName: (path as NSString).lastPathComponent,
                               itemKind: .certificate, source: "import-file \(a.positional[0])", replace: a.flags.contains("--replace"))
            return try done("Datei übernommen: \(reference) (die Originaldatei bleibt liegen; löschen entscheidet der Nutzer)")

        // MARK: profiles
        case ("profiles", _):
            let result = try service.profiles()
            return (0, try json(result), result.profiles.isEmpty ? "Noch keine Profile." : result.profiles.map { "\($0.name)\t\($0.directory)" }.joined(separator: "\n"))
        case ("describe", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat describe PROFIL") }
            let result = try service.describe(a.positional[0])
            return (0, try json(result), (["\(result.profile.name)", "Ordner: \(result.profile.directory)"]
                + result.profile.bindings.sorted { $0.key < $1.key }.map { "\($0.key) ← \($0.value)" }).joined(separator: "\n"))
        case ("check", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat check PROFIL") }
            let timeout = AgentError("keychain_timeout", "Der Schlüsselbund antwortet nicht rechtzeitig. Bitte erneut versuchen.")
            let watchdog = CheckWatchdog(output: a.json ? try json(AgentFailure(timeout)) : timeout.message)
            watchdog.start(); defer { _ = watchdog.finish() }
            let result = try service.check(a.positional[0])
            guard watchdog.finish() else { return (2, nil, nil) }
            let text = (["\(result.profile): \(result.ok ? "bereit" : "nicht bereit")"] + (result.directoryExists ? [] : ["Projektordner fehlt."])
                + result.variables.map { "\($0.variable) ← \($0.reference): \($0.status)" }).joined(separator: "\n")
            return (result.ok ? 0 : 2, try json(result), text)
        case ("instructions", _):
            guard all.count == 2 else { throw AgentError("invalid_arguments", "Aufruf: secretariat instructions PROFIL") }
            return (0, nil, ProjectInstructions.body(profile: try service.profile(named: all[1]), executable: executable))
        case ("setup", _):
            let a = try Arguments(all.dropFirst(), flags: ["--dry-run"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat setup PROFIL [--dry-run]") }
            let plan = try ProjectInstructions.preview(profile: service.profile(named: a.positional[0]), executable: executable)
            let dryRun = a.flags.contains("--dry-run")
            if !dryRun { try ProjectInstructions.apply(plan) }
            let result = SetupResult(plan: plan, dryRun: dryRun)
            let text = ([dryRun ? "Vorschau – keine Dateien geändert:" : "Projektanweisungen eingerichtet:"]
                + result.files.map { "\($0.name): \($0.changed ? (dryRun ? "wird aktualisiert" : "aktualisiert") : "unverändert")" }
                + (dryRun ? ["", plan.instructions] : [])).joined(separator: "\n")
            return (0, try json(result), text)

        case ("profile", _):
            let a = try Arguments(all.dropFirst(2), values: ["--dir", "--command"], usage: usage)
            func absolute(_ path: String) -> String {
                URL(fileURLWithPath: (path as NSString).expandingTildeInPath,
                    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
                    .standardizedFileURL.resolvingSymlinksInPath().path
            }
            func describe(_ name: String) throws -> (Int32, String?, String?) {
                let result = try service.describe(name)
                return (0, try json(result), "\(name)\nOrdner: \(result.profile.directory)\nVariablen: \(result.profile.variables.isEmpty ? "–" : result.profile.variables.joined(separator: ", "))")
            }
            switch (sub, a.positional.count) {
            case ("create", 1):
                guard let dir = a.option("--dir") else { throw AgentError("invalid_arguments", "--dir ORDNER fehlt.") }
                if (try? service.profile(named: a.positional[0])) != nil { throw AgentError("profile_exists", "Ein Profil mit diesem Namen gibt es schon.") }
                try vault.saveProfile(Profile(name: a.positional[0], directory: absolute(dir), command: a.option("--command") ?? ""))
                return try describe(a.positional[0])
            case ("set", 1):
                var profile = try service.profile(named: a.positional[0])
                if let dir = a.option("--dir") { profile.directory = absolute(dir) }
                if let command = a.option("--command") { profile.command = command }
                try vault.saveProfile(profile); return try describe(profile.name)
            case ("bind", 3):
                var profile = try service.profile(named: a.positional[0])
                let new = try binding(a.positional[1], a.positional[2])
                profile.bindings.removeAll { $0.variable == new.variable }; profile.bindings.append(new)
                try vault.saveProfile(profile); return try describe(profile.name)
            case ("unbind", 2):
                var profile = try service.profile(named: a.positional[0])
                guard profile.bindings.contains(where: { $0.variable == a.positional[1] }) else {
                    throw AgentError("variable_not_bound", "Diese Variable ist dem Profil nicht zugeordnet.")
                }
                profile.bindings.removeAll { $0.variable == a.positional[1] }
                try vault.saveProfile(profile); return try describe(profile.name)
            case ("delete", 1):
                try vault.deleteProfile(id: try service.profile(named: a.positional[0]).id)
                return try done("Profil entfernt: \(a.positional[0])")
            default: throw AgentError("invalid_arguments", usage)
            }

        case ("inject", _):
            let a = try Arguments(all.dropFirst(), values: ["--out"], usage: usage)
            guard a.positional.count == 1, let out = a.option("--out") else { throw AgentError("invalid_arguments", "Aufruf: secretariat inject VORLAGE --out DATEI") }
            let rendered = try Inject.render(template: a.positional[0], vault: vault)
            try Inject.write(rendered.text, to: out)
            vault.audit.record("inject", ["out": out, "fields": rendered.references.joined(separator: ",")])
            return try done("\(out) geschrieben (\(rendered.references.count) Verweise, Rechte 0600)")

        // MARK: targets
        case ("targets", _):
            let report = try Targets.report(vault: vault)
            return (0, try json(report), report.targets.isEmpty ? "Keine Ziele." : report.targets.map { target in
                "\(target.name)\t\(target.destination)\n" + target.variables.map { "  \($0.variable) ← \($0.reference): \($0.status)" }.joined(separator: "\n")
            }.joined(separator: "\n"))
        case ("target", _):
            let a = try Arguments(all.dropFirst(2), values: ["--command", "--dir", "--env-file"], usage: usage)
            func target(_ name: String) throws -> Target {
                guard let t = try vault.configuration.load().targets.first(where: { $0.name == name }) else {
                    throw AgentError("target_not_found", "Ziel nicht gefunden. Vorhandene Ziele: secretariat targets")
                }
                return t
            }
            switch (sub, a.positional.count) {
            case ("add", 1):
                var t: Target
                if let command = a.option("--command") {
                    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                    let dir = URL(fileURLWithPath: ((a.option("--dir") ?? ".") as NSString).expandingTildeInPath, relativeTo: cwd).standardizedFileURL.path
                    t = Target(name: a.positional[0], kind: .command, command: command, directory: dir)
                } else if let spec = a.option("--env-file"), let colon = spec.firstIndex(of: ":") {
                    t = Target(name: a.positional[0], kind: .envFile, host: String(spec[..<colon]), path: String(spec[spec.index(after: colon)...]))
                } else { throw AgentError("invalid_arguments", "--command 'BEFEHL {var}' oder --env-file HOST:PFAD") }
                if (try? target(t.name)) != nil { throw AgentError("target_exists", "Ein Ziel mit diesem Namen gibt es schon.") }
                try vault.saveTarget(t); return try done("Ziel angelegt: \(t.name)")
            case ("map", 3):
                var t = try target(a.positional[0])
                let new = try binding(a.positional[1], a.positional[2])
                t.bindings.removeAll { $0.variable == new.variable }; t.bindings.append(new)
                try vault.saveTarget(t); return try done("\(t.name): \(new.variable) ← \(a.positional[2])")
            case ("unmap", 2):
                var t = try target(a.positional[0])
                t.bindings.removeAll { $0.variable == a.positional[1] }; t.pushed.removeValue(forKey: a.positional[1])
                try vault.saveTarget(t); return try done("\(t.name): \(a.positional[1]) entfernt")
            case ("delete", 1):
                try vault.deleteTarget(id: try target(a.positional[0]).id); return try done("Ziel entfernt: \(a.positional[0])")
            default: throw AgentError("invalid_arguments", usage)
            }
        case ("push", _):
            let a = try Arguments(all.dropFirst(), flags: ["--dry-run"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Aufruf: secretariat push ZIEL [--dry-run]") }
            let lines = try Targets.push(a.positional[0], vault: vault, dryRun: a.flags.contains("--dry-run"))
            return try done(lines.joined(separator: "\n"))

        // MARK: overview
        case ("registry", "export"):
            guard vault.registryDirectory != nil else { throw AgentError("no_registry", "Kein Register unter ~/.claude/registry (nur der echte Secretariat-Ordner exportiert).") }
            vault.exportRegistry()
            return try done("Register geschrieben: ~/.claude/registry/accounts.toml")
        case ("scan", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            let root = (a.positional.first.map { ($0 as NSString).expandingTildeInPath }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("work").path
            let findings = try Scan.run(root: URL(fileURLWithPath: root), vault: vault)
            struct Report: Encodable { let schemaVersion = 2; let ok = true; let findings: [Scan.Finding] }
            return (0, try json(Report(findings: findings)), findings.isEmpty ? "Keine .env-Dateien mit Werten gefunden." : findings.map {
                "\($0.file)\n" + $0.variables.map { "  \($0.name)\($0.storedAs.map { "  = in Secretariat: \($0)" } ?? "")" }.joined(separator: "\n")
            }.joined(separator: "\n"))
        case ("log", _):
            let a = try Arguments(all.dropFirst(), values: ["--lines"], usage: usage)
            let lines = vault.audit.tail(a.option("--lines").flatMap(Int.init) ?? 30)
            return (0, "[\(lines.joined(separator: ","))]", lines.isEmpty ? "Noch keine Einträge im Protokoll." : lines.joined(separator: "\n"))
        default:
            throw AgentError("invalid_arguments", "Unbekannter Aufruf. \(usage)")
        }
    }
}

// MARK: - inject

enum Inject {
    static func render(template: String, vault: Vault) throws -> (text: String, references: [String]) {
        guard let source = try? String(contentsOfFile: (template as NSString).expandingTildeInPath, encoding: .utf8) else {
            throw AgentError("file_unreadable", "Vorlage nicht lesbar: \(template)")
        }
        let regex = try NSRegularExpression(pattern: #"\{\{\s*([^}\s]+)\s*\}\}"#)
        var output = source, references: [String] = []
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            let reference = String(source[Range(match.range(at: 1), in: source)!])
            let (item, field) = try vault.resolve(try FieldReference(reference))
            var value = try vault.value(itemID: item.id, field: field.name)
            if field.kind == .file {
                guard let data = Data(base64Encoded: value), let text = String(data: data, encoding: .utf8) else {
                    throw AgentError("binary_file", "\(reference) ist keine Textdatei und lässt sich nicht einsetzen.")
                }
                value = text
            }
            output.replaceSubrange(Range(match.range, in: output)!, with: value)
            references.append(reference)
        }
        return (output, references.reversed())
    }

    /// Refuses a destination that git would track: rendered files hold secret values.
    static func write(_ text: String, to out: String) throws {
        let url = URL(fileURLWithPath: (out as NSString).expandingTildeInPath).standardizedFileURL
        let folder = url.deletingLastPathComponent().path
        if git(["-C", folder, "rev-parse", "--is-inside-work-tree"]) == 0 && git(["-C", folder, "check-ignore", "-q", url.path]) != 0 {
            throw AgentError("tracked_destination", "\(out) liegt in einem Git-Repository und ist nicht in .gitignore. Bitte zuerst ignorieren oder einen anderen Ort wählen.")
        }
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: Data(text.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw AgentError("write_failed", "\(out) konnte nicht geschrieben werden.")
        }
    }
    static func git(_ arguments: [String]) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = arguments
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return 127 }
    }
}

// MARK: - targets

public enum Targets {
    public struct VariableStatus: Encodable, Sendable { public let variable: String; public let reference: String; public let status: String }
    public struct TargetStatus: Encodable, Sendable {
        public let name: String; public let destination: String; public let pushedAt: String?; public let variables: [VariableStatus]
    }
    public struct Report: Encodable, Sendable { public let schemaVersion = 2; public let ok = true; public let targets: [TargetStatus] }

    static func destination(_ t: Target) -> String { t.kind == .command ? "\(t.command)  (in \(t.directory))" : "\(t.host):\(t.path)" }

    public static func report(vault: Vault) throws -> Report {
        let config = try vault.configuration.load()
        let items = (try? vault.list()) ?? []
        return Report(targets: config.targets.sorted { $0.name < $1.name }.map { t in
            TargetStatus(name: t.name, destination: destination(t), pushedAt: t.pushedAt, variables: t.bindings.sorted { $0.variable < $1.variable }.map { b in
                let reference = (items.first { $0.id == b.itemID }?.path ?? "(fehlt)") + "/" + b.field
                let status: String
                if let value = try? vault.value(itemID: b.itemID, field: b.field) {
                    let print = vault.fingerprint(value, salt: config.salt)
                    status = t.pushed[b.variable] == nil ? "never" : t.pushed[b.variable] == print ? "current" : "stale"
                } else { status = "missing" }
                return VariableStatus(variable: b.variable, reference: reference, status: status)
            })
        })
    }

    /// Write the target's values. A command target runs once per variable with the value on stdin;
    /// an env-file target replaces the whole file over ssh (umask 077).
    static func push(_ name: String, vault: Vault, dryRun: Bool) throws -> [String] {
        let config = try vault.configuration.load()
        guard var target = config.targets.first(where: { $0.name == name }) else {
            throw AgentError("target_not_found", "Ziel nicht gefunden. Vorhandene Ziele: secretariat targets")
        }
        guard !target.bindings.isEmpty else { throw AgentError("target_empty", "Dem Ziel ist noch keine Variable zugeordnet.") }
        var values: [(String, String)] = []
        for b in target.bindings.sorted(by: { $0.variable < $1.variable }) { values.append((b.variable, try vault.value(itemID: b.itemID, field: b.field))) }
        if dryRun { return ["Würde nach \(destination(target)) schreiben: \(values.map(\.0).joined(separator: ", "))"] }
        var lines: [String] = []
        switch target.kind {
        case .command:
            for (variable, value) in values {
                let command = target.command.replacingOccurrences(of: "{var}", with: variable)
                let status = run("/bin/zsh", ["-c", command], directory: target.directory, stdin: value)
                guard status == 0 else { throw AgentError("push_failed", "\(variable): Befehl endete mit \(status). Bereits verteilte Variablen sind vermerkt.") }
                target.pushed[variable] = vault.fingerprint(value, salt: config.salt)
                lines.append("\(variable): verteilt")
                try vault.saveTarget(target)
            }
        case .envFile:
            let body = values.map { "\($0.0)=\(shellQuote($0.1))" }.joined(separator: "\n") + "\n"
            let remotePath = target.path
            let script = "umask 077; mkdir -p \"$(dirname \(remotePath))\" && cat > \(remotePath).secretariat-tmp && mv \(remotePath).secretariat-tmp \(remotePath)"
            let status = run("/usr/bin/ssh", ["-o", "BatchMode=yes", target.host, script], directory: FileManager.default.currentDirectoryPath, stdin: body)
            guard status == 0 else { throw AgentError("push_failed", "ssh \(target.host) endete mit \(status).") }
            for (variable, value) in values { target.pushed[variable] = vault.fingerprint(value, salt: config.salt) }
            lines.append("\(target.host):\(remotePath): \(values.count) Variablen geschrieben")
        }
        target.pushedAt = ISO8601DateFormatter().string(from: Date())
        try vault.saveTarget(target)
        vault.audit.record("push", ["target": name, "variables": values.map(\.0).joined(separator: ",")])
        return lines
    }

    static func run(_ executable: String, _ arguments: [String], directory: String, stdin: String) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        p.currentDirectoryURL = URL(fileURLWithPath: directory)
        let pipe = Pipe(); p.standardInput = pipe
        do { try p.run() } catch { return 127 }
        pipe.fileHandleForWriting.write(Data(stdin.utf8)); try? pipe.fileHandleForWriting.close()
        p.waitUntilExit()
        return p.terminationStatus
    }
}

// MARK: - scan

enum Scan {
    struct Variable: Encodable { let name: String; let storedAs: String? }
    struct Finding: Encodable { let file: String; let variables: [Variable] }
    static let skip: Set<String> = ["node_modules", ".git", "Pods", ".dart_tool", "build", "dist", ".next", ".venv", "DerivedData", ".build", "archive"]

    /// .env files with real values under `root`; names only, plus where an identical value already lives.
    static func run(root: URL, vault: Vault) throws -> [Finding] {
        var known: [String: String] = [:]
        for item in try vault.list() {
            guard let values = try? vault.items.secrets(id: item.id) else { continue }
            for (field, value) in values where item.field(field)?.kind != .file { known[value] = "\(item.path)/\(field)" }
            for field in item.fields where field.kind == .identifier { if let v = field.value { known[v] = "\(item.path)/\(field.name)" } }
        }
        var findings: [Finding] = []
        func walk(_ url: URL, depth: Int) {
            guard let entries = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return }
            for entry in entries {
                let name = entry.lastPathComponent
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values?.isSymbolicLink == true { continue }
                if values?.isDirectory == true { if depth > 0 && !skip.contains(name) { walk(entry, depth: depth - 1) }; continue }
                guard name == ".env" || (name.hasPrefix(".env.") && !["example", "sample", "template", "dist"].contains(where: { name.hasSuffix($0) })) else { continue }
                guard let text = try? String(contentsOf: entry, encoding: .utf8) else { continue }
                let vars = DotEnv.parse(text).filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { Variable(name: $0.key, storedAs: known[$0.value]) }
                if !vars.isEmpty { findings.append(Finding(file: entry.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), variables: vars)) }
            }
        }
        walk(root, depth: 6)
        return findings.sorted { $0.file < $1.file }
    }
}
