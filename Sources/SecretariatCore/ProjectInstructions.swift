import Foundation
import Darwin

public struct SetupResult: Encodable, Sendable {
    public let schemaVersion = 1
    public let ok = true
    public let profile: String
    public let directory: String
    public let dryRun: Bool
    public let files: [FileResult]
    public struct FileResult: Encodable, Sendable { public let name: String; public let changed: Bool }
    public init(plan: InstructionPlan, dryRun: Bool) {
        profile = plan.profile; directory = plan.directory.path; self.dryRun = dryRun
        files = plan.files.map { FileResult(name: $0.name, changed: $0.original.data != $0.updated) }
    }
}
public struct InstructionPlan: Sendable {
    public let profile: String
    public let directory: URL
    public let instructions: String
    public var changedFiles: [String] { files.filter { $0.original.data != $0.updated }.map(\.name) }
    fileprivate let device: UInt64
    fileprivate let inode: UInt64
    fileprivate let files: [InstructionFile]
}
private struct FileSnapshot: Equatable, Sendable {
    let data: Data?
    let mode: mode_t
    let device: UInt64
    let inode: UInt64
}
private struct InstructionFile: Sendable {
    let name: String
    let original: FileSnapshot
    let updated: Data
}

public enum ProjectInstructions {
    private static let end = "<!-- secretariat:end -->"
    public static func body(profile: Profile, executable: String) -> String {
        let launcher = shellQuote(executable)
        let name = shellQuote(profile.name)
        return """
        ## Projektbefehle mit Secretariat

        Für Entwicklungsbefehle und Tests, die Projekt-Credentials benötigen, verwende das lokale Profil `\(profile.name)`:

        1. Prüfe die Verfügbarkeit: `\(launcher) check \(name) --json`.
        2. Bei `ok: true` starte den benötigten Projektbefehl durch Secretariat, z. B. `\(launcher) run \(name) -- npm test`. Ersetze `npm test` durch den zum Projekt passenden Befehl.
        3. Bei einem Fehler nenne die fehlende Variable oder den gemeldeten Zugriffsschritt. Schlüsselwerte pflegt der Nutzer in der Secretariat-App.
        4. Braucht das Projekt eine weitere Variable, ordne sie selbst zu: `\(launcher) keys --json` zeigt die vorhandenen Schlüsselnamen, `\(launcher) profile bind \(name) VARIABLE SCHLÜSSELNAME` verbindet sie. Fehlt der Schlüssel ganz, nenne dem Nutzer den Variablennamen; er legt den Wert in der App an.

        Der Projektbefehl erhält die zugeordneten Werte ausschließlich beim Start. Halte Credentialwerte aus Dateien, Chat und Toolausgaben heraus; verwende gezielte Projektbefehle. Führe die Coding-Sitzung mit ihrer normalen Anmeldung aus. Dieser Ablauf setzt den Mac mit installiertem Secretariat voraus; eine Cloud-Umgebung hat keinen direkten Zugriff auf dessen Schlüsselbund.
        """
    }

    public static func preview(profile: Profile, executable: String) throws -> InstructionPlan {
        // Profile slugs are also used inside markers and inline Markdown.
        guard profile.name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$"#, options: .regularExpression) != nil,
              !executable.contains("\n"), !executable.contains("\r"), !executable.contains("`"), executable.hasPrefix("/") else {
            throw AgentError("invalid_instructions", "Profilname oder absoluter Launcherpfad ist für Projektanweisungen ungeeignet.")
        }
        let directory = URL(fileURLWithPath: profile.directory, isDirectory: true).resolvingSymlinksInPath()
        let descriptor = try openDirectory(directory)
        defer { close(descriptor) }
        var info = stat(); guard fstat(descriptor, &info) == 0 else { throw fileError() }
        let instructions = body(profile: profile, executable: executable)
        let begin = "<!-- secretariat:begin profile=\(profile.name) -->"
        let contents = [
            ("AGENTS.md", "\(begin)\n\(instructions)\n\(end)"),
            ("CLAUDE.md", "\(begin)\n@AGENTS.md\n\(end)")
        ]
        let files = try contents.map { name, block in
            let original = try read(name, in: descriptor)
            let updated = try merge(original.data, block: block, begin: begin)
            return InstructionFile(name: name, original: original, updated: updated)
        }
        return InstructionPlan(profile: profile.name, directory: directory, instructions: instructions,
                               device: UInt64(info.st_dev), inode: UInt64(info.st_ino), files: files)
    }

