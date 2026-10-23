import SwiftUI
import AppKit
import SecretariatCore

struct AgentSetupDraft: Identifiable {
    let id = UUID()
    let plan: InstructionPlan
    let revision: Int
}

struct AgentSetupView: View {
    let model: AppModel
    let draft: AgentSetupDraft
    @Environment(\.dismiss) private var dismiss
    @State private var installed = false
    @State private var copied = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coding-System einrichten").font(.title2.bold())
            Text("Codex, Claude Code und OpenCode verwenden dieselbe Projektanweisung.")
                .foregroundStyle(.secondary)
            Label(draft.plan.directory.path, systemImage: "folder").font(.caption).textSelection(.enabled)
            Text("AGENTS.md erhält die Anleitung. CLAUDE.md verweist darauf. Vorhandene Inhalte außerhalb des Secretariat-Abschnitts bleiben erhalten.")
            ScrollView {
                Text(draft.plan.instructions).font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            .frame(minHeight: 160, maxHeight: 300)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) }
            if installed {
                Label("Projektanweisungen sind eingerichtet.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text(draft.plan.changedFiles.isEmpty ? "Beide Dateien sind bereits aktuell." : "Wird aktualisiert: \(draft.plan.changedFiles.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(installed ? "Fertig" : "Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(copied ? "Anleitung kopiert" : "Anleitung kopieren") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(draft.plan.instructions, forType: .string)
                    copied = true
                }
                Spacer()
                Button("Im Projekt einrichten") {
                    do { try model.applyAgentSetup(draft); installed = true; errorMessage = nil }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).disabled(installed)
            }
        }.padding(24).frame(width: 640)
    }
}
