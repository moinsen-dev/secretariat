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
        ## Project commands with Secretariat

        For development commands and tests that need project credentials, use the local profile `\(profile.name)`:

        1. Check availability: `\(launcher) check \(name) --json`.
        2. If `ok: true`, start the project command you need through Secretariat, e.g. `\(launcher) run \(name) -- npm test`. Replace `npm test` with the command that fits the project.
        3. On an error, name the missing variable or the reported access step. The user manages key values in the Secretariat app.
        4. If the project needs another variable, bind it yourself: `\(launcher) items --json` lists items and fields (never values), `\(launcher) profile bind \(name) VARIABLE PATH/FIELD` binds it. If the value is already in a `.env`, import it with `\(launcher) import FILE VARIABLE=PATH/FIELD`. If it is missing entirely, tell the user the variable and path; they add the value in the app.
        5. Read identifiers (team ID, account ID, bundle ID) with `\(launcher) get PATH/FIELD` instead of asking the user.

        The project command receives the bound values only at launch. Keep credential values out of files, chat and tool output; use targeted project commands. Run the coding session with its normal sign-in. This flow requires the Mac with Secretariat installed; a cloud environment has no direct access to its keychain.
        """
    }

    public static func preview(profile: Profile, executable: String) throws -> InstructionPlan {
        guard !profile.isAnywhere else { throw AgentError("no_project", "Profiles without a fixed folder have no project instructions.") }
        // Profile slugs are also used inside markers and inline Markdown.
        guard profile.name.range(of: #"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$"#, options: .regularExpression) != nil,
              !executable.contains("\n"), !executable.contains("\r"), !executable.contains("`"), executable.hasPrefix("/") else {
            throw AgentError("invalid_instructions", "The profile name or absolute launcher path is not suitable for project instructions.")
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
                    throw AgentError("rollback_failed", "Setup was interrupted and could not be fully rolled back. Please check AGENTS.md and CLAUDE.md in the project.")
                }
            }
            throw error
        }
    }

    private static func merge(_ data: Data?, block: String, begin: String) throws -> Data {
        guard let original = data.map({ String(data: $0, encoding: .utf8) }) ?? "" else {
            throw AgentError("instructions_conflict", "An instructions file is not UTF-8. The files are kept.")
        }
        let marker = "<!-- secretariat:"
        if original.contains(marker) {
            guard original.components(separatedBy: marker).count == 3,
                  let start = original.range(of: begin), let finish = original.range(of: end),
                  start.upperBound <= finish.lowerBound,
                  (start.lowerBound == original.startIndex || original[original.index(before: start.lowerBound)] == "\n"),
                  (finish.upperBound == original.endIndex || original[finish.upperBound] == "\n" || original[finish.upperBound] == "\r") else {
                throw AgentError("instructions_conflict", "An instructions file contains other or damaged Secretariat markers. Please check the existing setup; the files are kept.")
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
        guard descriptor >= 0 else { throw AgentError("directory_unavailable", "The project folder is missing or not accessible.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor); throw AgentError("setup_busy", "A setup is already running for this project. Please try again.")
        }
        return descriptor
    }
    private static func read(_ name: String, in directory: Int32) throws -> FileSnapshot {
        let descriptor = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        if descriptor < 0 {
            if errno == ENOENT { return FileSnapshot(data: nil, mode: 0o644, device: 0, inode: 0) }
            throw AgentError("instructions_conflict", "\(name) can't be read as a regular local file. The files are kept.")
        }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_nlink == 1, info.st_size <= 1_048_576 else {
            throw AgentError("instructions_conflict", "\(name) must be a regular file without other hard links and at most 1 MiB. The files are kept.")
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
    private static func fileError() -> AgentError { AgentError("setup_write_failed", "Project instructions could not be saved. Please check write permissions and files.") }
    private static func staleError() -> AgentError { AgentError("instructions_changed", "Project instructions changed since the preview. Please open the preview again.") }
}
