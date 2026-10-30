import Foundation
import Darwin

public struct PreparedLaunch {
    public struct File: Sendable {
        public let variable: String
        public let name: String
        public let data: Data
    }
    public let directory: String
    public let arguments: [String]
    public let environment: [String: String]
    public let files: [File]
    /// Values to mask in the program's output (Agent Guard).
    public var masks: [StreamMasker.Secret] = []
    public init(directory: String, arguments: [String], environment: [String: String], files: [File], masks: [StreamMasker.Secret] = []) {
        self.directory = directory; self.arguments = arguments; self.environment = environment; self.files = files; self.masks = masks
    }

    /// `mask`: nil = automatic — mask when stdout or stderr is not a terminal (an agent or a pipe reads it);
    /// a person at a terminal keeps the untouched, interactive program.
    public func execute(mask: Bool? = nil) throws -> Never {
        guard chdir(directory) == 0 else { throw SecretariatError("The project folder can't be reached. Please fix the folder in the profile.") }
        let executable = try resolveExecutable()
        let masking = !masks.isEmpty && (mask ?? (isatty(1) == 0 || isatty(2) == 0))
        // Without files or masking: replace this process, preserving terminal, process group, signals and exit status.
        guard !files.isEmpty || masking else {
            withCStrings(arguments, environment) { argv, envp in _ = execve(executable, argv, envp) }
            throw SecretariatError("The program could not be started (system error \(errno)).")
        }
        // With files: write them to a private temporary folder, run the program as a child in the same
        // process group (terminal signals reach it directly), then remove the folder.
        var template = Array((NSTemporaryDirectory() + "secretariat-run-XXXXXX").utf8CString)
        guard let folderPointer = mkdtemp(&template) else { throw SecretariatError("No temporary folder available for files.") }
        let folder = String(cString: folderPointer)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        var environment = environment
        for file in files {
            let path = (folder as NSString).appendingPathComponent((file.name as NSString).lastPathComponent)
            guard FileManager.default.createFile(atPath: path, contents: file.data, attributes: [.posixPermissions: 0o600]) else {
                throw SecretariatError("The file for \(file.variable) could not be provided.")
            }
            environment[file.variable] = path
        }
        signal(SIGINT, SIG_IGN); signal(SIGQUIT, SIG_IGN)
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes); defer { posix_spawnattr_destroy(&attributes) }
        var defaults = sigset_t(); sigemptyset(&defaults); sigaddset(&defaults, SIGINT); sigaddset(&defaults, SIGQUIT)
        posix_spawnattr_setsigdefault(&attributes, &defaults)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSIGDEF))
        // Masking: the child writes into pipes; two readers filter and forward to our own stdout/stderr.
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions); defer { posix_spawn_file_actions_destroy(&actions) }
        var pipes: [[Int32]] = []
        if masking {
            for target in [Int32(1), Int32(2)] {
                var fds: [Int32] = [0, 0]
                guard pipe(&fds) == 0 else { throw SecretariatError("Output masking could not be set up.") }
                posix_spawn_file_actions_adddup2(&actions, fds[1], target)
                posix_spawn_file_actions_addclose(&actions, fds[0]); posix_spawn_file_actions_addclose(&actions, fds[1])
                pipes.append(fds)
            }
        }
        var pid: pid_t = 0
        let spawned = withCStrings(arguments, environment) { argv, envp in posix_spawn(&pid, executable, &actions, &attributes, argv, envp) }
        guard spawned == 0 else { throw SecretariatError("The program could not be started (system error \(spawned)).") }
        let readers = DispatchGroup()
        for (index, fds) in pipes.enumerated() {
            close(fds[1])
            let source = fds[0], target = Int32(index + 1), secrets = masks
            readers.enter()
            Thread.detachNewThread {
                var masker = StreamMasker(secrets)
                var buffer = [UInt8](repeating: 0, count: 65536)
                func write(_ data: Data) { data.withUnsafeBytes { raw in var off = 0
                    while off < raw.count { let n = Darwin.write(target, raw.baseAddress! + off, raw.count - off); if n <= 0 { break }; off += n } } }
                while true {
                    let n = read(source, &buffer, buffer.count)
                    if n <= 0 { break }
                    write(masker.feed(Data(buffer[0..<n])))
                }
                write(masker.finish()); close(source); readers.leave()
            }
        }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
        readers.wait()
        try? FileManager.default.removeItem(atPath: folder)
        if status & 0x7f == 0 { exit((status >> 8) & 0xff) }
        signal(status & 0x7f, SIG_DFL); kill(getpid(), status & 0x7f)
        exit(128 + (status & 0x7f))
    }

    private func resolveExecutable() throws -> String {
        let program = arguments[0]
        if program.contains("/") {
            return URL(fileURLWithPath: program, relativeTo: URL(fileURLWithPath: directory, isDirectory: true)).standardizedFileURL.path
        }
        let paths = (environment["PATH"] ?? "/usr/bin:/bin").split(separator: ":", omittingEmptySubsequences: false)
        guard let match = paths.map({ URL(fileURLWithPath: String($0.isEmpty ? "." : $0)).appendingPathComponent(program).path })
            .first(where: { access($0, X_OK) == 0 && !isDirectory($0) }) else {
            throw SecretariatError("The program was not found in PATH. Please check the command.")
        }
        return match
    }
    private func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    private func withCStrings<T>(_ arguments: [String], _ environment: [String: String],
                                 _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>, UnsafePointer<UnsafeMutablePointer<CChar>?>) -> T) -> T {
        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.sorted(by: { $0.key < $1.key }).map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        return argv.withUnsafeBufferPointer { args in envp.withUnsafeBufferPointer { env in body(args.baseAddress!, env.baseAddress!) } }
    }
}

