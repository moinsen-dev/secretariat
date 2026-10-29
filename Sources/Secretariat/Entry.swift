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
                Divider()
                Button("New Template …") { model.templateEditor = TemplateDraft(template: Template(id: "", title: ""), isNew: true) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
        }
        Settings { SettingsView() }
    }
}
