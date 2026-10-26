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
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup("Secretariat") {
            MainView(model: model)
                .frame(minWidth: 760, minHeight: 500)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 990, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neuer Eintrag …") { model.itemEditor = ItemDraft(revision: model.configuration.revision) }.keyboardShortcut("n")
                Button("Neues Projektprofil …") { model.profileEditor = ProfileDraft(revision: model.configuration.revision) }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
