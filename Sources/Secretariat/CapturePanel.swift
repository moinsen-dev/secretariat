import AppKit
import KeyboardShortcuts
import SecretariatCore
import SwiftUI

extension KeyboardShortcuts.Name {
    static let capture = Self("captureClipboard", default: .init(.v, modifiers: [.control, .option, .command]))
}

/// Global shortcut → small floating panel over whatever app is in front: name the copied value (optional), save it to the inbox,
/// clear the clipboard. Like Reminders' quick entry, it does not bring the main window forward.
final class CaptureController {
    static let shared = CaptureController()
    private var panel: NSPanel?
    private weak var model: AppModel?

    func install(_ model: AppModel) {
        self.model = model
        KeyboardShortcuts.onKeyUp(for: .capture) { [weak self] in self?.show() }
    }

    func show() {
        let pasteboard = NSPasteboard.general
        let text = pasteboard.string(forType: .string) ?? ""
        let change = pasteboard.changeCount
        close()
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 200),
                             styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = CapturePanelView(value: text, capturedAt: Date(), cancel: { [weak self] in self?.close() }) { [weak self] name in
            guard let model = self?.model else { return "Secretariat is not ready yet." }
            if let error = model.capture(text, name: name) { return error }
            // The credential is safe now; don't leave it on the clipboard (unless something else was copied meanwhile).
            if pasteboard.changeCount == change { pasteboard.clearContents() }
            self?.close()
            return nil
        }
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - frame.height * 0.28 - panel.frame.height))
        }
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() { panel?.close(); panel = nil }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

struct CapturePanelView: View {
    let value: String
    let capturedAt: Date
    let cancel: () -> Void
    let save: (String) -> String?
    @State private var name = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    private var isEmpty: Bool { value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard.fill").font(.title2).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.blue.gradient, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture Clipboard").font(.headline)
                    Text(capturedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if isEmpty {
                Label("The clipboard holds no text. Copy the credential first, then press the shortcut again.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(Capture.preview(value)).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                TextField("Name (optional)", text: $name, prompt: Text(Capture.provider(for: value).map { "e.g. \($0) main key" } ?? "Name (optional), e.g. cloudflare pulse readonly"))
                    .textFieldStyle(.roundedBorder).focused($focused).onSubmit(submit)
                Text("Goes to the Inbox with date and time. The clipboard is cleared afterwards, and no program gets the value until you turn it into an item.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Save to Inbox", action: submit).keyboardShortcut(.defaultAction).disabled(isEmpty)
            }
        }
        .padding(20).frame(width: 440)
        .onAppear { focused = true }
    }

    private func submit() {
        guard !isEmpty else { return }
        error = save(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Capture clipboard:", name: .capture)
            Text("Copy a credential anywhere, press the shortcut and give it a name if you like. It lands in the Inbox with date and time, and the clipboard is cleared.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped).frame(width: 480)
    }
}
