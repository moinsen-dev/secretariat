import AppKit
import KeyboardShortcuts
import SecretariatCore
import SwiftUI

extension KeyboardShortcuts.Name {
    static let saveLogin = Self("saveLogin", default: .init(.s, modifiers: [.control, .option, .command]))
}

/// Global shortcut on a login, sign-up or change-password page: saves a new "Website login" item for the page. The password
/// is generated (and typed into the focused password field), taken from the clipboard (which is cleared), or typed once into
/// the panel. A password already typed into the page can't be read: macOS shows other apps only bullets.
final class SaveLoginController {
    static let shared = SaveLoginController()
    private var panel: NSPanel?
    private weak var model: AppModel?
    /// The login saved last, for a few minutes: Fill Login offers it first (confirm field on the same page).
    private(set) var lastSaved: (id: UUID, at: Date)?
    var recentlySaved: UUID? { lastSaved.flatMap { Date().timeIntervalSince($0.at) < 600 ? $0.id : nil } }

    func install(_ model: AppModel) {
        self.model = model
        KeyboardShortcuts.onKeyUp(for: .saveLogin) { [weak self] in self?.show() }
    }

    func show() {
        guard let model else { return }
        close()
        let front = NSWorkspace.shared.frontmostApplication
        let target = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        let trusted = FocusedPage.isTrusted
        let focus = trusted ? target.map { FocusedPage.focus(pid: $0.processIdentifier) } : nil
        let page = focus?.url
        let host = page.flatMap { LoginFill.host($0.absoluteString) }
        let username = trusted ? target.flatMap { FocusedPage.username(pid: $0.processIdentifier) } ?? "" : ""
        let inPasswordField = focus?.isPasswordField == true
        model.reload()
        let path = host.map { LoginCapture.path(host: $0, username: username, existing: model.items.map(\.path)) } ?? ""
        let view = SaveLoginView(host: host, trusted: trusted, inPasswordField: inPasswordField,
                                 path: path, username: username,
                                 cancel: { [weak self] in self?.close() },
                                 allowAccess: { [weak self] in self?.close(); FillController.shared.requestAccess() },
                                 save: { [weak self] request in self?.save(request, host: host, page: page, into: target, typing: inPasswordField) })
        let panel = makeFloatingPanel(view)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() { panel?.close(); panel = nil }

    /// Saves the item; returns an error text for the panel instead of closing it.
    private func save(_ request: SaveLoginView.Request, host: String?, page: URL?, into target: NSRunningApplication?,
                      typing: Bool) -> String? {
        guard let model, let host, let page, let address = LoginFill.origin(page) else { return "No web page found." }
        let pasteboard = NSPasteboard.general
        let change = pasteboard.changeCount
        let password: String
        switch request.source {
        case .generate: password = PasswordGenerator.make()
        case .clipboard: password = (pasteboard.string(forType: .string) ?? "").trimmingCharacters(in: .newlines)
        case .typed: password = request.typed
        }
        guard !password.isEmpty else { return request.source == .clipboard ? "The clipboard holds no text." : "Enter the password." }
        guard LoginFill.isTypable(password) else { return "The password contains a line break or another control character." }
        let meta = LoginCapture.item(address: address, path: request.path.trimmingCharacters(in: .whitespaces), username: request.username)
        do { try model.vault.save(meta, secrets: ["password": password]) } catch { return error.localizedDescription }
        lastSaved = (meta.id, Date())
        // The password is safe now; don't leave it on the clipboard (unless something else was copied meanwhile).
        if request.source == .clipboard, pasteboard.changeCount == change { pasteboard.clearContents() }
        close()
        model.reload()
        // A new password goes straight into the field it was made for; Fill Login (with Touch ID) fills the confirm field.
        // Only into the password field the shortcut was pressed in; otherwise Fill Login types it later.
        if request.source == .generate, typing, let target {
            let retry = "The new password is saved as \(meta.path). Click into the password field and use Fill Login (⌃⌥⌘P) to type it."
            Task { @MainActor in await PasswordTyping.type(into: target, page: page, place: host, retry: retry) { password } }
        }
        return nil
    }
}

struct SaveLoginView: View {
    enum Source: String, CaseIterable, Identifiable {
        case generate, clipboard, typed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .generate: "Generate"
            case .clipboard: "Clipboard"
            case .typed: "Type"
            }
        }
    }
    struct Request { var path: String; var username: String; var source: Source; var typed: String }

    let host: String?
    let trusted: Bool
    let inPasswordField: Bool
    @State var path: String
    @State var username: String
    let cancel: () -> Void
    let allowAccess: () -> Void
    let save: (Request) -> String?
    @State private var source: Source = .generate
    @State private var typed = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.plus").font(.title2).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Login").font(.headline)
                    Text(host ?? (trusted ? "No web page found" : "Access needed")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if !trusted {
                Label("To see which page you are on, Secretariat needs Accessibility access: System Settings › Privacy & Security › Accessibility › Secretariat on. Then press the shortcut again.",
                      systemImage: "hand.raised").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                    Button("Allow Access …", action: allowAccess).keyboardShortcut(.defaultAction)
                }
            } else if host == nil {
                Text("Open the login or sign-up page in a browser, click into it and press the shortcut again.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Button("Close", action: cancel).keyboardShortcut(.cancelAction) }
            } else {
                Form {
                    TextField("Name", text: $path)
                    TextField("User name", text: $username, prompt: Text("e-mail or user name"))
                    Picker("Password", selection: $source) {
                        ForEach(Source.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if source == .typed { SecureField("Password", text: $typed) }
                }
                .formStyle(.grouped).scrollDisabled(true).frame(height: source == .typed ? 190 : 150)
                Text(hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let error { Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                HStack {
                    Spacer()
                    Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                    Button(source == .generate && inPasswordField ? "Save and Fill" : "Save") {
                        error = save(Request(path: path, username: username, source: source, typed: typed))
                    }
                    .keyboardShortcut(.defaultAction).disabled(path.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(20).frame(width: 460)
    }

    private var hint: String {
        switch source {
        case .generate:
            inPasswordField
                ? "A new 20-character password is saved and typed into the password field. Fill a confirm field with Fill Login."
                : "A new 20-character password is saved. Click into the password field and use Fill Login to type it."
        case .clipboard: "Copy the password first. It is saved and the clipboard is cleared."
        case .typed: "A password already typed into the page can't be read: macOS shows other apps only dots. Type it once here."
        }
    }
}
