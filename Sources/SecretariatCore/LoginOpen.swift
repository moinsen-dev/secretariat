import ApplicationServices
import Foundation

// Open and sign in: the app opens an item's stored address in the Mac's default browser, waits for the login form and,
// after Touch ID, types the user name and the password into it. The CLI and the MCP server only ask the app to do so,
// so no terminal and no agent ever holds the value. The form is never submitted.

public enum LoginOpen {
    /// The page to open: the address stored with the item (`url`, `website` or `address`), https if it has no scheme.
    /// Nil unless it is an http(s) address with a host (the same rule as `LoginFill.itemHost`).
    public static func address(_ item: ItemMeta) -> URL? {
        for name in ["url", "website", "address"] {
            guard let field = item.field(name), field.kind == .identifier,
                  let value = field.value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { continue }
            let text = value.contains("://") ? value : "https://\(value)"
            if LoginFill.host(text) != nil, let url = URL(string: text) { return url }
        }
        return nil
    }

    /// The address to open, or why this item can't be opened and signed in to.
    public static func check(_ item: ItemMeta) throws -> URL {
        guard LoginFill.fillableField(item) != nil else {
            throw AgentError("not_a_login", "\(item.path) has no field named password, so there is nothing to sign in with.")
        }
        guard let url = address(item) else {
            throw AgentError("no_address", "\(item.path) has no web address. Add one: secretariat item set \(item.path) --set url=https://…")
        }
        return url
    }

    // MARK: Hand-over to the app (CLI and MCP)

    public static let requestName = Notification.Name("dev.moinsen.secretariat.openLogin")
    public static let answerName = Notification.Name("dev.moinsen.secretariat.openLogin.answer")
    public static let bundleIdentifier = "dev.moinsen.secretariat.local"

    /// How the CLI reaches the app; tests replace it.
    nonisolated(unsafe) public static var send: (_ path: String, _ origin: String) throws -> Void = { try request(path: $0, via: $1) }

    /// Asks the running app (started in the background if needed) to open the item and sign in. Returns once the app has
    /// taken the request; the sign-in itself waits for the page and Touch ID. Throws when the app doesn't answer.
    public static func request(path: String, via origin: String, timeout: TimeInterval = 20) throws {
        let id = UUID().uuidString
        let center = DistributedNotificationCenter.default()
        final class Box: @unchecked Sendable { var answer: [String: String]? }
        let box = Box()
        let observer = center.addObserver(forName: answerName, object: id, queue: nil) { note in
            box.answer = note.userInfo as? [String: String] ?? [:]
        }
        defer { center.removeObserver(observer) }
        let start = Date(), deadline = start.addingTimeInterval(timeout)
        var launched = false, nextPost = Date()
        while box.answer == nil, Date() < deadline {
            if Date() >= nextPost {
                center.postNotificationName(requestName, object: id, userInfo: ["path": path, "via": origin], deliverImmediately: true)
                nextPost = Date().addingTimeInterval(1)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            // No answer within two seconds: the app is probably not running.
            if !launched, Date().timeIntervalSince(start) > 2 {
                launched = true
                let open = Process()
                open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                open.arguments = ["-g", "-b", bundleIdentifier]
                try? open.run()
                open.waitUntilExit()
            }
        }
        guard let answer = box.answer else {
            throw AgentError("app_not_reachable", "The Secretariat app didn't answer. Open it and try again.")
        }
        if let error = answer["error"] { throw AgentError("open_failed", error) }
    }

    /// The app's reply to a request.
    public static func answer(request id: String, error: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(answerName, object: id, userInfo: error.map { ["error": $0] } ?? [:],
                                                                     deliverImmediately: true)
    }
}

extension FocusedPage {
    /// The login form of a page in an app: the page's address, its first password field and the text field before it.
    public struct LoginForm {
        public let url: URL
        public let user: AXUIElement?
        public let password: AXUIElement
    }

    /// A page with this host in one of the app's windows (focused window first) that shows a password field.
    public static func loginForm(pid: pid_t, host: String) -> LoginForm? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var windows = (value(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        if let focused = element(app, kAXFocusedWindowAttribute) { windows.insert(focused, at: 0) }
        for window in windows {
            for area in webAreas(in: window) where LoginFill.host(area.url.absoluteString) == host {
                if let form = form(in: area.element, url: area.url) { return form }
            }
        }
        return nil
    }

    /// Whether one of the app's windows shows a page of this host.
    public static func hasPage(pid: pid_t, host: String) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        let windows = (value(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        return windows.contains { webAreas(in: $0).contains { LoginFill.host($0.url.absoluteString) == host } }
    }

    /// Web areas with an http(s) address below an element (bounded walk; frames inside a page count as their own).
    static func webAreas(in root: AXUIElement) -> [(element: AXUIElement, url: URL)] {
        var found: [(AXUIElement, URL)] = []
        var stack = [root], visited = 0
        while let element = stack.popLast(), visited < 20_000 {
            visited += 1
            if string(element, kAXRoleAttribute) == "AXWebArea", let url = value(element, "AXURL") as? URL,
               url.scheme == "http" || url.scheme == "https" {
                found.append((element, url))
            }
            if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
        }
        return found
    }

    /// The first password field of a page and the last visible text field before it (the user name), in document order.
    static func form(in area: AXUIElement, url: URL) -> LoginForm? {
        var stack = [area], visited = 0
        var lastText: AXUIElement?
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            let role = string(element, kAXRoleAttribute)
            if role == "AXTextField" || role == "AXComboBox" {
                if isSecure(element) { return LoginForm(url: url, user: lastText, password: element) }
                if value(element, kAXEnabledAttribute) as? Bool != false { lastText = element }
            }
            if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
        }
        return nil
    }

    /// Moves the keyboard focus of the page to this field.
    @discardableResult
    public static func focus(_ field: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }

    /// Whether this exact field has the keyboard focus of the app.
    public static func hasFocus(_ field: AXUIElement, pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        if let focused = element(app, kAXFocusedUIElementAttribute), CFEqual(focused, field) { return true }
        return value(field, kAXFocusedAttribute) as? Bool == true
    }

    /// Text of a (non-password) field; nil for password fields.
    public static func text(of field: AXUIElement) -> String? {
        isSecure(field) ? nil : (string(field, kAXValueAttribute) ?? "")
    }

    /// Empties the focused text field (⌘→, ⌘⌫, then single ⌫), true when it is verifiably empty.
    public static func clearTextField(_ field: AXUIElement, pid: pid_t) -> Bool {
        guard var count = text(of: field)?.count else { return false }
        guard count > 0 else { return true }
        Keystrokes.press(0x7C, flags: .maskCommand, to: pid)
        Keystrokes.press(0x33, flags: .maskCommand, to: pid)
        Thread.sleep(forTimeInterval: 0.08)
        count = text(of: field)?.count ?? -1
        if count > 0 {
            for _ in 0..<min(count, 256) { Keystrokes.press(0x33, flags: [], to: pid) }
            Thread.sleep(forTimeInterval: 0.08)
            count = text(of: field)?.count ?? -1
        }
        return count == 0
    }
}
