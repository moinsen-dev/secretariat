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

    /// Where a login opened from a stored address may be typed.
    public enum Destination: Equatable, Sendable {
        /// The stored host itself, with its scheme (or https) and port.
        case sameHost
        /// Another host of the same site (`login.example.com` for `app.example.com`), on the front page.
        case sameSite
        /// Another site on the front page, where the browser was sent after opening (single sign-on).
        case redirect
    }

    /// Whether the login stored for `item` may be typed into `page`. The stored host counts in any window (same port, same
    /// scheme or https). Any other host only counts as the browser's front page, over https (plain http only for a local
    /// item on this Mac), and Touch ID names it before anything is typed there.
    public static func destination(item: URL, page: URL, isFrontPage: Bool) -> Destination? {
        guard let itemHost = LoginFill.host(item.absoluteString), let pageHost = LoginFill.host(page.absoluteString) else { return nil }
        let itemScheme = item.scheme?.lowercased(), pageScheme = page.scheme?.lowercased()
        if pageHost == itemHost, pageScheme == itemScheme || pageScheme == "https",
           page.port == item.port || (pageScheme != itemScheme && item.port == nil) { return .sameHost }
        guard isFrontPage, pageScheme == "https" || (isLoopback(pageHost) && isLoopback(itemHost)) else { return nil }
        let isAddress = { (host: String) in host.split(separator: ":").first.map { $0.allSatisfy { $0.isNumber || $0 == "." } } ?? false }
        if !LoginFill.isSharedHosting(itemHost), !LoginFill.isSharedHosting(pageHost), !isAddress(itemHost), !isAddress(pageHost),
           !isLoopback(pageHost), LoginFill.site(pageHost) == LoginFill.site(itemHost) { return .sameSite }
        return .redirect
    }

    static func isLoopback(_ host: String) -> Bool {
        let name = host.split(separator: ":").first.map(String.init) ?? host
        return name == "localhost" || name == "127.0.0.1"
    }

    /// Whether a text field asks for the user name, judged by its id, placeholder, label and help text: the first step of a
    /// sign-in that asks for the password on the next page. Search and newsletter fields don't count.
    public static func asksForUsername(_ labels: [String]) -> Bool {
        let text = labels.joined(separator: " ").lowercased()
        if ["search", "such", "newsletter", "subscribe", "abonn", "coupon", "gutschein", "promo"].contains(where: text.contains) { return false }
        return ["user", "mail", "login", "log in", "sign in", "signin", "account", "identifier", "benutzer", "anmelde", "konto", "kennung"]
            .contains(where: text.contains)
    }

    // MARK: Hand-over to the app (CLI and MCP)

    public static let requestName = Notification.Name("dev.moinsen.secretariat.openLogin")
    public static let answerName = Notification.Name("dev.moinsen.secretariat.openLogin.answer")
    public static let bundleIdentifier = "dev.moinsen.secretariat.local"

    /// How the CLI reaches the app; tests replace it.
    nonisolated(unsafe) public static var send: (_ path: String, _ origin: String) throws -> Void = { try request(path: $0, via: $1) }

    /// Asks the running app (started in the background if needed) to open the item and sign in. Returns once the app has
    /// taken the request; the sign-in itself waits for the page and Touch ID. Throws when the app doesn't answer.
    /// The vault a request is meant for. The app ignores requests for another vault, so a CLI running on a test vault
    /// (`SECRETARIAT_HOME`) never drives the app on the real one, and the other way round.
    public static func vault(_ paths: AppPaths = AppPaths()) -> String {
        AppPaths.canonical(paths.directory.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    /// Whether a request names this vault.
    public static func isForThisVault(_ info: [String: String], paths: AppPaths = AppPaths()) -> Bool { info["vault"] == vault(paths) }

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
                center.postNotificationName(requestName, object: id, userInfo: ["path": path, "via": origin, "vault": vault()],
                                         deliverImmediately: true)
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
    /// The login form of a page in an app: the page's address, the user name field and the password field. Without a
    /// password field it is the first step of a two-step sign-in, which asks only for the user name.
    public struct LoginForm {
        public let url: URL
        public let user: AXUIElement?
        public let password: AXUIElement?
        public let destination: LoginOpen.Destination
        public var host: String { LoginFill.host(url.absoluteString) ?? "" }
    }

    /// The login form for the stored address in one of the app's windows (focused window first): a page with a password
    /// field wins over a page that only asks for the user name. `needsPassword` skips the user-name-only step;
    /// `frontOnly` looks only at the browser's front page.
    public static func loginForm(pid: pid_t, item: URL, needsPassword: Bool = false, frontOnly: Bool = false) -> LoginForm? {
        var usernameStep: LoginForm?
        for page in pages(pid: pid, item: item, frontOnly: frontOnly) {
            guard let form = form(in: page.element, url: page.url, destination: page.destination) else { continue }
            if form.password != nil { return form }
            if !needsPassword, usernameStep == nil { usernameStep = form }
        }
        return usernameStep
    }

    /// Whether one of the app's windows shows a page where this login may be typed.
    public static func hasPage(pid: pid_t, item: URL) -> Bool { !pages(pid: pid, item: item).isEmpty }

    /// Pages of the app where the stored login may go, focused window first. The front page is the top web area of the
    /// focused window; frames inside it and pages in other windows only count for the stored host.
    static func pages(pid: pid_t, item: URL, frontOnly: Bool = false) -> [(element: AXUIElement, url: URL, destination: LoginOpen.Destination)] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        let focused = element(app, kAXFocusedWindowAttribute)
        var windows = (value(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        if let focused { windows.removeAll { CFEqual($0, focused) }; windows.insert(focused, at: 0) }
        var found: [(AXUIElement, URL, LoginOpen.Destination)] = []
        for (index, window) in windows.enumerated() {
            for (position, area) in webAreas(in: window).enumerated() {
                let front = focused != nil && index == 0 && position == 0
                if frontOnly, !front { continue }
                if let destination = LoginOpen.destination(item: item, page: area.url, isFrontPage: front) {
                    found.append((area.element, area.url, destination))
                }
            }
        }
        return found
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

    /// The first password field of a page and the last enabled text field before it (the user name), in document order.
    /// Without a password field, the first text field that asks for the user name.
    static func form(in area: AXUIElement, url: URL, destination: LoginOpen.Destination) -> LoginForm? {
        var stack = [area], visited = 0
        var lastText: AXUIElement?, usernameField: AXUIElement?
        while let element = stack.popLast(), visited < 5000 {
            visited += 1
            let role = string(element, kAXRoleAttribute)
            if role == "AXTextField" || role == "AXComboBox" {
                if isSecure(element) { return LoginForm(url: url, user: lastText, password: element, destination: destination) }
                if value(element, kAXEnabledAttribute) as? Bool != false {
                    lastText = element
                    if usernameField == nil, LoginOpen.asksForUsername(labels(of: element)) { usernameField = element }
                }
            }
            if let children = value(element, kAXChildrenAttribute) as? [AXUIElement] { stack.append(contentsOf: children.reversed()) }
        }
        return usernameField.map { LoginForm(url: url, user: $0, password: nil, destination: destination) }
    }

    /// What a field says about itself: DOM id, placeholder, label, title and help.
    static func labels(of field: AXUIElement) -> [String] {
        ["AXDOMIdentifier", "AXPlaceholderValue", kAXDescriptionAttribute, kAXTitleAttribute, kAXHelpAttribute]
            .compactMap { string(field, $0) }
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
