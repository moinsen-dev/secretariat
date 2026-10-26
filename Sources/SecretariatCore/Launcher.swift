import Foundation
import Darwin

public struct PreparedLaunch {
    public let directory: String
    public let arguments: [String]
    public let environment: [String: String]

    // Replacing this process preserves the terminal, process group, signals and exit status.
    public func execute() throws -> Never {
        guard chdir(directory) == 0 else { throw SecretariatError("Der Projektordner ist nicht erreichbar. Bitte den Ordner im Profil korrigieren.") }
        let program = arguments[0]
        let executable: String
        if program.contains("/") {
            executable = URL(fileURLWithPath: program, relativeTo: URL(fileURLWithPath: directory, isDirectory: true)).standardizedFileURL.path
        } else {
            let paths = (environment["PATH"] ?? "/usr/bin:/bin").split(separator: ":", omittingEmptySubsequences: false)
            guard let match = paths.map({ URL(fileURLWithPath: String($0.isEmpty ? "." : $0)).appendingPathComponent(program).path })
                .first(where: { access($0, X_OK) == 0 && !isDirectory($0) }) else {
                throw SecretariatError("Das angegebene Programm wurde im PATH nicht gefunden. Bitte den Befehl prüfen.")
            }
            executable = match
        }
        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.sorted(by: { $0.key < $1.key }).map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in _ = execve(executable, args.baseAddress!, env.baseAddress!) }
        }
        throw SecretariatError("Das Programm konnte nicht gestartet werden (Systemfehler \(errno)).")
    }
    private func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

public enum CommandLineInterface {
    public static let help = """
    Secretariat 0.4 – Schlüssel für deine Projekte

    secretariat run PROFIL -- PROGRAMM [ARGUMENTE …]
    secretariat profiles [--json]
    secretariat describe PROFIL [--json]
    secretariat check PROFIL [--json]
    secretariat instructions PROFIL
    secretariat setup PROFIL [--dry-run] [--json]
    secretariat keys [--json]
    secretariat profile create PROFIL --dir ORDNER [--command BEFEHL] [--json]
    secretariat profile set PROFIL [--dir ORDNER] [--command BEFEHL] [--json]
    secretariat profile bind PROFIL VARIABLE SCHLÜSSELNAME [--json]
    secretariat profile unbind PROFIL VARIABLE [--json]
    secretariat profile delete PROFIL [--json]
    secretariat key rename ALTER_NAME NEUER_NAME [--json]
    secretariat import DATEI VARIABLE[=SCHLÜSSELNAME] … [--profile PROFIL] [--replace] [--json]
    secretariat --version

    Schlüsselwerte verwaltest du in der Secretariat-App oder übernimmst sie per import aus einer .env;
    die CLI gibt nie Werte aus. Profile auch per CLI.
    Der Zielprozess erhält die ausgewählten Werte. Es läuft kein Hintergrunddienst.
    """

    public static func run(_ arguments: [String], vault: Vault? = nil) throws -> Int32 {
        let paths = AppPaths()
        let vault = vault ?? Vault(configuration: ConfigurationStore(paths: paths),
                                   credentials: paths.credentialStore(allowInteraction: false))
        if AgentCommand.handles(arguments.first) {
            return try AgentCommand.execute(arguments, service: AgentService(paths: vault.configuration.paths),
                                            executable: Bundle.main.executableURL?.path ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path)
        }
        switch arguments.first {
        case "--help", "-h", "help": print(help); return 0
        case "--version": print("Secretariat 0.4.1"); return 0
        case "run":
            guard arguments.count >= 4, arguments[2] == "--" else {
                throw SecretariatError("Aufruf: secretariat run PROFIL -- PROGRAMM [ARGUMENTE …]")
            }
            try vault.preparedLaunch(name: arguments[1], arguments: Array(arguments.dropFirst(3)),
                                     inheritedEnvironment: ProcessInfo.processInfo.environment).execute()
        default: throw SecretariatError("Unbekannter Aufruf. Hilfe: secretariat --help")
        }
    }
}
