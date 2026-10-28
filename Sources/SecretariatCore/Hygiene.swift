import Foundation

// Three cleanups around the vault: find keys that already leaked into git (sweep), stop agents from
// reading them on the way in (Claude Code hook), and retire .env files whose values Secretariat holds (tidy).

// MARK: - Sweep: known values in repositories and their history

public enum Sweep {
    public struct Finding: Encodable, Sendable, Equatable {
        public let repository: String
        public let file: String
        public let reference: String
        /// Still in the checked-out files (not only in history).
        public let current: Bool
        /// Oldest commit that added the value (history scans only).
        public let commit: String?
    }

    /// Git repositories under `root` (the folder itself counts when it is one).
    public static func repositories(under root: String) -> [String] {
        let finder = Process(); finder.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        finder.arguments = [root, "-maxdepth", "6", "-name", ".git", "-not", "-path", "*/node_modules/*", "-prune"]
        let pipe = Pipe(); finder.standardOutput = pipe; finder.standardError = FileHandle.nullDevice
        guard (try? finder.run()) != nil else { return [] }
        let out = pipe.fileHandleForReading.readDataToEndOfFile(); finder.waitUntilExit()
        return String(decoding: out, as: UTF8.self).split(separator: "\n").map { ($0 as NSString).deletingLastPathComponent }.sorted()
    }

    /// Checks every repository for the given values: the current files (`git grep`) and, with `history`,
    /// every added line of every commit on every branch. Values never touch the disk: `git grep` reads
    /// them on stdin, history is matched in memory.
    public static func run(repositories: [String], secrets: [(String, String)], history: Bool) throws -> [Finding] {
        guard !secrets.isEmpty, !repositories.isEmpty else { return [] }
        let patterns = Data(secrets.map(\.0).joined(separator: "\n").utf8)
        let matcher = Matcher(secrets.map(\.0))

        let lock = NSLock()
        var findings: [Finding] = []
        DispatchQueue.concurrentPerform(iterations: repositories.count) { index in
            let repo = repositories[index]
            var local: [Finding] = []
            var seen = Set<String>()
            let shown = repo.replacingOccurrences(of: NSHomeDirectory(), with: "~")
            // Current files: "path:content" lines.
            for line in pipeline(["/usr/bin/git", "-C", repo, "grep", "-F", "-I", "--no-color", "--full-name", "-f", "-"], input: patterns) {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let file = String(line[..<colon])
                for (value, reference) in secrets where line[colon...].contains(value) && seen.insert("\(file)|\(reference)").inserted {
                    local.append(Finding(repository: shown, file: file, reference: reference, current: true, commit: nil))
                }
            }
            // History in two stages: one cheap pass over every object in the repository (no diffs), and the
            // commit-by-commit diff only where that pass found a value — most repositories never get there.
            guard history, stream(["/usr/bin/git", "-C", repo, "cat-file", "--batch-all-objects", "--batch", "--unordered"],
                                  until: { matcher.contains($0) }) else {
                lock.lock(); findings += local; lock.unlock(); return
            }
            var commit = "", file = ""
            var oldest: [String: Finding] = [:]
            let log = ["/usr/bin/git", "-C", repo, "log", "--all", "-p", "-U0", "--no-color", "--no-ext-diff", "--no-textconv", "--format=commit %H"]
            _ = stream(log, lines: true) { chunk in
                for raw in chunk.split(separator: UInt8(ascii: "\n")) {
                    if raw.starts(with: commitPrefix), raw.count == 47 { commit = String(decoding: raw.dropFirst(7).prefix(10), as: UTF8.self); continue }
                    if raw.starts(with: filePrefix) {
                        file = String(decoding: raw.dropFirst(raw.starts(with: newFilePrefix) ? 6 : 4), as: UTF8.self); continue
                    }
                    guard raw.first == UInt8(ascii: "+"), matcher.contains(raw) else { continue }
                    let line = String(decoding: raw, as: UTF8.self)
                    for (value, reference) in secrets where line.contains(value) {
                        // git log runs newest first: the last hit is the commit that introduced the value.
                        let key = "\(file)|\(reference)"
                        oldest[key] = Finding(repository: shown, file: file, reference: reference, current: seen.contains(key), commit: commit)
                    }
                }
                return false
            }
            for (key, finding) in oldest {
                if let i = local.firstIndex(where: { "\($0.file)|\($0.reference)" == key }) { local[i] = finding } else { local.append(finding) }
            }
            lock.lock(); findings += local; lock.unlock()
        }
        return findings.sorted { ($0.repository, $0.file, $0.reference) < ($1.repository, $1.file, $1.reference) }
    }

