import Foundation

// `secretariat mcp`: a Model Context Protocol server over stdio for agents without a shell (Claude Desktop,
// Cursor, chat apps). Every tool maps onto the same CLI commands agents use in a terminal, so the rules are
// identical: names and identifiers only, values reach programs (`run_command`), output is always masked,
// approval items still ask for Touch ID.

public enum McpServer {
    struct Tool {
        let name: String
        let description: String
        let properties: [String: [String: Any]]
        let required: [String]
        let arguments: ([String: Any]) throws -> [String]
    }

    static func string(_ args: [String: Any], _ key: String) throws -> String {
        guard let value = args[key] as? String, !value.isEmpty else { throw AgentError("invalid_arguments", "Missing argument '\(key)'.") }
        return value
    }
    nonisolated(unsafe) static let str: [String: Any] = ["type": "string"]

    nonisolated(unsafe) static let tools: [Tool] = [
        Tool(name: "status", description: "Overview of Secretariat: item and profile counts, items expiring soon, items that need Touch ID, targets with stale copies, recent log. Names only, never values.",
             properties: [:], required: []) { _ in ["status"] },
        Tool(name: "list_items", description: "All items (path like moinsen/openai) with their template and fields. Identifier values are included; secret values never are.",
             properties: [:], required: []) { _ in ["items"] },
        Tool(name: "show_item", description: "One item with its fields (identifier values only).",
             properties: ["path": str], required: ["path"]) { a in ["item", "show", try string(a, "path")] },
        Tool(name: "open_login", description: "Open a login item's web address (field url or website) in the user's default browser and let the Secretariat app fill the user name and password after the user confirms with Touch ID. You never get the password; the form is not submitted, the user does that. Use it when the user wants to be signed in to a site.",
             properties: ["path": str], required: ["path"]) { a in ["open", try string(a, "path")] },
        Tool(name: "get_identifier", description: "Value of a non-secret identifier field, e.g. moinsen/apple-developer/team_id or moinsen/company/email. Refuses secret fields.",
             properties: ["reference": str], required: ["reference"]) { a in ["get", try string(a, "reference")] },
        Tool(name: "list_templates", description: "Templates (kinds of items) with their fields.",
             properties: [:], required: []) { _ in ["template", "list"] },
        Tool(name: "list_profiles", description: "Project profiles: folder and which variables they map to which item fields.",
             properties: [:], required: []) { _ in ["profiles"] },
        Tool(name: "find_profile", description: "The profile for a project folder (or the closest enclosing one).",
             properties: ["directory": str], required: ["directory"]) { a in ["profile", "which", try string(a, "directory")] },
        Tool(name: "check_profile", description: "Whether every variable of a profile is available (available / missing / personal / unavailable). No values.",
             properties: ["profile": str], required: ["profile"]) { a in ["check", try string(a, "profile")] },
        Tool(name: "create_profile", description: "Create a project profile for a folder.",
             properties: ["profile": str, "directory": str, "command": str], required: ["profile", "directory"]) { a in
            ["profile", "create", try string(a, "profile"), "--dir", try string(a, "directory")] + ((a["command"] as? String).map { ["--command", $0] } ?? [])
        },
        Tool(name: "bind_variable", description: "Map an environment variable of a profile to an item field (PATH/FIELD), e.g. OPENAI_API_KEY → moinsen/openai/api_key.",
             properties: ["profile": str, "variable": str, "reference": str], required: ["profile", "variable", "reference"]) { a in
            ["profile", "bind", try string(a, "profile"), try string(a, "variable"), try string(a, "reference")]
        },
        Tool(name: "import_env", description: "Move values from a .env file into Secretariat without reading them: mappings VAR → PATH/FIELD; optionally bind them to a profile.",
             properties: ["file": str, "mappings": ["type": "object", "additionalProperties": ["type": "string"]], "profile": str], required: ["file", "mappings"]) { a in
            guard let mappings = a["mappings"] as? [String: String], !mappings.isEmpty else { throw AgentError("invalid_arguments", "mappings must map VAR to PATH/FIELD.") }
            return ["import", try string(a, "file")] + mappings.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
                + ((a["profile"] as? String).map { ["--profile", $0] } ?? [])
        },
        Tool(name: "login_inventory", description: "Inventory of the user's website logins: counts of local addresses, reused, weak and leaked passwords, gone domains, decisions and how hard each account is to close. Optional: from (browser profile, e.g. \"Chrome: Work\"), finding (local|reused|weak|leaked|domainGone) or closing (easy|medium|hard|impossible) to list matching login paths. Never values.",
             properties: ["from": str, "finding": str, "closing": str], required: []) { a in
            ["audit-logins"] + ((a["from"] as? String).map { ["--from", $0] } ?? []) + ((a["finding"] as? String).map { ["--finding", $0] } ?? [])
                + ((a["closing"] as? String).map { ["--closing", $0] } ?? [])
        },
        Tool(name: "login_sites", description: "Website logins grouped by site (registrable domain) with usernames, browser profiles, findings, the user's decisions and the known way to close the account (deletion page, contact, difficulty, source). needs_route=true lists only sites without a known way: research those (the site's help pages and privacy policy) and record what you find with set_deletion_route. Paged with limit/offset.",
             properties: ["needs_route": ["type": "boolean"], "from": str, "decision": ["type": "string", "description": "open, keep, close or change"],
                          "limit": ["type": "integer"], "offset": ["type": "integer"]], required: []) { a in
            ["login-sites"] + ((a["needs_route"] as? Bool) == true ? ["--needs-route"] : []) + ((a["from"] as? String).map { ["--from", $0] } ?? [])
                + ((a["decision"] as? String).map { ["--decision", $0] } ?? [])
                + ((a["limit"] as? Int).map { ["--limit", String($0)] } ?? []) + ((a["offset"] as? Int).map { ["--offset", String($0)] } ?? [])
        },
        Tool(name: "set_deletion_route", description: "Record how to close the account on a site, for every login of that site: deletion page (url) and/or contact for a deletion request (contact: privacy e-mail or contact form), difficulty (easy: a delete button; medium: extra steps; hard: only via support or a request; impossible: no real deletion, or the service shut down; then url and contact may be empty) and the page you found it on (source, required). Optional one-line note. Only record what the source says; this does not close anything.",
             properties: ["site": str, "difficulty": str, "url": str, "contact": str, "note": str, "source": str], required: ["site", "difficulty", "source"]) { a in
            ["login-route", try string(a, "site"), "--difficulty", try string(a, "difficulty"), "--source", try string(a, "source")]
                + ((a["url"] as? String).map { ["--url", $0] } ?? []) + ((a["contact"] as? String).map { ["--contact", $0] } ?? [])
                + ((a["note"] as? String).map { ["--note", $0] } ?? [])
        },
        Tool(name: "guard_check", description: "Check a git repository's staged changes for known secret values (file:line and item names only).",
             properties: ["directory": str], required: ["directory"]) { a in ["guard", "check", try string(a, "directory")] },
    ]