    public static func apply(_ plan: InstructionPlan) throws {
        let descriptor = try openDirectory(plan.directory)
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, UInt64(info.st_dev) == plan.device, UInt64(info.st_ino) == plan.inode else { throw staleError() }
        // Preflight both files before changing either, including the UI preview's snapshots.
        for file in plan.files { guard try read(file.name, in: descriptor) == file.original else { throw staleError() } }
        var committed: [(InstructionFile, FileSnapshot)] = []
        do {
            for file in plan.files where file.original.data != file.updated {
                guard try read(file.name, in: descriptor) == file.original else { throw staleError() }
                let written = try replace(file.name, data: file.updated, mode: file.original.mode, expected: file.original, in: descriptor)
                committed.append((file, written))
            }
        } catch {
            for (file, written) in committed.reversed() {
                do {
                    // Preserve any change made by another editor after our own write.
                    guard try read(file.name, in: descriptor) == written else { throw staleError() }
                    if let original = file.original.data {
                        try replace(file.name, data: original, mode: file.original.mode, expected: written, in: descriptor)
                    } else if unlinkat(descriptor, file.name, 0) != 0 { throw fileError() }
                } catch {
                    throw AgentError("rollback_failed", "Die Einrichtung wurde unterbrochen und konnte nicht vollständig zurückgesetzt werden. Bitte AGENTS.md und CLAUDE.md im Projekt prüfen.")
                }
            }
            throw error
        }
    }

    private static func merge(_ data: Data?, block: String, begin: String) throws -> Data {
        guard let original = data.map({ String(data: $0, encoding: .utf8) }) ?? "" else {
            throw AgentError("instructions_conflict", "Eine Anweisungsdatei ist kein UTF-8. Die Dateien bleiben erhalten.")
        }
        let marker = "<!-- secretariat:"
        if original.contains(marker) {
            guard original.components(separatedBy: marker).count == 3,
                  let start = original.range(of: begin), let finish = original.range(of: end),
                  start.upperBound <= finish.lowerBound,
                  (start.lowerBound == original.startIndex || original[original.index(before: start.lowerBound)] == "\n"),
                  (finish.upperBound == original.endIndex || original[finish.upperBound] == "\n" || original[finish.upperBound] == "\r") else {
                throw AgentError("instructions_conflict", "Eine Anweisungsdatei enthält andere oder beschädigte Secretariat-Marker. Bitte vorhandene Einrichtung prüfen; die Dateien bleiben erhalten.")
            }
            var updated = original
            updated.replaceSubrange(start.lowerBound..<finish.upperBound, with: block)
            return Data(updated.utf8)
        }
        let separator = original.isEmpty ? "" : (original.hasSuffix("\n") ? "\n" : "\n\n")
        return Data((original + separator + block + "\n").utf8)
    }

    private static func openDirectory(_ directory: URL) throws -> Int32 {
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw AgentError("directory_unavailable", "Der Projektordner fehlt oder ist nicht zugänglich.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor); throw AgentError("setup_busy", "Für dieses Projekt läuft bereits eine Einrichtung. Bitte erneut versuchen.")
        }
        return descriptor
    }
    private static func read(_ name: String, in directory: Int32) throws -> FileSnapshot {
        let descriptor = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if descriptor < 0 {
            if errno == ENOENT { return FileSnapshot(data: nil, mode: 0o644, device: 0, inode: 0) }
            throw AgentError("instructions_conflict", "\(name) ist nicht als normale lokale Datei lesbar. Die Dateien bleiben erhalten.")
        }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_nlink == 1, info.st_size <= 1_048_576 else {
            throw AgentError("instructions_conflict", "\(name) muss eine normale Datei ohne weitere Hardlinks und höchstens 1 MiB groß sein. Die Dateien bleiben erhalten.")
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        let data = try handle.readToEnd() ?? Data()
        return FileSnapshot(data: data, mode: info.st_mode & 0o777, device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
    }
    @discardableResult private static func replace(_ name: String, data: Data, mode: mode_t, expected: FileSnapshot, in directory: Int32) throws -> FileSnapshot {
        let temporary = ".secretariat-\(UUID().uuidString).tmp"
        let descriptor = openat(directory, temporary, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw fileError() }
        defer { close(descriptor); _ = unlinkat(directory, temporary, 0) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard fchmod(descriptor, mode) == 0, fsync(descriptor) == 0 else { throw fileError() }
        // Staging can take time. Compare again immediately before committing the rename.
        guard try read(name, in: directory) == expected else { throw staleError() }
        var info = stat(); guard fstat(descriptor, &info) == 0 else { throw fileError() }
        let written = FileSnapshot(data: data, mode: info.st_mode & 0o777, device: UInt64(info.st_dev), inode: UInt64(info.st_ino))
        guard renameat(directory, temporary, directory, name) == 0 else { throw fileError() }
        return written
    }
    private static func fileError() -> AgentError { AgentError("setup_write_failed", "Projektanweisungen konnten nicht gespeichert werden. Bitte Schreibrechte und Dateien prüfen.") }
    private static func staleError() -> AgentError { AgentError("instructions_changed", "Projektanweisungen wurden seit der Vorschau geändert. Bitte Vorschau erneut öffnen.") }
}