    static let commitPrefix = Array("commit ".utf8), filePrefix = Array("+++ ".utf8), newFilePrefix = Array("+++ b/".utf8)

    /// Runs `command` with `input` on stdin and returns the output lines.
    static func pipeline(_ command: [String], input: Data) -> [String] {
        var data = Data()
        stream(command, input: input, lines: true) { data.append(contentsOf: $0); data.append(UInt8(ascii: "\n")); return false }
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// Feeds the command's output to `until` in chunks (whole lines with `lines`, otherwise overlapping by
    /// `Matcher.overlap` so no value is cut in half). Returns true and stops the command once `until` does.
    @discardableResult
    static func stream(_ command: [String], input: Data? = nil, lines: Bool = false, until: ([UInt8]) -> Bool) -> Bool {
        let process = Process(); process.executableURL = URL(fileURLWithPath: command[0]); process.arguments = Array(command.dropFirst())
        process.standardError = FileHandle.nullDevice
        let out = Pipe(); process.standardOutput = out
        let stdin = input.map { _ in Pipe() }
        process.standardInput = stdin ?? FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        if let stdin, let input {
            // Written from another thread: a pattern list larger than the pipe buffer would block otherwise.
            Thread.detachNewThread { try? stdin.fileHandleForWriting.write(contentsOf: input); try? stdin.fileHandleForWriting.close() }
        }
        let handle = out.fileHandleForReading
        var carry: [UInt8] = []
        var hit = false
        while true {
            let data = handle.readData(ofLength: 1 << 20)
            if data.isEmpty { if !carry.isEmpty { hit = until(carry) }; break }
            var buffer = carry; buffer.append(contentsOf: data)
            if lines {
                guard let cut = buffer.lastIndex(of: UInt8(ascii: "\n")) else { carry = buffer; continue }
                carry = Array(buffer[(cut + 1)...]); buffer.removeSubrange((cut + 1)...)
            } else {
                carry = Array(buffer.suffix(Matcher.overlap))
            }
            if until(buffer) { hit = true; break }
        }
        if process.isRunning { process.terminate() }
        try? handle.close()
        process.waitUntilExit()
        return hit
    }
}

/// Multi-value substring search for gigabytes of git objects: a table of two-byte starts rules out almost
/// every position, a hashed bitmap of four-byte starts most of the rest, and only then are whole values compared.
struct Matcher: Sendable {
    /// Bytes kept between chunks: longer values are only found when they don't straddle a chunk border,
    /// and secrets are far shorter than this.
    static let overlap = 4096
    private static let headBits = 22
    private let two: [UInt8]
    private let fours: [UInt64]
    private let heads: [UInt32: [[UInt8]]]

    init(_ values: [String]) {
        var two = [UInt8](repeating: 0, count: 1 << 16)
        var fours = [UInt64](repeating: 0, count: (1 << Self.headBits) / 64)
        var heads: [UInt32: [[UInt8]]] = [:]
        for value in Set(values) {
            let b = Array(value.utf8)
            guard b.count >= 4 else { continue }
            two[Int(b[0]) << 8 | Int(b[1])] = 1
            let head = UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
            let slot = Self.slot(head)
            fours[slot >> 6] |= 1 << UInt64(slot & 63)
            heads[head, default: []].append(b)
        }
        self.two = two; self.fours = fours; self.heads = heads
    }

