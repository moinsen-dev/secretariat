import AppKit
import SwiftUI
import SecretariatCore

@main
enum Entry {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
        if !arguments.isEmpty {
            do { exit(try CommandLineInterface.run(arguments)) }
            catch {
                FileHandle.standardError.write(Data("Secretariat: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        Origin.set(Origin.app)
        NSApplication.shared.setActivationPolicy(.regular)
        // Design checks: light or dark for this instance only, without touching the Mac's setting.
        if let look = ProcessInfo.processInfo.environment["SECRETARIAT_APPEARANCE"] {
            NSApplication.shared.appearance = NSAppearance(named: look == "light" ? .aqua : .darkAqua)
        }
        SecretariatApp.main()
    }
}

struct SecretariatApp: App {
    @NSApplicationDelegateAdaptor(ShareOpener.self) private var opener
    @State private var model: AppModel
    private let updates = Updates()
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        CaptureController.shared.install(model)
        FillController.shared.install(model)
        SaveLoginController.shared.install(model)
        OpenLoginController.shared.install(model)
    }
    var body: some Scene {
        WindowGroup("Secretariat") {
            MainView(model: model)
                .frame(minWidth: 900, minHeight: 520)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    opener.model = model
                    opener.pending.first.map(model.openShare); opener.pending = []
                }
                // Profiles and items change from the CLI, agents and other Macs; pick that up when the user comes back.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.reload() }
        }
        .defaultSize(width: 1180, height: 720)
        // Opening a share package (double-click) goes to ShareOpener and the existing window, never a second one.
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates …") { updates.check() }.disabled(!updates.available)
                Button("License …") { model.showLicense = true }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Item …") { model.itemEditor = model.newItemDraft() }.keyboardShortcut("n")
                Button("New Project Profile …") { model.profileEditor = ProfileDraft(revision: model.configuration.revision) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Capture Clipboard …") { CaptureController.shared.show() }
                Button("Fill Login …") { FillController.shared.show() }
                Button("Save Login …") { SaveLoginController.shared.show() }
                Button("New Screenshot from Clipboard …") { model.screenshotFromClipboard() }
                Button("Import Screenshot …") { model.chooseScreenshotFile() }
                Button("Import Passwords (CSV) …") { model.choosePasswordFile() }
                Button("Open Share …") { model.chooseShareFile() }.keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("New Template …") { model.templateEditor = TemplateDraft(template: Template(id: "", title: ""), isNew: true) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
            // Like Notes and Reminders: the selected item's actions in the menu bar, with their shortcuts.
            CommandMenu("Item") {
                Button("Edit Item …") { if let item = model.currentItem, !Capture.isCapture(item) { model.edit(item) } }
                    .keyboardShortcut("e").disabled(model.currentItem.map(Capture.isCapture) ?? true)
                Button("Share Item …") { model.startShare(model.currentItem) }
                    .disabled(model.currentItem.map(Capture.isCapture) ?? true)
                // No ⌘⌫ here: a menu shortcut wins over text fields (delete to line start). ⌫ in the list deletes (onDeleteCommand).
                Button("Delete Item …") { if let item = model.currentItem { model.pendingDelete = item } }
                    .disabled(model.currentItem == nil)
            }
            CommandGroup(before: .toolbar) {
                Button("Reload") { model.reload() }.keyboardShortcut("r")
                Button("Inventory") { model.selection = "inventory" }.keyboardShortcut("i", modifiers: [.command, .option])
                Divider()
            }
        }
        Settings { SettingsView() }
    }
}
