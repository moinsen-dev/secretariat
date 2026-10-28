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

    public func execute() throws -> Never {
        guard chdir(directory) == 0 else { throw SecretariatError("The project folder can't be reached. Please fix the folder in the profile.") }
        let executable = try resolveExecutable()
        // Without files: replace this process, preserving terminal, process group, signals and exit status.
        guard !files.isEmpty else {
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
        var pid: pid_t = 0
        let spawned = withCStrings(arguments, environment) { argv, envp in posix_spawn(&pid, executable, nil, &attributes, argv, envp) }
        guard spawned == 0 else { throw SecretariatError("The program could not be started (system error \(spawned)).") }
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
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
    public static let version = "1.4.2"
    public static let help = """
    Secretariat \(version) – confidential data for you and your agents

    Items (path org/account/name; fields: identifier, secret, file, only for me)
      secretariat items [--expiring DAYS] [--json]
      secretariat item show PATH [--json]
      secretariat item create PATH --kind KIND [--set FIELD=VALUE …] [--source TEXT] [--expires YYYY-MM-DD] [--json]
      secretariat item set PATH [--set FIELD=VALUE …] [--unset FIELD …] [--source TEXT] [--expires YYYY-MM-DD] [--json]
      secretariat item rename PATH NEW_PATH [--json]
      secretariat get PATH/FIELD                     value of an identifier (never secrets)
      secretariat field move PATH/FIELD PATH/FIELD [--replace] [--json]
      secretariat import FILE VARIABLE[=PATH/FIELD] … [--profile PROFILE] [--replace] [--json]
      secretariat import-file FILE PATH/FIELD [--replace] [--json]
      Kinds: account, login, api, token, certificate, database, server, note

    Projects
      secretariat profiles [--json] · describe PROFILE [--json] · check PROFILE [--json]
      secretariat profile create PROFILE --dir FOLDER [--command COMMAND] [--json]   --dir '*': no fixed folder (tool tokens)
      secretariat profile which [FOLDER]               profile of this (or the enclosing) project folder
      secretariat profile set PROFILE [--dir FOLDER] [--command COMMAND] [--json]
      secretariat profile bind PROFILE VARIABLE PATH/FIELD [--json] · unbind PROFILE VARIABLE · delete PROFILE
      secretariat run PROFILE -- PROGRAM [ARGUMENTS …]   file fields arrive as the path of a temporary file
      secretariat inject TEMPLATE --out FILE            replaces {{ PATH/FIELD }}; keep the output out of git
      secretariat instructions PROFILE · setup PROFILE [--dry-run] [--json]

    Targets (copies outside your Macs: Workers, Supabase, GitHub, Linux hosts)
      secretariat target add NAME --command 'COMMAND {var}' [--dir FOLDER] [--json]
      secretariat target add NAME --env-file HOST:PATH [--json]
      secretariat target map NAME VARIABLE PATH/FIELD · unmap NAME VARIABLE · delete NAME
      secretariat targets [--json]                     current / stale / never pushed
      secretariat push NAME [--dry-run] [--json]

    Overview
      secretariat registry export · scan [FOLDER] [--json] · log [--lines N] · --version

    The CLI never prints secret values. Enter them via the app, import or import-file.
    """

    public static func run(_ arguments: [String], vault: Vault? = nil) throws -> Int32 {
        let vault = vault ?? Vault(paths: AppPaths())
        switch arguments.first {
        case "--help", "-h", "help", nil: print(help); return 0
        case "--version": print("Secretariat \(version)"); return 0
        case "run":
            guard arguments.count >= 4, arguments[2] == "--" else {
                throw SecretariatError("Usage: secretariat run PROFILE -- PROGRAM [ARGUMENTS …]")
            }
            try vault.preparedLaunch(name: arguments[1], arguments: Array(arguments.dropFirst(3)),
                                     inheritedEnvironment: ProcessInfo.processInfo.environment).execute()
        default:
            let executable = Bundle.main.executableURL?.path ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
            return try Commands.execute(arguments, service: AgentService(vault: vault), executable: executable)
        }
    }
}