    @inline(__always) private static func slot(_ head: UInt32) -> Int { Int((head &* 2_654_435_761) >> UInt32(32 - headBits)) }

    func contains(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBufferPointer { contains($0) }
    }
    func contains(_ bytes: ArraySlice<UInt8>) -> Bool {
        bytes.withUnsafeBufferPointer { contains($0) }
    }

    func contains(_ b: UnsafeBufferPointer<UInt8>) -> Bool {
        guard !heads.isEmpty, b.count >= 4, let p = b.baseAddress else { return false }
        return two.withUnsafeBufferPointer { two in
            fours.withUnsafeBufferPointer { fours in
                var i = 0
                let last = b.count - 4
                while i <= last {
                    if two[Int(p[i]) << 8 | Int(p[i + 1])] != 0 {
                        let head = UInt32(p[i]) << 24 | UInt32(p[i + 1]) << 16 | UInt32(p[i + 2]) << 8 | UInt32(p[i + 3])
                        let slot = Self.slot(head)
                        if fours[slot >> 6] & (1 << UInt64(slot & 63)) != 0, let candidates = heads[head] {
                            for value in candidates where i + value.count <= b.count && memcmp(p + i, value, value.count) == 0 { return true }
                        }
                    }
                    i += 1
                }
                return false
            }
        }
    }
}

// MARK: - Claude Code hook: stop reads of secrets before they run

public enum AgentHook {
    public static let marker = "guard claude-hook"

