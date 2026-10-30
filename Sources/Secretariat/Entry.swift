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
        SecretariatApp.main()
    }
}

struct SecretariatApp: App {
    @State private var model: AppModel
    private let updates = Updates()
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        CaptureController.shared.install(model)
    }
    var body: some Scene {
        WindowGroup("Secretariat") {
            MainView(model: model)
                .frame(minWidth: 900, minHeight: 520)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
                // Profiles and items change from the CLI, agents and other Macs; pick that up when the user comes back.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.reload() }
        }
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates …") { updates.check() }.disabled(!updates.available)
                Button("License …") { model.showLicense = true }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Item …") { model.itemEditor = model.newItemDraft() }.keyboardShortcut("n")
                Button("New Project Profile …") { model.profileEditor = ProfileDraft(revision: model.configuration.revision) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Capture Clipboard …") { CaptureController.shared.show() }
                Button("New Screenshot from Clipboard …") { model.screenshotFromClipboard() }
                Button("Import Screenshot …") { model.chooseScreenshotFile() }
                Divider()
                Button("New Template …") { model.templateEditor = TemplateDraft(template: Template(id: "", title: ""), isNew: true) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
            CommandGroup(before: .toolbar) {
                Button("Reload") { model.reload() }.keyboardShortcut("r")
                Divider()
            }
        }
        Settings { SettingsView() }
    }
}
