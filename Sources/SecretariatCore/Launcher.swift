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
        guard chdir(directory) == 0 else { throw SecretariatError("Der Projektordner ist nicht erreichbar. Bitte den Ordner im Profil korrigieren.") }
        let executable = try resolveExecutable()
        // Without files: replace this process, preserving terminal, process group, signals and exit status.
        guard !files.isEmpty else {
            withCStrings(arguments, environment) { argv, envp in _ = execve(executable, argv, envp) }
            throw SecretariatError("Das Programm konnte nicht gestartet werden (Systemfehler \(errno)).")
        }
        // With files: write them to a private temporary folder, run the program as a child in the same
        // process group (terminal signals reach it directly), then remove the folder.
        var template = Array((NSTemporaryDirectory() + "secretariat-run-XXXXXX").utf8CString)
        guard let folderPointer = mkdtemp(&template) else { throw SecretariatError("Kein temporärer Ordner für Dateien verfügbar.") }
        let folder = String(cString: folderPointer)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        var environment = environment
        for file in files {
            let path = (folder as NSString).appendingPathComponent((file.name as NSString).lastPathComponent)
            guard FileManager.default.createFile(atPath: path, contents: file.data, attributes: [.posixPermissions: 0o600]) else {
                throw SecretariatError("Die Datei für \(file.variable) konnte nicht bereitgestellt werden.")
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
        guard spawned == 0 else { throw SecretariatError("Das Programm konnte nicht gestartet werden (Systemfehler \(spawned)).") }
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
            throw SecretariatError("Das angegebene Programm wurde im PATH nicht gefunden. Bitte den Befehl prüfen.")
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
    public static let version = "1.2.1"
    public static let help = """
    Secretariat \(version) – vertrauliche Daten für dich und deine Agenten

    Einträge (Pfad organisation/konto/name, Felder: Kennung, Geheimnis, Datei, Nur für mich)
      secretariat items [--expiring TAGE] [--json]
      secretariat item show PFAD [--json]
      secretariat item create PFAD --kind ART [--set FELD=WERT …] [--source TEXT] [--expires JJJJ-MM-TT] [--json]
      secretariat item set PFAD [--set FELD=WERT …] [--unset FELD …] [--source TEXT] [--expires JJJJ-MM-TT] [--json]
      secretariat item rename PFAD NEUER_PFAD [--json]
      secretariat get PFAD/FELD                      Wert einer Kennung (Geheimnisse nie)
      secretariat field move PFAD/FELD PFAD/FELD [--replace] [--json]
      secretariat import DATEI VARIABLE[=PFAD/FELD] … [--profile PROFIL] [--replace] [--json]
      secretariat import-file DATEI PFAD/FELD [--replace] [--json]
      Arten: account, login, api, token, certificate, database, server, note

    Projekte
      secretariat profiles [--json] · describe PROFIL [--json] · check PROFIL [--json]
      secretariat profile create PROFIL --dir ORDNER [--command BEFEHL] [--json]   --dir '*': ohne festen Ordner (Werkzeug-Tokens)
      secretariat profile which [ORDNER]               Profil dieses (oder des umgebenden) Projektordners
      secretariat profile set PROFIL [--dir ORDNER] [--command BEFEHL] [--json]
      secretariat profile bind PROFIL VARIABLE PFAD/FELD [--json] · unbind PROFIL VARIABLE · delete PROFIL
      secretariat run PROFIL -- PROGRAMM [ARGUMENTE …]   Dateifelder kommen als Pfad einer temporären Datei
      secretariat inject VORLAGE --out DATEI            {{ PFAD/FELD }} ersetzen; Ziel nie in Git
      secretariat instructions PROFIL · setup PROFIL [--dry-run] [--json]

    Ziele (Kopien außerhalb der Macs: Worker, Supabase, GitHub, Linux-Hosts)
      secretariat target add NAME --command 'BEFEHL {var}' [--dir ORDNER] [--json]
      secretariat target add NAME --env-file HOST:PFAD [--json]
      secretariat target map NAME VARIABLE PFAD/FELD · unmap NAME VARIABLE · delete NAME
      secretariat targets [--json]                     aktuell / veraltet / nie verteilt
      secretariat push NAME [--dry-run] [--json]

    Übersicht
      secretariat registry export · scan [ORDNER] [--json] · log [--lines N] · --version

    Werte von Geheimnissen gibt die CLI nie aus. Eingeben: App, import oder import-file.
    """

    public static func run(_ arguments: [String], vault: Vault? = nil) throws -> Int32 {
        let vault = vault ?? Vault(paths: AppPaths())
        switch arguments.first {
        case "--help", "-h", "help", nil: print(help); return 0
        case "--version": print("Secretariat \(version)"); return 0
        case "run":
            guard arguments.count >= 4, arguments[2] == "--" else {
                throw SecretariatError("Aufruf: secretariat run PROFIL -- PROGRAMM [ARGUMENTE …]")
            }
            try vault.preparedLaunch(name: arguments[1], arguments: Array(arguments.dropFirst(3)),
                                     inheritedEnvironment: ProcessInfo.processInfo.environment).execute()
        default:
            let executable = Bundle.main.executableURL?.path ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path
            return try Commands.execute(arguments, service: AgentService(vault: vault), executable: executable)
        }
    }
}
