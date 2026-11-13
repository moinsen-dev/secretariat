import AppKit
import KeyboardShortcuts
import LocalAuthentication
import SecretariatCore

/// Open and Sign In: opens an item's address in the default browser, waits until the page shows its login form, asks for
/// Touch ID and types the user name and the password into it. The form is not submitted. Started from the item view,
/// `secretariat open PATH` and the MCP tool open_login (both only ask the app; the value never leaves it).
final class OpenLoginController {
    static let shared = OpenLoginController()
    private weak var model: AppModel?
    private var running = false

    func install(_ model: AppModel) {
        self.model = model
        DistributedNotificationCenter.default().addObserver(forName: LoginOpen.requestName, object: nil, queue: .main) { note in
            let id = note.object as? String ?? ""
            let info = note.userInfo as? [String: String] ?? [:]
            MainActor.assumeIsolated { OpenLoginController.shared.handle(request: id, path: info["path"] ?? "", via: info["via"] ?? "cli") }
        }
    }

    /// The CLI repeats its request until it hears back; each request id is answered once.
    private var answered: Set<String> = []

    private func handle(request id: String, path: String, via: String) {
        guard !id.isEmpty, answered.insert(id).inserted else { return }
        guard let model else { LoginOpen.answer(request: id, error: "The app is still starting. Try again."); return }
        model.reload()
        guard let item = model.items.first(where: { $0.path.lowercased() == path.lowercased() }) else {
            LoginOpen.answer(request: id, error: "No item \(path)."); return
        }
        do { _ = try LoginOpen.check(item) } catch { LoginOpen.answer(request: id, error: error.localizedDescription); return }
        LoginOpen.answer(request: id)
        open(item, via: via)
    }

    func open(_ item: ItemMeta, via: String = "app") {
        guard let model, !running else { return }
        let url: URL
        do { url = try LoginOpen.check(item) } catch { PasswordTyping.tell(error.localizedDescription, title: "Can't sign in"); return }
        guard let host = LoginFill.host(url.absoluteString), let fieldName = LoginFill.fillableField(item),
              let field = item.field(fieldName) else { return }
        running = true
        model.vault.audit.record("open.login", ["item": item.path, "host": host, "via": via])
        Task { @MainActor in
            defer { running = false }
            guard let browser = await openPage(url) else {
                PasswordTyping.tell("The page could not be opened in the default browser.", title: "Can't sign in"); return
            }
            guard FocusedPage.isTrusted else {
                FillController.shared.requestAccess()
                PasswordTyping.tell("To fill the login, Secretariat needs Accessibility access: System Settings › Privacy & Security › Accessibility › Secretariat on.",
                                    title: "Page opened, nothing typed")
                return
            }
            // Wait for the login form of exactly this host (redirects to another host never get the password).
            var form: FocusedPage.LoginForm?
            for _ in 0..<150 {
                form = FocusedPage.loginForm(pid: browser.processIdentifier, host: host)
                if form != nil { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard form != nil else {
                let open = FocusedPage.hasPage(pid: browser.processIdentifier, host: host)
                notFilled(open ? "\(host) shows no password field. If you are already signed in, there is nothing to fill."
                               : "No login form of \(host) showed up within 15 seconds.")
                return
            }
            let context = LAContext()
            do {
                guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                       localizedReason: "sign in to \(host) with \(item.path)") else { return }
            } catch { return }
            // Touch ID took the front: hand it back, then find the form again (the page may have changed meanwhile).
            NSApplication.shared.yieldActivation(to: browser)
            browser.activate()
            let pid = browser.processIdentifier
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(100))
                form = FocusedPage.loginForm(pid: pid, host: host)
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, form != nil { break }
                browser.activate()
            }
            guard let form else { notFilled("The login form of \(host) is gone."); return }
            if let user = form.user, let name = LoginFill.username(item), !typeUsername(name, into: user, pid: pid) {
                notFilled("The user name could not be typed into \(host)."); return
            }
            FocusedPage.focus(form.password)
            let typed = await PasswordTyping.type(into: browser, page: form.url, place: host,
                                                  retry: "Click into the password field and press \(fillShortcut).",
                                                  typed: { model.vault.audit.record("read", ["field": "\(item.path)/\(field.name)", "purpose": "sign in \(host)"]) }) {
                model.storedValue(item, field)
            }
            if !typed { return }
        }
    }

    /// Opens the address with the app that handles it and returns that app once it runs.
    private func openPage(_ url: URL) async -> NSRunningApplication? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else { return nil }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return try? await NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }

    /// Types the user name into its field unless it already holds exactly that name. Only the identifier is typed here.
    private func typeUsername(_ name: String, into field: AXUIElement, pid: pid_t) -> Bool {
        if FocusedPage.text(of: field) == name { return true }
        guard LoginFill.isTypable(name) else { return false }
        FocusedPage.focus(field)
        for _ in 0..<10 where !FocusedPage.hasFocus(field, pid: pid) { Thread.sleep(forTimeInterval: 0.05) }
        guard FocusedPage.hasFocus(field, pid: pid), FocusedPage.clearTextField(field, pid: pid) else { return false }
        guard Keystrokes.type(name, to: pid, isFront: { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid }) else { return false }
        Thread.sleep(forTimeInterval: 0.1)
        return FocusedPage.text(of: field) == name
    }

    private var fillShortcut: String { KeyboardShortcuts.getShortcut(for: .fillLogin)?.description ?? "⌃⌥⌘P" }

    private func notFilled(_ reason: String) {
        PasswordTyping.tell("\(reason) The page stays open: click into the password field and press \(fillShortcut) to fill it.",
                            title: "Page opened, nothing typed")
    }
}