public enum CommandLineInterface {
    public static let version = "1.13.1"
    public static let help = """
    Secretariat \(version) – confidential data for you and your agents

    Items (path org/account/name; fields: identifier, secret, file, only for me)
      secretariat items [--expiring DAYS] [--json]
      secretariat item show PATH [--json]
      secretariat item create PATH --kind KIND [--set FIELD=VALUE …] [--source TEXT] [--expires YYYY-MM-DD] [--json]
      secretariat item set PATH [--set FIELD=VALUE …] [--unset FIELD …] [--source TEXT] [--expires YYYY-MM-DD] [--json]
      secretariat item rename PATH NEW_PATH [--json]
      secretariat get PATH/FIELD                     value of an identifier (never secrets)
      secretariat header PATH/FIELD [--bearer] [--name HEADER]
                                                     headersHelper for HTTP MCP servers: {"Authorization":"Bearer …"} to a pipe, never a terminal or file
      secretariat field move PATH/FIELD PATH/FIELD [--replace] [--json]
      secretariat import FILE VARIABLE[=PATH/FIELD] … [--profile PROFILE] [--replace] [--json]
      secretariat import-file FILE PATH/FIELD [--replace] [--json]
      Kinds are templates: secretariat template list | show ID
      secretariat template create ID --title T [--symbol SF] [--explanation E] [--identity]
      secretariat template set ID [--title T] [--symbol SF] [--explanation E] [--identity|--no-identity]
      secretariat template field add ID NAME [--label L] [--kind identifier|secret|file|personal] [--required] [--prompt P] [--env SUFFIX]
      secretariat template field remove ID NAME · template delete ID · template reset ID

    Projects
      secretariat profiles [--json] · describe PROFILE [--json] · check PROFILE [--json]
      secretariat profile create PROFILE --dir FOLDER [--command COMMAND] [--json]   --dir '*': no fixed folder (tool tokens)
      secretariat profile which [FOLDER]               profile of this (or the enclosing) project folder
      secretariat profile set PROFILE [--dir FOLDER] [--command COMMAND] [--json]
      secretariat profile bind PROFILE VARIABLE PATH/FIELD [--json] · unbind PROFILE VARIABLE · delete PROFILE
      secretariat run PROFILE [--mask|--no-mask] -- PROGRAM [ARGUMENTS …]
                                                     output to a pipe/agent: known values are masked automatically   file fields arrive as the path of a temporary file
      secretariat inject TEMPLATE --out FILE            replaces {{ PATH/FIELD }}; keep the output out of git
      secretariat instructions PROFILE · setup PROFILE [--dry-run] [--json]

    Targets (copies outside your Macs: Workers, Supabase, GitHub, Linux hosts)
      secretariat target add NAME --command 'COMMAND {var}' [--dir FOLDER] [--json]
      secretariat target add NAME --env-file HOST:PATH [--json]
      secretariat target map NAME VARIABLE PATH/FIELD · unmap NAME VARIABLE · delete NAME
      secretariat targets [--json]                     current / stale / never pushed
      secretariat push NAME [--dry-run] [--json]

    Agent Guard
      secretariat guard install [DIR …] [--all ROOT]  pre-commit hook: refuse commits with known secret values
      secretariat guard uninstall [DIR …] [--all ROOT] · guard check [DIR]
      secretariat item set PATH --approval on          programs need Touch ID before they get this item (off: app only)
      secretariat guard claude install|uninstall      Claude Code hook: refuse cat .env, printenv, docker compose config … before they run
      secretariat sweep [ROOT] [--current] [--json]   known secret values in your repositories and their git history (default ~/work)
      secretariat tidy [ROOT] [--apply]               .env files whose values are all in Secretariat → Trash (+ .env.example)
      secretariat lint [--json]                       stored values that are .env comments or template placeholders (names only)

    Overview
      secretariat mcp                                 MCP server (stdio) for Claude Desktop, Cursor & co.
      secretariat status [--days N] [--json]          overview: counts, expiring items, Touch ID items, targets, recent log
      secretariat screenshots [--json]                how many encrypted screenshots this Mac can open (counts only)
      secretariat registry export · scan [FOLDER] [--json] · log [--lines N] · --version
      secretariat backup status [--json]              automatic encrypted backup: key id, where, newest files (set up in the app)
      secretariat backup now [--json]                 back up right away (sealed to the backup key; only the recovery key opens it)
      secretariat history [--period day|week|month|quarter|year] [--via ORIGIN] [--lines N] [--json]
                                                     who used what on this Mac: app, terminal, script, MCP client or agent

    License (14 days to try everything; nothing is ever blocked)
      secretariat license [--json] · license activate [FILE|-] · license remove
                                                     pbpaste | secretariat license activate

    The CLI never prints secret values (one exception: header, into a pipe). Enter them via the app, import or import-file.
    """

