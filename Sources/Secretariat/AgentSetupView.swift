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
            Text("Set Up Coding Agent").font(.title2.bold())
            Text("Codex, Claude Code and OpenCode use the same project instructions.")
                .foregroundStyle(.secondary)
            Label(draft.plan.directory.path, systemImage: "folder").font(.caption).textSelection(.enabled)
            Text("AGENTS.md gets the instructions. CLAUDE.md points to it. Existing content outside the Secretariat section stays as it is.")
            ScrollView {
                Text(draft.plan.instructions).font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            .frame(minHeight: 160, maxHeight: 300)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) }
            if installed {
                Label("Project instructions are set up.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text(draft.plan.changedFiles.isEmpty ? "Both files are already up to date." : "Will be updated: \(draft.plan.changedFiles.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button(installed ? "Done" : "Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(copied ? "Instructions Copied" : "Copy Instructions") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(draft.plan.instructions, forType: .string)
                    copied = true
                }
                Spacer()
                Button("Set Up in Project") {
                    do { try model.applyAgentSetup(draft); installed = true; errorMessage = nil }
                    catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.borderedProminent).disabled(installed)
            }
        }.padding(24).frame(width: 640)
    }
}
