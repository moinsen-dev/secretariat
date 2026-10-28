import Foundation
import LocalAuthentication

// Agent Guard: three walls between secret values and an agent's context.
//   1. Output masking — `run` replaces known values in the program's stdout/stderr when nobody watches a terminal.
//   2. Approval — items marked for approval need Touch ID (or the Mac password) before a program gets them.
//   3. Git guard — a pre-commit hook refuses commits that contain a value Secretariat knows.

/// Replaces secret values in a byte stream. Values can arrive split across reads, so the tail that could still
/// grow into a value is held back until the next chunk (or the end).
public struct StreamMasker {
    public struct Secret: Sendable { public let value: Data; public let label: String
        public init(value: Data, label: String) { self.value = value; self.label = label } }
    public static let minimumLength = 6
    let secrets: [Secret]
    let keep: Int
    var buffer = Data()

    public init(_ secrets: [Secret]) {
        self.secrets = secrets.filter { $0.value.count >= Self.minimumLength }.sorted { $0.value.count > $1.value.count }
        keep = max((self.secrets.map(\.value.count).max() ?? 1) - 1, 0)
    }
    public var isEmpty: Bool { secrets.isEmpty }

    public mutating func feed(_ chunk: Data) -> Data {
        buffer.append(chunk)
        replaceAll()
        guard buffer.count > keep else { return Data() }
        let out = buffer.prefix(buffer.count - keep)
        buffer = Data(buffer.suffix(keep))
        return Data(out)
    }
    public mutating func finish() -> Data {
        replaceAll()
        defer { buffer = Data() }
        return buffer
    }
    private mutating func replaceAll() {
        for secret in secrets {
            let replacement = Data("[masked \(secret.label)]".utf8)
            var start = buffer.startIndex
            while let range = buffer.range(of: secret.value, in: start..<buffer.endIndex) {
                buffer.replaceSubrange(range, with: replacement)
                start = range.lowerBound + replacement.count
            }
        }
    }
}

/// Confirms access to approval items. The real one asks Touch ID / the Mac password on this Mac's screen.
public protocol Approver: Sendable {
    func approve(_ reason: String) throws
}
public struct DeviceOwnerApprover: Approver {
    public init() {}
    public func approve(_ reason: String) throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw AgentError("approval_unavailable", "This item needs Uli's approval (Touch ID or Mac password), but no prompt can be shown here (\(error?.localizedDescription ?? "no session")). Run it on the Mac's screen.")
        }
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var granted = false
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in granted = ok; done.signal() }
        done.wait()
        guard granted else { throw AgentError("approval_denied", "Uli did not approve: \(reason)") }
    }
}
/// Tests and the CLI's dry runs.
public struct FixedApprover: Approver {
    public let allow: Bool
    public init(allow: Bool) { self.allow = allow }
    public func approve(_ reason: String) throws { if !allow { throw AgentError("approval_denied", "Uli did not approve: \(reason)") } }
}

public enum GitGuard {
    public struct Finding: Encodable, Sendable { public let file: String; public let line: Int; public let reference: String }
    public static let marker = "# secretariat-guard"
    public static let minimumLength = 8

    /// Known values worth guarding: every secret and personal text field (files are binary blobs).
    public static func secrets(_ vault: Vault) -> [(String, String)] {
        var out: [(String, String)] = []
        for item in (try? vault.list()) ?? [] {
            guard let values = try? vault.items.secrets(id: item.id) else { continue }
            for field in item.fields where field.kind == .secret || field.kind == .personal {
                if let v = values[field.name], v.count >= minimumLength { out.append((v, "\(item.path)/\(field.name)")) }
            }
        }
        return out
    }

    /// Added lines of a unified diff (`git diff --cached -U0`) that contain a known value.
    public static func scan(diff: String, secrets: [(String, String)]) -> [Finding] {
        var findings: [Finding] = []
        var file = "", line = 0
        for raw in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            if raw.hasPrefix("+++ ") { file = raw.hasPrefix("+++ b/") ? String(raw.dropFirst(6)) : String(raw.dropFirst(4)); continue }
            if raw.hasPrefix("@@"), let plus = raw.split(separator: " ").first(where: { $0.hasPrefix("+") }) {
                line = Int(plus.dropFirst().split(separator: ",").first ?? "0") ?? 0; continue
            }
            if raw.hasPrefix("+") && !raw.hasPrefix("+++") {
                for (value, reference) in secrets where raw.contains(value) {
                    findings.append(Finding(file: file, line: line, reference: reference))
                }
                line += 1
            }
        }
        return findings
    }

    static func git(_ args: [String], in dir: String) -> (Int32, String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/git"); p.arguments = ["-C", dir] + args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return (127, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    public static func stagedDiff(in dir: String) -> String {
        git(["diff", "--cached", "--no-color", "--no-ext-diff", "-U0", "--diff-filter=ACMR"], in: dir).1
    }

    /// Adds (or removes) the guard line in the repository's pre-commit hook; existing hooks are kept.
    public static func install(in dir: String, executable: String, remove: Bool = false) throws -> String {
        let (code, hooks) = git(["rev-parse", "--git-path", "hooks"], in: dir)
        guard code == 0 else { throw AgentError("not_a_repository", "\(dir) is not a git repository.") }
        var hooksDir = hooks.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hooksDir.hasPrefix("/") { hooksDir = (dir as NSString).appendingPathComponent(hooksDir) }
        let hook = (hooksDir as NSString).appendingPathComponent("pre-commit")
        var text = (try? String(contentsOfFile: hook, encoding: .utf8)) ?? ""
        let line = "\(shellQuote(executable)) guard check || exit 1 \(marker)"
        let had = text.contains(marker)
        if remove {
            guard had else { return "not installed" }
            text = text.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.contains(marker) }.joined(separator: "\n")
        } else {
            guard !had else { return "already installed" }
            if text.isEmpty { text = "#!/bin/sh\n" }
            if !text.hasSuffix("\n") { text += "\n" }
            text += line + "\n"
        }
        try FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
        try text.write(toFile: hook, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook)
        return remove ? "removed" : "installed"
    }
}
