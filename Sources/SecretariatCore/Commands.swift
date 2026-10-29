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
        // Unquoted: a # at the start or after whitespace begins a comment (`KEY=   # what it is for` is empty).
        if rest.hasPrefix("#") { return "" }
        if let hash = rest.range(of: #"\s#"#, options: .regularExpression) { return rest[..<hash.lowerBound].trimmingCharacters(in: .whitespaces) }
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
            } else { throw AgentError("invalid_arguments", "Unknown option \(arg).\n\(usage)") }
        }
    }
}

public enum Commands {
    static func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    static var usage: String { "Help: secretariat --help" }

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
                + config.targets.filter { $0.bindings.contains { $0.itemID == id } }.map { "target:\($0.name)" }
        }
        func show(_ item: ItemMeta) throws -> (Int32, String?, String?) {
            let config = try vault.configuration.load()
            let info = ItemInfo(item, usedBy: usedBy(item.id, config))
            let lines = ["\(item.path)  (\(vault.catalog().template(item.kind).title))"] + item.fields.map {
                "  \($0.name)\t\($0.kind.title)\($0.kind == .identifier ? "\t\($0.value ?? "")" : $0.kind == .file ? "\t\($0.fileName ?? "")" : "")"
            } + (item.expires.map { ["  expires: \($0)"] } ?? []) + (item.source.isEmpty ? [] : ["  source: \(item.source)"])
            return (0, try json(ItemResult(item: info)), lines.joined(separator: "\n"))
        }
        func setIdentifiers(_ item: inout ItemMeta, _ assignments: [String]) throws {
            for assignment in assignments {
                guard let eq = assignment.firstIndex(of: "=") else { throw AgentError("invalid_arguments", "--set expects FIELD=VALUE.") }
                let name = String(assignment[..<eq]), value = String(assignment[assignment.index(after: eq)...])
                if let existing = item.field(name), existing.kind != .identifier {
                    throw AgentError("secret_field", "\(item.path)/\(name) is secret. Secret values come in through the app, import or import-file.")
                }
                item.fields.removeAll { $0.name == name }
                item.fields.append(ItemField(name: name, kind: .identifier, value: value))
            }
        }
        func binding(_ variable: String, _ reference: String) throws -> Binding {
            let (item, field) = try vault.resolve(try FieldReference(reference))
            guard field.kind.isUsable else { throw AgentError("personal_field", "\(reference) is only for the user and can't be bound to a program.") }
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
            let text = list.isEmpty ? "No items." : list.map { item in
                "\(item.path)\t\(item.kind)\t\(item.fields.map(\.name).joined(separator: ","))\(item.expires.map { "\texpires \($0)" } ?? "")"
            }.joined(separator: "\n")
            return (0, try json(ItemList(items: list.map { ItemInfo($0, usedBy: usedBy($0.id, config)) })), text)

        case ("item", "show"):
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat item show PATH") }
            return try show(try vault.item(path: a.positional[0]))

        case ("item", "create"), ("item", "set"):
            let a = try Arguments(all.dropFirst(2), values: ["--kind", "--set", "--unset", "--source", "--expires", "--approval"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", usage) }
            var item: ItemMeta
            if sub == "create" {
                let catalog = vault.catalog()
                guard let kind = a.option("--kind"), catalog.isKnown(kind) else {
                    throw AgentError("invalid_arguments", "--kind \(catalog.all.map(\.id).joined(separator: "|")) (templates: secretariat template list)")
                }
                if (try? vault.item(path: a.positional[0])) != nil { throw AgentError("path_exists", "An item \(a.positional[0]) already exists.") }
                item = ItemMeta(path: a.positional[0], kind: kind)
            } else {
                item = try vault.item(path: a.positional[0])
                if let kind = a.option("--kind") {
                    guard vault.catalog().isKnown(kind) else { throw AgentError("unknown_template", "No template \(kind). Templates: secretariat template list") }
                    item.kind = kind
                }
            }
            try setIdentifiers(&item, a.options["--set"] ?? [])
            for name in a.options["--unset"] ?? [] {
                guard let field = item.field(name) else { throw AgentError("field_not_found", "\(item.path) has no field \(name).") }
                guard field.kind == .identifier else { throw AgentError("secret_field", "Only the user removes secret fields, in the app.") }
                item.fields.removeAll { $0.name == name }
            }
            if let approval = a.option("--approval") {
                // Agents may tighten, never loosen: switching approval off is Uli's call, in the app.
                guard approval == "on" else { throw AgentError("app_only", "Approval can only be switched off in the Secretariat app.") }
                item.approval = true
            }
            if let source = a.option("--source") { item.source = source }
            if let expires = a.option("--expires") { item.expires = expires.isEmpty ? nil : expires }
            try vault.save(item)
            return try show(try vault.item(path: item.path))

        case ("item", "delete"):
            // Deleting real items is the user's call in the app; the CLI only cleans up test homes.
            guard vault.registryDirectory == nil, ProcessInfo.processInfo.environment["SECRETARIAT_HOME"] != nil else {
                throw AgentError("app_only", "The user deletes items in the Secretariat app.")
            }
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", usage) }
            try vault.delete(id: try vault.item(path: a.positional[0]).id)
            return try done("Item removed: \(a.positional[0])")

        case ("screenshots", "clear"):
            // Screenshots are the user's alone; the CLI never reads them and only clears test homes.
            let paths = vault.configuration.paths
            guard !paths.isDefault, ProcessInfo.processInfo.environment["SECRETARIAT_HOME"] != nil else {
                throw AgentError("app_only", "Screenshots are only shown and deleted in the Secretariat app.")
            }
            try ScreenshotLibrary.resolve(paths: paths).removeEverything()
            return try done("Screenshots of this test home removed")

        case ("screenshots", _):
            // Counts only: titles, notes and images never leave the app.
            struct Out: Encodable { let schemaVersion = 2; let ok = true; let location: String; let screenshots: Int; let pending: Int; let unreadable: Int }
            let library = ScreenshotLibrary.resolve(paths: vault.configuration.paths)
            let listing = try library.list()
            let location = library.location == .iCloud ? "icloud" : "local"
            return (0, try json(Out(location: location, screenshots: listing.screenshots.count, pending: listing.pending, unreadable: listing.unreadable)),
                    "\(listing.screenshots.count) screenshots (\(location)), \(listing.pending) downloading, \(listing.unreadable) unreadable")

        case ("template", _):
            let a = try Arguments(all.dropFirst(2), values: ["--title", "--symbol", "--explanation", "--label", "--kind", "--prompt", "--env"],
                                  flags: ["--identity", "--no-identity", "--required"], usage: usage)
            let catalog = vault.catalog()
            func render(_ t: Template) throws -> (Int32, String?, String?) {
                struct Out: Encodable { let schemaVersion = 2; let ok = true; let template: Template; let builtin: Bool }
                let text = (["\(t.id)  \(t.title)\(t.identity ? "  [identity]" : "")\(t.isBuiltin ? "  (built-in)" : "")"]
                    + t.fields.map { "  \($0.name)\t\($0.label)\t\($0.kind.rawValue)\($0.required ? " *" : "")\($0.envSuffix.map { "\tenv _\($0)" } ?? "")" }).joined(separator: "\n")
                return (0, try json(Out(template: t, builtin: t.isBuiltin)), text)
            }
            func existing(_ id: String) throws -> Template {
                guard catalog.isKnown(id) else { throw AgentError("unknown_template", "No template \(id). Templates: secretariat template list") }
                return catalog.template(id)
            }
            switch (sub, a.positional.count) {
            case ("list", 0):
                struct Out: Encodable { let schemaVersion = 2; let ok = true; let templates: [Template] }
                return (0, try json(Out(templates: catalog.all)), catalog.all.map { "\($0.id)\t\($0.title)\t\($0.fields.map(\.name).joined(separator: ","))" }.joined(separator: "\n"))
            case ("show", 1):
                return try render(try existing(a.positional[0]))
            case ("create", 1), ("set", 1):
                var t: Template
                if sub == "create" {
                    guard !catalog.isKnown(a.positional[0]) else { throw AgentError("template_exists", "A template \(a.positional[0]) already exists.") }
                    guard !Template.builtins.contains(where: { $0.id == a.positional[0] }) else {
                        throw AgentError("template_exists", "\(a.positional[0]) is a hidden built-in template. Bring it back with: secretariat template reset \(a.positional[0])")
                    }
                    t = Template(id: a.positional[0], title: a.option("--title") ?? a.positional[0])
                } else { t = try existing(a.positional[0]) }
                if let title = a.option("--title") { t.title = title }
                if let symbol = a.option("--symbol") { t.symbol = symbol }
                if let explanation = a.option("--explanation") { t.explanation = explanation }
                if a.flags.contains("--identity") { t.identity = true }
                if a.flags.contains("--no-identity") { t.identity = false }
                try vault.saveTemplate(t); return try render(vault.catalog().template(t.id))
            case ("field", 3):
                // template field add|remove ID NAME
                var t = try existing(a.positional[1]); let name = a.positional[2]
                switch a.positional[0] {
                case "add":
                    guard let raw = a.option("--kind") ?? Optional("identifier"), let kind = FieldKind(rawValue: raw) else {
                        throw AgentError("invalid_arguments", "--kind identifier|secret|file|personal")
                    }
                    let spec = FieldSpec(name, a.option("--label") ?? name, kind, required: a.flags.contains("--required"),
                                         prompt: a.option("--prompt") ?? "", env: a.option("--env"))
                    if let i = t.fields.firstIndex(where: { $0.name == name }) { t.fields[i] = spec } else { t.fields.append(spec) }
                case "remove":
                    guard t.fields.contains(where: { $0.name == name }) else { throw AgentError("field_not_found", "\(t.id) has no field \(name).") }
                    t.fields.removeAll { $0.name == name }
                default: throw AgentError("invalid_arguments", usage)
                }
                try vault.saveTemplate(t); return try render(vault.catalog().template(t.id))
            case ("delete", 1):
                _ = try existing(a.positional[0]); try vault.deleteTemplate(id: a.positional[0])
                return try done("Template removed: \(a.positional[0]) (items keep their fields)")
            case ("reset", 1):
                guard Template.builtins.contains(where: { $0.id == a.positional[0] }) else { throw AgentError("not_builtin", "Only built-in templates can be reset.") }
                try vault.resetTemplate(id: a.positional[0]); return try render(vault.catalog().template(a.positional[0]))
            default: throw AgentError("invalid_arguments", usage)
            }

        case ("guard", _):
            let a = try Arguments(all.dropFirst(2), values: ["--all"], usage: usage)
            switch sub {
            case "check":
                let dir = a.positional.first ?? FileManager.default.currentDirectoryPath
                let findings = GitGuard.scan(diff: GitGuard.stagedDiff(in: dir), secrets: GitGuard.secrets(vault))
                struct Out: Encodable { let schemaVersion = 2; let ok: Bool; let findings: [GitGuard.Finding] }
                if !findings.isEmpty { vault.audit.record("guard.blocked", ["files": Set(findings.map(\.file)).sorted().joined(separator: ",")]) }
                let text = findings.isEmpty ? "Secretariat guard: no known secret values in the staged changes." :
                    (["Secretariat guard: commit blocked — staged changes contain secret values:"]
                     + findings.map { "  \($0.file):\($0.line)  value of \($0.reference)" }
                     + ["Read it from the environment instead (secretariat run), then stage again. Bypass only knowingly: git commit --no-verify"]).joined(separator: "\n")
                return (findings.isEmpty ? 0 : 1, try json(Out(ok: findings.isEmpty, findings: findings)), text)
            case "install", "uninstall":
                var dirs = a.positional.isEmpty && a.option("--all") == nil ? [FileManager.default.currentDirectoryPath] : a.positional
                if let root = a.option("--all") {
                    let base = (root as NSString).expandingTildeInPath
                    let finder = Process(); finder.executableURL = URL(fileURLWithPath: "/usr/bin/find")
                    finder.arguments = [base, "-maxdepth", "6", "-name", ".git", "-type", "d", "-not", "-path", "*/node_modules/*", "-prune"]
                    let pipe = Pipe(); finder.standardOutput = pipe; finder.standardError = FileHandle.nullDevice
                    try finder.run(); let out = pipe.fileHandleForReading.readDataToEndOfFile(); finder.waitUntilExit()
                    dirs += String(decoding: out, as: UTF8.self).split(separator: "\n").map { ($0 as NSString).deletingLastPathComponent }
                }
                var results: [String: String] = [:]
                for dir in dirs {
                    let path = (dir as NSString).expandingTildeInPath
                    results[path] = (try? GitGuard.install(in: path, executable: executable, remove: sub == "uninstall")) ?? "not a git repository"
                }
                struct Out: Encodable { let schemaVersion = 2; let ok = true; let repositories: [String: String] }
                let counts = Dictionary(grouping: results.values, by: { $0 }).mapValues(\.count)
                return (0, try json(Out(repositories: results)),
                        results.count == 1 ? "\(results.keys.first!): \(results.values.first!)" : counts.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n"))
            case "claude":
                // guard claude install|uninstall [--settings FILE]: the PreToolUse hook in Claude Code's user settings.
                let b = try Arguments(all.dropFirst(3), values: ["--settings"], usage: usage)
                let action = all.dropFirst(2).first ?? ""
                guard action == "install" || action == "uninstall" else { throw AgentError("invalid_arguments", "secretariat guard claude install|uninstall [--settings FILE]") }
                let settings = b.option("--settings").map { ($0 as NSString).expandingTildeInPath }
                    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json").path
                let result = try AgentHook.install(settings: settings, executable: executable, remove: action == "uninstall")
                return try done("Claude Code agent guard \(result): \(settings.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
            default: throw AgentError("invalid_arguments", "secretariat guard check | install [DIR …] [--all ROOT] | uninstall [DIR …] [--all ROOT] | claude install|uninstall")
            }

        case ("item", "rename"):
            let a = try Arguments(all.dropFirst(2), usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Usage: secretariat item rename PATH NEW_PATH") }
            return try show(try vault.rename(path: a.positional[0], to: a.positional[1]))

        case ("get", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat get PATH/FIELD") }
            let (_, field) = try vault.resolve(try FieldReference(a.positional[0]))
            guard field.kind == .identifier, let value = field.value else {
                throw AgentError("secret_field", "\(a.positional[0]) is a field of kind '\(field.kind.title)' – Secretariat doesn't print its value. Programs get it through run.")
            }
            struct Value: Encodable { let schemaVersion = 2; let ok = true; let reference: String; let value: String }
            return (0, try json(Value(reference: a.positional[0], value: value)), value)

        case ("field", "move"):
            let a = try Arguments(all.dropFirst(2), flags: ["--replace"], usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Usage: secretariat field move PATH/FIELD PATH/FIELD") }
            try vault.moveField(from: try FieldReference(a.positional[0]), to: try FieldReference(a.positional[1]), replace: a.flags.contains("--replace"))
            return try done("Moved: \(a.positional[0]) → \(a.positional[1])")

        case ("import", _):
            let a = try Arguments(all.dropFirst(), values: ["--profile"], flags: ["--replace"], usage: usage)
            guard a.positional.count >= 2 else { throw AgentError("invalid_arguments", "Usage: secretariat import FILE VARIABLE[=PATH/FIELD] …") }
            let file = (a.positional[0] as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: file), let text = String(data: data, encoding: .utf8) else {
                throw AgentError("file_unreadable", "File not readable: \(a.positional[0])")
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
            guard missing.isEmpty else { throw AgentError("variable_missing", "Missing or empty in the file: \(missing.joined(separator: ", "))") }
            var profile = try a.option("--profile").map { try service.profile(named: $0) }
            for (variable, reference) in pairs {
                try vault.setValue(reference, value: env[variable]!, source: "imported from \(a.positional[0])", replace: a.flags.contains("--replace"))
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
                    pairs.map { "\($0.0) → \($0.1)" }.joined(separator: "\n") + (profile.map { "\nProfile: \($0.name)" } ?? ""))

        case ("import-file", _):
            let a = try Arguments(all.dropFirst(), flags: ["--replace"], usage: usage)
            guard a.positional.count == 2 else { throw AgentError("invalid_arguments", "Usage: secretariat import-file FILE PATH/FIELD") }
            let path = (a.positional[0] as NSString).expandingTildeInPath
            guard let data = FileManager.default.contents(atPath: path), !data.isEmpty, data.count <= 256_000 else {
                throw AgentError("file_unreadable", "File not readable, empty or larger than 250 KB: \(a.positional[0])")
            }
            let reference = try FieldReference(a.positional[1])
            try vault.setValue(reference, value: data.base64EncodedString(), kind: .file, fileName: (path as NSString).lastPathComponent,
                               itemKind: "certificate", source: "import-file \(a.positional[0])", replace: a.flags.contains("--replace"))
            return try done("File imported: \(reference) (the original file stays in place; the user decides whether to delete it)")

        // MARK: profiles
        case ("profiles", _):
            let result = try service.profiles()
            return (0, try json(result), result.profiles.isEmpty ? "No profiles yet." : result.profiles.map { "\($0.name)\t\($0.directory)" }.joined(separator: "\n"))
        case ("describe", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat describe PROFILE") }
            let result = try service.describe(a.positional[0])
            return (0, try json(result), (["\(result.profile.name)", "Folder: \(result.profile.directory)"]
                + result.profile.bindings.sorted { $0.key < $1.key }.map { "\($0.key) ← \($0.value)" }).joined(separator: "\n"))
        case ("check", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat check PROFILE") }
            let timeout = AgentError("keychain_timeout", "The keychain didn't respond in time. Please try again.")
            let watchdog = CheckWatchdog(output: a.json ? try json(AgentFailure(timeout)) : timeout.message)
            watchdog.start(); defer { _ = watchdog.finish() }
            let result = try service.check(a.positional[0])
            guard watchdog.finish() else { return (2, nil, nil) }
            let text = (["\(result.profile): \(result.ok ? "ready" : "not ready")"] + (result.directoryExists ? [] : ["Project folder missing."])
                + result.variables.map { "\($0.variable) ← \($0.reference): \($0.status)" }).joined(separator: "\n")
            return (result.ok ? 0 : 2, try json(result), text)
        case ("instructions", _):
            guard all.count == 2 else { throw AgentError("invalid_arguments", "Usage: secretariat instructions PROFILE") }
            return (0, nil, ProjectInstructions.body(profile: try service.profile(named: all[1]), executable: executable))
        case ("setup", _):
            let a = try Arguments(all.dropFirst(), flags: ["--dry-run"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat setup PROFILE [--dry-run]") }
            let plan = try ProjectInstructions.preview(profile: service.profile(named: a.positional[0]), executable: executable)
            let dryRun = a.flags.contains("--dry-run")
            if !dryRun { try ProjectInstructions.apply(plan) }
            let result = SetupResult(plan: plan, dryRun: dryRun)
            let text = ([dryRun ? "Preview – no files changed:" : "Project instructions set up:"]
                + result.files.map { "\($0.name): \($0.changed ? (dryRun ? "will be updated" : "updated") : "unchanged")" }
                + (dryRun ? ["", plan.instructions] : [])).joined(separator: "\n")
            return (0, try json(result), text)

        case ("profile", _):
            let a = try Arguments(all.dropFirst(2), values: ["--dir", "--command"], usage: usage)
            func absolute(_ path: String) -> String {
                if path == Profile.anywhere { return path }
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath,
                    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
                    .standardizedFileURL.resolvingSymlinksInPath().path
            }
            func describe(_ name: String) throws -> (Int32, String?, String?) {
                let result = try service.describe(name)
                return (0, try json(result), "\(name)\nFolder: \(result.profile.directory)\nVariables: \(result.profile.variables.isEmpty ? "–" : result.profile.variables.joined(separator: ", "))")
            }
            switch (sub, a.positional.count) {
            case ("which", 0), ("which", 1):
                // The profile for a folder: its own or the closest enclosing project's.
                let dir = absolute(a.positional.first ?? ".")
                let match = try vault.configuration.load().profiles.filter { !$0.isAnywhere && (dir == $0.directory || dir.hasPrefix($0.directory + "/")) }
                    .max { $0.directory.count < $1.directory.count }
                guard let match else { throw AgentError("profile_not_found", "No profile for \(dir).") }
                return try describe(match.name)
            case ("create", 1):
                guard let dir = a.option("--dir") else { throw AgentError("invalid_arguments", "--dir FOLDER is missing.") }
                if (try? service.profile(named: a.positional[0])) != nil { throw AgentError("profile_exists", "A profile with this name already exists.") }
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
                    throw AgentError("variable_not_bound", "This variable isn't bound to the profile.")
                }
                profile.bindings.removeAll { $0.variable == a.positional[1] }
                try vault.saveProfile(profile); return try describe(profile.name)
            case ("delete", 1):
                try vault.deleteProfile(id: try service.profile(named: a.positional[0]).id)
                return try done("Profile removed: \(a.positional[0])")
            default: throw AgentError("invalid_arguments", usage)
            }

        case ("inject", _):
            let a = try Arguments(all.dropFirst(), values: ["--out"], usage: usage)
            guard a.positional.count == 1, let out = a.option("--out") else { throw AgentError("invalid_arguments", "Usage: secretariat inject TEMPLATE --out FILE") }
            let rendered = try Inject.render(template: a.positional[0], vault: vault)
            try Inject.write(rendered.text, to: out)
            vault.audit.record("inject", ["out": out, "fields": rendered.references.joined(separator: ",")])
            return try done("\(out) written (\(rendered.references.count) references, permissions 0600)")

        // MARK: targets
        case ("targets", _):
            let report = try Targets.report(vault: vault)
            return (0, try json(report), report.targets.isEmpty ? "No targets." : report.targets.map { target in
                "\(target.name)\t\(target.destination)\n" + target.variables.map { "  \($0.variable) ← \($0.reference): \($0.status)" }.joined(separator: "\n")
            }.joined(separator: "\n"))
        case ("target", _):
            let a = try Arguments(all.dropFirst(2), values: ["--command", "--dir", "--env-file"], usage: usage)
            func target(_ name: String) throws -> Target {
                guard let t = try vault.configuration.load().targets.first(where: { $0.name == name }) else {
                    throw AgentError("target_not_found", "Target not found. Existing targets: secretariat targets")
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
                } else { throw AgentError("invalid_arguments", "--command 'COMMAND {var}' or --env-file HOST:PATH") }
                if (try? target(t.name)) != nil { throw AgentError("target_exists", "A target with this name already exists.") }
                try vault.saveTarget(t); return try done("Target created: \(t.name)")
            case ("map", 3):
                var t = try target(a.positional[0])
                let new = try binding(a.positional[1], a.positional[2])
                t.bindings.removeAll { $0.variable == new.variable }; t.bindings.append(new)
                try vault.saveTarget(t); return try done("\(t.name): \(new.variable) ← \(a.positional[2])")
            case ("unmap", 2):
                var t = try target(a.positional[0])
                t.bindings.removeAll { $0.variable == a.positional[1] }; t.pushed.removeValue(forKey: a.positional[1])
                try vault.saveTarget(t); return try done("\(t.name): \(a.positional[1]) removed")
            case ("delete", 1):
                try vault.deleteTarget(id: try target(a.positional[0]).id); return try done("Target removed: \(a.positional[0])")
            default: throw AgentError("invalid_arguments", usage)
            }
        case ("push", _):
            let a = try Arguments(all.dropFirst(), flags: ["--dry-run"], usage: usage)
            guard a.positional.count == 1 else { throw AgentError("invalid_arguments", "Usage: secretariat push TARGET [--dry-run]") }
            let lines = try Targets.push(a.positional[0], vault: vault, dryRun: a.flags.contains("--dry-run"))
            return try done(lines.joined(separator: "\n"))

        // MARK: overview
        case ("registry", "export"):
            guard vault.registryDirectory != nil else { throw AgentError("no_registry", "No registry at ~/.claude/registry (only the real Secretariat folder exports one).") }
            vault.exportRegistry()
            return try done("Registry written: ~/.claude/registry/accounts.toml")
        case ("scan", _):
            let a = try Arguments(all.dropFirst(), usage: usage)
            let root = (a.positional.first.map { ($0 as NSString).expandingTildeInPath }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("work").path
            let findings = try Scan.run(root: URL(fileURLWithPath: root), vault: vault)
            struct Report: Encodable { let schemaVersion = 2; let ok = true; let findings: [Scan.Finding] }
            return (0, try json(Report(findings: findings)), findings.isEmpty ? "No .env files with values found." : findings.map {
                "\($0.file)\n" + $0.variables.map { "  \($0.name)\($0.storedAs.map { "  = in Secretariat: \($0)" } ?? "")" }.joined(separator: "\n")
            }.joined(separator: "\n"))
        case ("sweep", _):
            let a = try Arguments(all.dropFirst(), flags: ["--current"], usage: usage)
            let root = (a.positional.first.map { ($0 as NSString).expandingTildeInPath }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("work").path
            let repos = Sweep.repositories(under: root)
            let findings = try Sweep.run(repositories: repos, secrets: GitGuard.secrets(vault), history: !a.flags.contains("--current"))
            vault.audit.record("sweep", ["repositories": String(repos.count), "findings": String(findings.count)])
            struct Out: Encodable { let schemaVersion = 2; let ok: Bool; let repositories: Int; let findings: [Sweep.Finding]; let rotate: [String] }
            let rotate = Array(Set(findings.map(\.reference))).sorted()
            var lines = ["Secretariat sweep: \(repos.count) repositories, \(findings.isEmpty ? "no known secret values found" : "\(findings.count) places with known secret values")."]
            for (repo, group) in Dictionary(grouping: findings, by: \.repository).sorted(by: { $0.key < $1.key }) {
                lines.append(repo)
                lines += group.map { "  \($0.file)  value of \($0.reference)  \($0.current ? "in the current files" : "in history")\($0.commit.map { " since \($0)" } ?? "")" }
            }
            if !rotate.isEmpty {
                lines.append("Rotate these keys (they are in git, so every clone and fork has them): \(rotate.joined(separator: ", "))")
                lines.append("Then push the new values with secretariat push, and remove current copies from the files.")
            }
            return (findings.isEmpty ? 0 : 1, try json(Out(ok: findings.isEmpty, repositories: repos.count, findings: findings, rotate: rotate)), lines.joined(separator: "\n"))

        case ("lint", _):
            _ = try Arguments(all.dropFirst(), flags: [], usage: usage)
            let problems = Placeholder.scan(vault)
            struct Out: Encodable { let schemaVersion = 2; let ok: Bool; let problems: [Placeholder.Problem] }
            let text = problems.isEmpty ? "All stored values look like real values." : (["\(problems.count) stored value(s) are not real values:"]
                + problems.map { "  \($0.reference)  – \($0.reason)" }
                + ["Store the real value (secretariat set PATH/FIELD) or remove the field."]).joined(separator: "\n")
            return (problems.isEmpty ? 0 : 1, try json(Out(ok: problems.isEmpty, problems: problems)), text)

        case ("tidy", _):
            let a = try Arguments(all.dropFirst(), flags: ["--apply"], usage: usage)
            let root = (a.positional.first.map { ($0 as NSString).expandingTildeInPath }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("work").path
            let entries = try Tidy.run(root: URL(fileURLWithPath: root), vault: vault, apply: a.flags.contains("--apply"))
            struct Out: Encodable { let schemaVersion = 2; let ok = true; let applied: Bool; let files: [Tidy.Entry] }
            let movable = entries.filter { $0.action == "trash" }.count
            let text = entries.isEmpty ? "No .env files with values found." : (entries.map {
                "\($0.action == "keep" ? "keep   " : $0.action == "trash" ? "trash  " : "trashed")  \($0.file)  – \($0.reason)\($0.profile.map { " (profile \($0))" } ?? "")"
            } + (movable > 0 ? ["\(movable) file(s) can go to the Trash: secretariat tidy \(a.positional.first ?? "") --apply"] : [])).joined(separator: "\n")
            return (0, try json(Out(applied: a.flags.contains("--apply"), files: entries)), text)

        case ("license", _):
            let action = sub.hasPrefix("--") ? "" : sub
            let a = try Arguments(all.dropFirst(action.isEmpty && !sub.isEmpty ? 1 : 2), usage: usage)
            let licensing = vault.licensing
            switch action {
            case "activate":
                // From a file, or the JSON block on stdin: pbpaste | secretariat license activate
                let raw = a.positional.first.map { $0 == "-" ? nil : $0 } ?? nil
                let text = try raw.map { try String(contentsOfFile: ($0 as NSString).expandingTildeInPath, encoding: .utf8) }
                    ?? String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
                let license = try licensing.activate(text)
                vault.audit.record("license.activate", [:])
                return try done("Licensed to \(license.email). Thank you! The license is valid on all your Macs.")
            case "remove":
                try licensing.remove(); return try done("License removed from this keychain (all Macs).")
            case "", "status":
                struct Out: Encodable { let schemaVersion = 2; let ok = true; let state: String; let email: String?; let daysLeft: Int?; let buyURL: String }
                let state = licensing.state()
                let out: Out, text: String
                switch state {
                case .licensed(let email):
                    out = Out(state: "licensed", email: email, daysLeft: nil, buyURL: Licensing.buyURL.absoluteString)
                    text = email.isEmpty ? "This build doesn't check licenses." : "Licensed to \(email)."
                case .trial(let days):
                    out = Out(state: "trial", email: nil, daysLeft: days, buyURL: Licensing.buyURL.absoluteString)
                    text = "Trial: \(days) day\(days == 1 ? "" : "s") left. Buy: \(Licensing.buyURL.absoluteString)"
                case .expired:
                    out = Out(state: "expired", email: nil, daysLeft: 0, buyURL: Licensing.buyURL.absoluteString)
                    text = Licensing.reminder(state)!
                }
                return (0, try json(out), text)
            default: throw AgentError("invalid_arguments", "secretariat license [status] | activate [FILE|-] | remove")
            }

        case ("status", _):
            // Overview for dashboards (the fleet Leitstand): names, dates and counts only — never a value.
            let a = try Arguments(all.dropFirst(), values: ["--days", "--lines"], usage: usage)
            let days = a.option("--days").flatMap(Int.init) ?? 30
            let items = try vault.list()
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let cutoff = f.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date())!)
            struct Expiring: Encodable { let path: String; let expires: String }
            struct TargetState: Encodable { let name: String; let stale: [String]; let never: [String]; let missing: [String] }
            struct Out: Encodable {
                let schemaVersion = 2; let ok = true; let version: String; let items: Int; let profiles: Int
                let expiring: [Expiring]; let approval: [String]; let targets: [TargetState]; let recent: [String]; let license: String
            }
            let report = try Targets.report(vault: vault)
            let license: String = switch vault.licensing.state() {
            case .licensed: "licensed"
            case .trial(let days): "trial, \(days) days left"
            case .expired: "trial ended – \(Licensing.buyURL.absoluteString)"
            }
            let targets = report.targets.map { t in
                TargetState(name: t.name, stale: t.variables.filter { $0.status == "stale" }.map(\.variable),
                            never: t.variables.filter { $0.status == "never" }.map(\.variable),
                            missing: t.variables.filter { $0.status == "missing" }.map(\.variable))
            }
            let out = Out(version: CommandLineInterface.version, items: items.count, profiles: try vault.configuration.load().profiles.count,
                          expiring: items.compactMap { i in i.expires.flatMap { $0 <= cutoff ? Expiring(path: i.path, expires: $0) : nil } }.sorted { $0.expires < $1.expires },
                          approval: items.filter(\.needsApproval).map(\.path).sorted(), targets: targets,
                          recent: vault.audit.tail(a.option("--lines").flatMap(Int.init) ?? 20), license: license)
            let text = ["Secretariat \(out.version): \(out.items) items, \(out.profiles) profiles",
                        "expiring within \(days) days: \(out.expiring.isEmpty ? "none" : out.expiring.map { "\($0.path) (\($0.expires))" }.joined(separator: ", "))",
                        "need Touch ID: \(out.approval.isEmpty ? "none" : out.approval.joined(separator: ", "))",
                        "license: \(license)",
                        "targets: \(targets.isEmpty ? "none" : targets.map { "\($0.name)\($0.stale.isEmpty && $0.never.isEmpty && $0.missing.isEmpty ? " ok" : " stale \($0.stale.count) never \($0.never.count) missing \($0.missing.count)")" }.joined(separator: ", "))"]
            return (0, try json(out), text.joined(separator: "\n"))

        case ("log", _):
            let a = try Arguments(all.dropFirst(), values: ["--lines"], usage: usage)
            let lines = vault.audit.tail(a.option("--lines").flatMap(Int.init) ?? 30)
            return (0, "[\(lines.joined(separator: ","))]", lines.isEmpty ? "No log entries yet." : lines.joined(separator: "\n"))
        default:
            throw AgentError("invalid_arguments", "Unknown command. \(usage)")
        }
    }
}

// MARK: - inject

enum Inject {
    static func render(template: String, vault: Vault) throws -> (text: String, references: [String]) {
        guard let source = try? String(contentsOfFile: (template as NSString).expandingTildeInPath, encoding: .utf8) else {
            throw AgentError("file_unreadable", "Template not readable: \(template)")
        }
        let regex = try NSRegularExpression(pattern: #"\{\{\s*([^}\s]+)\s*\}\}"#)
        var output = source, references: [String] = []
        let all = regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap {
            try? vault.resolve(try FieldReference(String(source[Range($0.range(at: 1), in: source)!]))).0.id
        }
        try vault.requireApproval(all, for: "inject \((template as NSString).lastPathComponent)")
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            let reference = String(source[Range(match.range(at: 1), in: source)!])
            let (item, field) = try vault.resolve(try FieldReference(reference))
            var value = try vault.value(itemID: item.id, field: field.name)
            if field.kind == .file {
                guard let data = Data(base64Encoded: value), let text = String(data: data, encoding: .utf8) else {
                    throw AgentError("binary_file", "\(reference) is not a text file and can't be inserted.")
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
            throw AgentError("tracked_destination", "\(out) is inside a git repository and not in .gitignore. Ignore it first or choose another location.")
        }
        try? FileManager.default.removeItem(at: url)
        guard FileManager.default.createFile(atPath: url.path, contents: Data(text.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw AgentError("write_failed", "\(out) could not be written.")
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
                let reference = (items.first { $0.id == b.itemID }?.path ?? "(missing)") + "/" + b.field
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
            throw AgentError("target_not_found", "Target not found. Existing targets: secretariat targets")
        }
        guard !target.bindings.isEmpty else { throw AgentError("target_empty", "No variable is mapped to this target yet.") }
        try vault.requireApproval(target.bindings.map(\.itemID), for: "push \(name)")
        var values: [(String, String)] = []
        for b in target.bindings.sorted(by: { $0.variable < $1.variable }) { values.append((b.variable, try vault.value(itemID: b.itemID, field: b.field))) }
        if dryRun { return ["Would write to \(destination(target)): \(values.map(\.0).joined(separator: ", "))"] }
        var lines: [String] = []
        switch target.kind {
        case .command:
            for (variable, value) in values {
                let command = target.command.replacingOccurrences(of: "{var}", with: variable)
                let status = run("/bin/zsh", ["-c", command], directory: target.directory, stdin: value)
                guard status == 0 else { throw AgentError("push_failed", "\(variable): command exited with \(status). Variables already pushed are recorded.") }
                target.pushed[variable] = vault.fingerprint(value, salt: config.salt)
                lines.append("\(variable): pushed")
                try vault.saveTarget(target)
            }
        case .envFile:
            let body = values.map { "\($0.0)=\(shellQuote($0.1))" }.joined(separator: "\n") + "\n"
            let remotePath = target.path
            let script = "umask 077; mkdir -p \"$(dirname \(remotePath))\" && cat > \(remotePath).secretariat-tmp && mv \(remotePath).secretariat-tmp \(remotePath)"
            let status = run("/usr/bin/ssh", ["-o", "BatchMode=yes", target.host, script], directory: FileManager.default.currentDirectoryPath, stdin: body)
            guard status == 0 else { throw AgentError("push_failed", "ssh \(target.host) exited with \(status).") }
            for (variable, value) in values { target.pushed[variable] = vault.fingerprint(value, salt: config.salt) }
            lines.append("\(target.host):\(remotePath): \(values.count) variables written")
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
    struct Finding: Encodable { let file: String; let path: String; let variables: [Variable] }
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
                if !vars.isEmpty { findings.append(Finding(file: entry.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), path: entry.path, variables: vars)) }
            }
        }
        walk(root, depth: 6)
        return findings.sorted { $0.file < $1.file }
    }
}
