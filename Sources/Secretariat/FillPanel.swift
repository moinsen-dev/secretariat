import AppKit
import KeyboardShortcuts
import LocalAuthentication
import SecretariatCore
import SwiftUI

extension KeyboardShortcuts.Name {
    static let fillLogin = Self("fillLogin", default: .init(.p, modifiers: [.control, .option, .command]))
}

/// Global shortcut while the cursor sits in a password field: a small panel over the page names the site, offers the
/// matching items and a search; after Touch ID the chosen password is typed into the field. No clipboard, no value on screen.
final class FillController {
    static let shared = FillController()
    private var panel: NSPanel?
    private weak var model: AppModel?

    func install(_ model: AppModel) {
        self.model = model
        KeyboardShortcuts.onKeyUp(for: .fillLogin) { [weak self] in self?.show() }
    }

    func show() {
        guard let model else { return }
        close()
        let front = NSWorkspace.shared.frontmostApplication
        let target = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        let trusted = FocusedPage.isTrusted
        let focus = trusted ? target.map { FocusedPage.focus(pid: $0.processIdentifier) } : nil
        let page = focus?.url
        model.reload()
        let host = page.flatMap { LoginFill.host($0.absoluteString) }
        let view = FillPanelView(host: host, appName: target?.localizedName, trusted: trusted,
                                 inPasswordField: focus?.isPasswordField == true,
                                 search: { query in LoginFill.candidates(model.items, page: page?.absoluteString, query: query,
                                                                          preferred: SaveLoginController.shared.recentlySaved) },
                                 cancel: { [weak self] in self?.close() },
                                 allowAccess: { [weak self] in self?.close(); self?.requestAccess() },
                                 choose: { [weak self] candidate in self?.fill(candidate, host: host, page: page, into: target) })
        let panel = makeFloatingPanel(view)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() { panel?.close(); panel = nil }

    /// The request puts Secretariat into the Accessibility list (switched off); the link opens that list.
    func requestAccess() {
        FocusedPage.requestTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Touch ID (or the Mac password) for this one fill, then the value goes as keystrokes into the field that had focus.
    private func fill(_ candidate: LoginFill.Candidate, host: String?, page: URL?, into target: NSRunningApplication?) {
        close()
        guard let model, let target, let field = candidate.item.field(candidate.field) else { return }
        let place = host ?? target.localizedName ?? "the focused field"
        Task { @MainActor in
            let context = LAContext()
            do {
                guard try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                       localizedReason: "fill \(candidate.item.path) into \(place)") else { return }
            } catch { return }
            // The history notes the fill only once the value really is in the field.
            await PasswordTyping.type(into: target, page: page, place: place, typed: {
                model.vault.audit.record("read", ["field": "\(candidate.item.path)/\(field.name)", "purpose": "fill \(place)"])
            }) {
                model.storedValue(candidate.item, field)
            }
        }
    }
}

/// The one way Secretariat types a password: give the keyboard back to the page, wait until a password field of the same
/// page has the focus, then type only into that app. Used by Fill Login and Save Login.
@MainActor enum PasswordTyping {
    @discardableResult
    static func type(into target: NSRunningApplication, page: URL?, place: String,
                     retry: String = "Click into the field and press the shortcut again.",
                     typed onTyped: () -> Void = {}, value: () -> String?) async -> Bool {
        // Touch ID or the panel may have made Secretariat the active app.
        NSApplication.shared.yieldActivation(to: target)
        target.activate()
        var inFront = false, ready = false
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(100))
            inFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
            let now = FocusedPage.focus(pid: target.processIdentifier)
            ready = inFront && now.isPasswordField && samePage(now.url, page)
            if ready { break }
            if !inFront { target.activate() }
        }
        guard ready else {
            tell(inFront
                 ? "The cursor is no longer in the password field of \(place). \(retry)"
                 : "\(target.localizedName ?? "The app") did not come back to the front. \(retry)")
            return false
        }
        let pid = target.processIdentifier
        // Prepare the field first (same page, password field, whole content selected so the value replaces it); only then
        // read the value, which also records the fill in the history.
        let now = FocusedPage.focus(pid: pid)
        guard now.isPasswordField, samePage(now.url, page) else {
            tell("The cursor is no longer in the password field of \(place). \(retry)")
            return false
        }
        guard FocusedPage.clearPasswordField(pid: pid) else {
            tell(FocusedPage.passwordFieldLength(pid: pid) == nil
                 ? "This browser doesn't tell how many characters the password field holds, so Secretariat can't type safely there."
                 : "The password field of \(place) could not be emptied. Clear it by hand. \(retry)")
            return false
        }
        guard let text = value() else { return false }
        // Reading the keychain took a moment: still the same password field?
        let after = FocusedPage.focus(pid: pid)
        guard after.isPasswordField, samePage(after.url, page) else {
            tell("The cursor left the password field of \(place). \(retry)")
            return false
        }
        guard LoginFill.isTypable(text) else {
            tell("The password contains a line break or another control character. Typing it could submit the form or put part of it into another field.")
            return false
        }
        let typed = Keystrokes.type(text, to: pid, isFront: { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid })
        // The field shows as many dots as it holds characters: check that exactly the password arrived.
        try? await Task.sleep(for: .milliseconds(150))
        let length = FocusedPage.passwordFieldLength(pid: pid)
        // One dot per character or per UTF-16 unit, depending on the browser.
        guard typed, let length, length == text.count || length == text.utf16.count else {
            tell("The field holds \(length.map(String.init) ?? "an unknown number of") characters instead of \(text.count). Clear it. \(retry)")
            return false
        }
        onTyped()
        return true
    }

    private static var messagePanel: NSPanel?

    /// A message in its own small panel. Not an app-modal alert: that would block every other Secretariat window,
    /// including the Fill and Save panels, until it is closed.
    /// Same scheme, host and port (URL.host alone would make localhost:3000 the same page as localhost:8765).
    static func samePage(_ a: URL?, _ b: URL?) -> Bool {
        guard let a, let b else { return false }
        return LoginFill.origin(a) == LoginFill.origin(b)
    }

    static func tell(_ text: String, title: String = "Nothing was typed") {
        messagePanel?.close()
        let view = VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(.orange)
            Text(text).fixedSize(horizontal: false, vertical: true)
            HStack { Spacer(); Button("OK") { messagePanel?.close(); messagePanel = nil }.keyboardShortcut(.defaultAction) }
        }
        .padding(20).frame(width: 400)
        let panel = makeFloatingPanel(view)
        panel.makeKeyAndOrderFront(nil)
        messagePanel = panel
    }
}

