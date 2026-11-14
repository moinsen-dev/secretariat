import AppKit
import KeyboardShortcuts
import LocalAuthentication
import SecretariatCore

/// Open and Sign In: opens an item's address in the default browser, waits until the page shows its login form, asks for
/// Touch ID and types the user name and the password into it. A sign-in that asks for the user name first gets the name,
/// then the password once the user has continued to the next page. The form is never submitted. Started from the item
/// view, `secretariat open PATH` and the MCP tool open_login (both only ask the app; the value never leaves it).
final class OpenLoginController {
    static let shared = OpenLoginController()
    private weak var model: AppModel?
    private var running = false

    func install(_ model: AppModel) {
        self.model = model
        DistributedNotificationCenter.default().addObserver(forName: LoginOpen.requestName, object: nil, queue: .main) { note in
            let id = note.object as? String ?? ""
            let info = note.userInfo as? [String: String] ?? [:]
            // A CLI on another vault (a test home) talks to another app; this one stays silent.
            guard LoginOpen.isForThisVault(info, paths: model.paths) else { return }
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
            let pid = browser.processIdentifier
            // Wait for a login form where this login may go: the stored host, its site, or the site the front page was sent to.
            guard let found = await waitForForm(pid: pid, item: url, seconds: 15, needsPassword: false) else {
                notFilled(FocusedPage.hasPage(pid: pid, item: url)
                          ? "\(host) shows no login field. If you are already signed in, there is nothing to fill."
                          : "No login form of \(host) showed up within 15 seconds.")
                return
            }
            var confirmed: Set<String> = []
            guard await confirm(item, itemHost: host, form: found) else { return }
            confirmed.insert(found.host)
            guard var form = await frontAgain(browser, item: url, needsPassword: found.password != nil) else {
                notFilled("The login form of \(host) is gone."); return
            }
            // Nothing is typed on a host Touch ID didn't name (the page may have moved on meanwhile).
            func isConfirmed(_ form: FocusedPage.LoginForm) -> Bool { form.destination == .sameHost || confirmed.contains(form.host) }
            guard isConfirmed(form) else { notFilled("The page moved on to \(form.host) before anything was typed."); return }
            if form.password == nil {
                // Two-step sign-in: the user name now; the user continues, then the password field appears.
                guard let user = form.user, let name = LoginFill.username(item) else {
                    notFilled("\(form.host) asks for the user name first, but \(item.path) has none."); return
                }
                guard typeUsername(name, into: user, pid: pid) else { notFilled("The user name could not be typed into \(form.host)."); return }
                guard let next = await waitForForm(pid: pid, item: url, seconds: 60, needsPassword: true, frontOnly: true) else {
                    notFilled("No password field showed up within a minute after the user name. Continue to the password page."); return
                }
                form = next
                if !isConfirmed(form) {
                    // Sent on to another sign-in host: the user confirms that one by name.
                    guard await confirm(item, itemHost: host, form: form) else { return }
                    confirmed.insert(form.host)
                    guard let again = await frontAgain(browser, item: url, needsPassword: true) else {
                        notFilled("The login form of \(form.host) is gone."); return
                    }
                    form = again
                    guard isConfirmed(form) else { notFilled("The page moved on to \(form.host) before anything was typed."); return }
                }
            } else if let user = form.user, let name = LoginFill.username(item), !typeUsername(name, into: user, pid: pid) {
                notFilled("The user name could not be typed into \(form.host)."); return
            }
            guard let password = form.password else { return }
            FocusedPage.focus(password)
            let place = form.host
            let typed = await PasswordTyping.type(into: browser, page: form.url, place: place,
                                                  retry: "Click into the password field and press \(fillShortcut).",
                                                  typed: { model.vault.audit.record("read", ["field": "\(item.path)/\(field.name)", "purpose": "sign in \(place)"]) }) {
                model.storedValue(item, field)
            }
            if !typed { return }
        }
    }

    /// Polls the browser for a login form of this login, up to `seconds`.
    private func waitForForm(pid: pid_t, item: URL, seconds: Int, needsPassword: Bool, frontOnly: Bool = false) async -> FocusedPage.LoginForm? {
        for _ in 0..<(seconds * 10) {
            if let form = FocusedPage.loginForm(pid: pid, item: item, needsPassword: needsPassword, frontOnly: frontOnly) { return form }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    /// Touch ID for typing this login into the form's host. Says so when the user cancels or it fails: nothing typed.
    private func confirm(_ item: ItemMeta, itemHost: String, form: FocusedPage.LoginForm) async -> Bool {
        let reason = form.destination != .sameHost
            ? "sign in to \(form.host) (sent there by \(itemHost)) with \(item.path)"
            : "sign in to \(form.host) with \(item.path)"
        do {
            if try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { return true }
            notFilled("Touch ID didn't confirm, so nothing was typed.")
        } catch let error as LAError where [.userCancel, .appCancel, .systemCancel].contains(error.code) {
            notFilled("Touch ID was cancelled, so nothing was typed.")
        } catch {
            notFilled("Touch ID didn't confirm (\(error.localizedDescription)), so nothing was typed.")
        }
        return false
    }

    /// Touch ID took the front: hands it back to the browser and finds the form again (the page may have changed meanwhile).
    private func frontAgain(_ browser: NSRunningApplication, item: URL, needsPassword: Bool) async -> FocusedPage.LoginForm? {
        NSApplication.shared.yieldActivation(to: browser)
        browser.activate()
        let pid = browser.processIdentifier
        var form: FocusedPage.LoginForm?
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            form = FocusedPage.loginForm(pid: pid, item: item, needsPassword: needsPassword)
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid, form != nil { break }
            browser.activate()
        }
        return form
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