    static let envFile = #"(^|[\s/'"=])\.env(\.(?!example\b|sample\b|template\b|dist\b)[\w.-]+)?(?=$|[\s'";|&)>])"#
    static let rules: [(String, String)] = [
        (#"\b(cat|less|more|head|tail|bat|nl|strings|xxd|od|hexdump|grep|egrep|rg|ag|awk|sed|cut|sort|uniq|diff|cp|mv|scp|source|base64|open)\b[^|;&]*"# + envFile,
         "reads a .env file"),
        (#"(^|[|;&]\s*|\$\(\s*|`\s*)(env|printenv|export\s+-p|set)\s*($|[|;&>)`])"#, "prints the environment"),
        (#"\bprintenv\b"#, "prints the environment"),
        (#"\bdocker(-|\s+)compose\b[^|;&]*\bconfig\b"#, "prints the compose file with resolved secrets"),
        (#"\bsecurity\s+find-(generic|internet)-password\b[^|;&]*\s-[wg]\b"#, "reads a password from the keychain"),
        (#"\bsecretariat\s+run\b[^|;&]*--no-mask"#, "switches off output masking"),
        (#"/proc/\d+/environ|\bps\s+[^|;&]*e[wW]*\b.*\benv"#, "reads another process's environment"),
    ]

    /// Why this tool call would expose a secret, or nil when it may run.
    public static func refusal(tool: String, input: [String: Any]) -> String? {
        switch tool {
        case "Bash":
            guard let command = input["command"] as? String else { return nil }
            for (pattern, reason) in rules where command.range(of: pattern, options: .regularExpression) != nil { return reason }
            return nil
        case "Read", "Grep", "Edit", "Write", "NotebookRead":
            for key in ["file_path", "path", "notebook_path"] {
                if let path = input[key] as? String, (" " + path).range(of: envFile, options: .regularExpression) != nil { return "opens a .env file" }
            }
            if let glob = input["glob"] as? String, glob.contains(".env") && !glob.contains("example") { return "searches .env files" }
            return nil
        default: return nil
        }
    }

    /// PreToolUse hook body: JSON in, a deny decision out (or nothing).
    public static func handle(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = json["tool_name"] as? String, let input = json["tool_input"] as? [String: Any],
              let reason = refusal(tool: tool, input: input) else { return nil }
        let message = "Secretariat agent guard: this \(reason), and that would put secret values into the conversation. "
            + "Run the program through its profile instead (`secretariat profile which`, then `secretariat run PROFILE -- …`); "
            + "check availability with `secretariat check PROFILE`. Names and identifiers: `secretariat describe PROFILE`, `secretariat get PATH/FIELD`."
        let out: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": message]]
        return (try? JSONSerialization.data(withJSONObject: out)).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Adds (or removes) the hook in a Claude Code settings file; other settings stay as they are.
    public static func install(settings path: String, executable: String, remove: Bool) throws -> String {
        var root: [String: Any] = [:]
        if let data = FileManager.default.contents(atPath: path), !data.isEmpty {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AgentError("invalid_settings", "\(path) is not a JSON object; left unchanged.")
            }
            root = parsed
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var pre = hooks["PreToolUse"] as? [[String: Any]] ?? []
        let ours: ([String: Any]) -> Bool = { entry in
            (entry["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
        }
        let had = pre.contains(where: ours)
        if remove {
            guard had else { return "not installed" }
            pre.removeAll(where: ours)
        } else {
            guard !had else { return "already installed" }
            pre.append(["matcher": "Bash|Read|Grep|Edit|Write",
                        "hooks": [["type": "command", "command": "\(shellQuote(executable)) \(marker)"]]])
        }
        hooks["PreToolUse"] = pre.isEmpty ? nil : pre
        root["hooks"] = hooks.isEmpty ? nil : hooks
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        return remove ? "removed" : "installed"
    }
}

// MARK: - Tidy: retire .env files whose values all live in Secretariat

public enum Tidy {
    public struct Entry: Encodable, Sendable {
        public let file: String
        /// trash · trashed · keep
        public let action: String
        public let reason: String
        public let profile: String?
    }

    /// A .env file goes to the Trash only when every value in it is stored in Secretariat and git doesn't track it.
    /// A `.env.example` with the variable names is written next to it unless one exists.
    static func run(root: URL, vault: Vault, apply: Bool) throws -> [Entry] {
        let profiles = try vault.configuration.load().profiles
        return try Scan.run(root: root, vault: vault).map { finding in
            let path = finding.path, folder = (path as NSString).deletingLastPathComponent
            let profile = profiles.filter { $0.directory != Profile.anywhere && (folder == $0.directory || folder.hasPrefix($0.directory + "/")) }
                .max { $0.directory.count < $1.directory.count }?.name
            let missing = finding.variables.filter { $0.storedAs == nil }.map(\.name)
            if !missing.isEmpty {
                return Entry(file: finding.file, action: "keep", reason: "not in Secretariat yet: \(missing.joined(separator: ", ")) – import first", profile: profile)
            }
            if GitGuard.git(["ls-files", "--error-unmatch", (path as NSString).lastPathComponent], in: folder).0 == 0 {
                return Entry(file: finding.file, action: "keep", reason: "tracked by git – remove it from the repository and rotate (secretariat sweep)", profile: profile)
            }
            guard apply else { return Entry(file: finding.file, action: "trash", reason: "every value is in Secretariat", profile: profile) }
            let example = (folder as NSString).appendingPathComponent(".env.example")
            if !FileManager.default.fileExists(atPath: example) {
                let names = finding.variables.map { "\($0.name)=" }.joined(separator: "\n") + "\n"
                try ("# Values come from Secretariat: secretariat run \(profile ?? "PROFILE") -- …\n" + names).write(toFile: example, atomically: true, encoding: .utf8)
            }
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            vault.audit.record("tidy", ["file": finding.file])
            return Entry(file: finding.file, action: "trashed", reason: "every value is in Secretariat; .env.example keeps the names", profile: profile)
        }
    }
}