    nonisolated(unsafe) static let runTool: [String: Any] = [
        "name": "run_command",
        "description": "Run a command with a profile's credentials in its project folder (like `secretariat run`). stdout/stderr come back with every secret value masked. Items marked for approval ask Uli for Touch ID first.",
        "inputSchema": ["type": "object", "properties": ["profile": str, "command": ["type": "array", "items": ["type": "string"], "description": "argv, e.g. [\"npm\", \"test\"]"],
                                                        "timeout_seconds": ["type": "integer"]], "required": ["profile", "command"]],
    ]

    public static func serve(service: AgentService, executable: String) {
        Origin.set(Origin.mcp)
        while let line = readLine(strippingNewline: true) {
            guard let data = line.data(using: .utf8), let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard let id = message["id"] else { continue }   // notifications need no answer
            let method = message["method"] as? String ?? ""
            let params = message["params"] as? [String: Any] ?? [:]
            var response: [String: Any] = ["jsonrpc": "2.0", "id": id]
            switch method {
            case "initialize":
                Origin.set(Origin.mcp(client: (params["clientInfo"] as? [String: Any])?["name"] as? String))
                response["result"] = ["protocolVersion": (params["protocolVersion"] as? String) ?? "2025-06-18",
                                      "capabilities": ["tools": [:]],
                                      "serverInfo": ["name": "secretariat", "version": CommandLineInterface.version],
                                      "instructions": "Credentials for this Mac's projects. You never see secret values: read names and identifiers, wire profiles, and run commands through run_command (output is masked). Never ask the user to paste a key."]
            case "ping": response["result"] = [:] as [String: Any]
            case "tools/list":
                response["result"] = ["tools": tools.map { t in
                    ["name": t.name, "description": t.description,
                     "inputSchema": ["type": "object", "properties": t.properties, "required": t.required]] as [String: Any]
                } + [runTool]]
            case "tools/call":
                let name = params["name"] as? String ?? ""
                let args = params["arguments"] as? [String: Any] ?? [:]
                let (text, isError) = call(name, args, service: service, executable: executable)
                response["result"] = ["content": [["type": "text", "text": text]], "isError": isError]
            default:
                response["error"] = ["code": -32601, "message": "Method not found: \(method)"]
            }
            if let out = try? JSONSerialization.data(withJSONObject: response), let text = String(data: out, encoding: .utf8) {
                print(text); fflush(stdout)
            }
        }
    }