    /// Set in children of the MCP tool run_command, whose output goes to the model.
    static let mcpChildVariable = "SECRETARIAT_MCP_CHILD"

    /// Why `header` must not print here, or nil: only into a pipe or socket (a headersHelper's stdout),
    /// never a terminal, a file, or a command started for an MCP client.
    static func headerRefusal(stdout descriptor: Int32, environment: [String: String]) -> String? {
        if environment[mcpChildVariable] != nil {
            return "secretariat header doesn't run inside an MCP tool call: its output would reach the model."
        }
        var info = stat()
        let kind = fstat(descriptor, &info) == 0 ? info.st_mode & S_IFMT : 0
        guard isatty(descriptor) == 0, kind == S_IFIFO || kind == S_IFSOCK else {
            return "secretariat header prints a secret for a program (Claude Code's headersHelper), not for a terminal or a file. "
                + "Register it: claude mcp add-json --scope user NAME '{\"type\":\"http\",\"url\":\"…\",\"headersHelper\":\"secretariat header PATH/FIELD --bearer\"}'"
        }
        return nil
    }

    public static func run(_ arguments: [String], vault: Vault? = nil) throws -> Int32 {
        let vault = vault ?? Vault(paths: AppPaths())
        // The retention set in the app applies on every call, also when the app isn't running.
        vault.pruneHistory()
        switch arguments.first {
        case "--help", "-h", "help", nil: print(help); return 0
        case "--version": print("Secretariat \(version)"); return 0
        case "guard" where arguments.dropFirst().first == "claude-hook":
            // Claude Code PreToolUse hook: tool call JSON on stdin, a deny decision on stdout. Silent = allowed.
            if let answer = AgentHook.handle(FileHandle.standardInput.readDataToEndOfFile()) {
                print(answer)
                vault.audit.record("guard.agent", [:])
            }
            return 0
        case "header" where headerRefusal(stdout: STDOUT_FILENO, environment: ProcessInfo.processInfo.environment) != nil:
            throw SecretariatError(headerRefusal(stdout: STDOUT_FILENO, environment: ProcessInfo.processInfo.environment)!)
        case "mcp":
            // MCP server over stdio for agents without a shell (Claude Desktop, Cursor …).
            let executable = Bundle.main.executableURL?.path ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
            McpServer.serve(service: AgentService(vault: vault), executable: executable)
            return 0
        case "run":
            // run PROFILE [--mask|--no-mask] -- PROGRAM …
            guard arguments.count >= 4, let dashes = arguments.firstIndex(of: "--"), dashes >= 2, dashes < arguments.count - 1 else {
                throw SecretariatError("Usage: secretariat run PROFILE [--mask|--no-mask] -- PROGRAM [ARGUMENTS …]")
            }
            let options = Set(arguments[2..<dashes])
            guard options.isSubset(of: ["--mask", "--no-mask"]), options.count < 2 else {
                throw SecretariatError("Usage: secretariat run PROFILE [--mask|--no-mask] -- PROGRAM [ARGUMENTS …]")
            }
            try vault.preparedLaunch(name: arguments[1], arguments: Array(arguments[(dashes + 1)...]),
                                     inheritedEnvironment: ProcessInfo.processInfo.environment)
                .execute(mask: options.contains("--mask") ? true : options.contains("--no-mask") ? false : nil)
        default:
            let executable = Bundle.main.executableURL?.path ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
            let code = try Commands.execute(arguments, service: AgentService(vault: vault), executable: executable)
            // Once a day from the CLI too, for Macs where the app rarely runs; never in the header helper's path.
            if !["header", "backup", "guard"].contains(arguments.first ?? "") { Backup.automatic(vault: vault, onlyDaily: true) }
            // The trial reminder goes to people at a terminal only; agents, pipes and values stay untouched.
            if isatty(STDERR_FILENO) == 1, isatty(STDOUT_FILENO) == 1, !arguments.contains("--json"),
               !["get", "inject", "license"].contains(arguments.first ?? ""), let reminder = Licensing.reminder(vault.licensing.state()) {
                FileHandle.standardError.write(Data("\n\(reminder)\n".utf8))
            }
            return code
        }
    }
}