/// A small panel over whatever app is in front that takes the keyboard without activating Secretariat.
func makeFloatingPanel<V: View>(_ view: V) -> NSPanel {
    let panel = FillKeyPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300),
                             styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
    panel.titlebarAppearsTransparent = true
    panel.titleVisibility = .hidden
    panel.level = .floating
    panel.isMovableByWindowBackground = true
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    let hosting = NSHostingView(rootView: view)
    panel.contentView = hosting
    panel.setContentSize(hosting.fittingSize)
    let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    if let frame = screen?.visibleFrame {
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - frame.height * 0.28 - panel.frame.height))
    }
    return panel
}

final class FillKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct FillPanelView: View {
    let host: String?
    let appName: String?
    let trusted: Bool
    let inPasswordField: Bool
    let search: (String) -> [LoginFill.Candidate]
    let cancel: () -> Void
    let allowAccess: () -> Void
    let choose: (LoginFill.Candidate) -> Void
    @State private var query = ""
    @State private var selected = 0
    @FocusState private var focused: Bool

    private var results: [LoginFill.Candidate] { search(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.key.fill").font(.title2).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.teal.gradient, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fill Login").font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if !trusted {
                Label("To see which page the field belongs to and to type the password, Secretariat needs Accessibility access: System Settings › Privacy & Security › Accessibility › Secretariat on. Then press the shortcut again.",
                      systemImage: "hand.raised").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                    Button("Allow Access …", action: allowAccess).keyboardShortcut(.defaultAction)
                }
            } else {
                TextField("Search items", text: $query, prompt: Text("Search by name, user or site"))
                    .textFieldStyle(.roundedBorder).focused($focused)
                    .onSubmit(submit)
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onChange(of: query) { selected = 0 }
                list
                if !inPasswordField {
                    Label("Click into the password field of the page first, then press the shortcut again. Secretariat only types into password fields.",
                          systemImage: "cursorarrow.click").foregroundStyle(.orange).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                Text("Touch ID confirms each fill. The password is typed into the field you were in, never copied to the clipboard.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                    Button("Fill", action: submit).keyboardShortcut(.defaultAction).disabled(results.isEmpty || !inPasswordField)
                }
            }
        }
        .padding(20).frame(width: 460)
        .onAppear { focused = true }
    }

    private var subtitle: String {
        if let host { return host }
        if !trusted { return "Access needed" }
        return appName.map { "No web page found in \($0): search instead" } ?? "No web page found: search instead"
    }

    @ViewBuilder private var list: some View {
        let items = Array(results.prefix(50))
        if items.isEmpty {
            Text(query.isEmpty ? "No item with a password yet." : "Nothing matches “\(query)”.")
                .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 60)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, candidate in
                            row(candidate, isSelected: index == selected).id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { if inPasswordField { choose(candidate) } else { selected = index } }
                        }
                    }
                }
                .frame(height: min(CGFloat(items.count) * 44, 220))
                .onChange(of: selected) { _, index in proxy.scrollTo(index) }
            }
        }
    }

    private func row(_ candidate: LoginFill.Candidate, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            // The seal only for the exact address stored with the item; everything else is just ordered first.
            Image(systemName: candidate.rank == .sameHost ? "checkmark.seal.fill" : "key")
                .foregroundStyle(candidate.rank == .sameHost ? Color.teal : Color.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(candidate.item.path).lineLimit(1)
                Text([candidate.username, candidate.host].compactMap { $0 }.joined(separator: " · ").ifEmpty("field \(candidate.field)"))
                    .font(.caption).foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private func move(_ step: Int) {
        let count = min(results.count, 50)
        guard count > 0 else { return }
        selected = (selected + step + count) % count
    }

    private func submit() {
        guard inPasswordField else { return }
        let items = results
        guard items.indices.contains(selected) else { return }
        choose(items[selected])
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