    static func call(_ name: String, _ args: [String: Any], service: AgentService, executable: String) -> (String, Bool) {
        do {
            if name == "run_command" { return try run(args, vault: service.vault) }
            guard let tool = tools.first(where: { $0.name == name }) else { throw AgentError("unknown_tool", "No tool \(name).") }
            let (code, json, _) = try Commands.dispatch(try tool.arguments(args) + ["--json"], service: service, executable: executable)
            service.vault.audit.record("mcp", ["tool": name])
            return (json ?? "{}", code != 0 && name != "check_profile" && name != "guard_check")
        } catch {
            return ((try? Commands.json(AgentFailure(error))) ?? "{\"ok\":false}", true)
        }
    }

    /// Runs the command as a child, captures and masks its output, enforces a timeout.
    static func run(_ args: [String: Any], vault: Vault) throws -> (String, Bool) {
        let profile = try string(args, "profile")
        guard let command = args["command"] as? [String], !command.isEmpty else { throw AgentError("invalid_arguments", "command must be a non-empty argv array.") }
        let timeout = min(max((args["timeout_seconds"] as? Int) ?? 120, 1), 1800)
        let launch = try vault.preparedLaunch(name: profile, arguments: command, inheritedEnvironment: ProcessInfo.processInfo.environment)
        var environment = launch.environment
        var folder: String?
        if !launch.files.isEmpty {
            let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("secretariat-mcp-\(UUID().uuidString)")
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            folder = dir
            for file in launch.files {
                let path = (dir as NSString).appendingPathComponent((file.name as NSString).lastPathComponent)
                FileManager.default.createFile(atPath: path, contents: file.data, attributes: [.posixPermissions: 0o600])
                environment[file.variable] = path
            }
        }
        defer { if let folder { try? FileManager.default.removeItem(atPath: folder) } }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        // Marks the child as running for an MCP client: `secretariat header` refuses to print into this output.
        environment[CommandLineInterface.mcpChildVariable] = "1"
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: launch.directory)
        let out = Pipe(), err = Pipe()
        process.standardOutput = out; process.standardError = err; process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = DispatchTime.now() + .seconds(timeout)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { process.waitUntilExit(); finished.signal() }
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter(); DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        var timedOut = false
        if finished.wait(timeout: deadline) == .timedOut { timedOut = true; process.terminate() ; _ = finished.wait(timeout: .now() + 5) }
        _ = group.wait(timeout: .now() + 5)
        func masked(_ data: Data) -> String {
            var m = StreamMasker(launch.masks); var d = m.feed(data); d.append(m.finish())
            let text = String(decoding: d, as: UTF8.self)
            return text.count > 60_000 ? "…(truncated)…\n" + String(text.suffix(60_000)) : text
        }
        struct Out: Encodable { let schemaVersion = 2; let ok: Bool; let exitCode: Int32; let timedOut: Bool; let stdout: String; let stderr: String }
        let result = Out(ok: !timedOut && process.terminationStatus == 0, exitCode: process.terminationStatus, timedOut: timedOut,
                         stdout: masked(outData), stderr: masked(errData))
        vault.audit.record("mcp.run", ["profile": profile, "exit": String(process.terminationStatus)])
        return (try Commands.json(result), !result.ok)
    }
}
