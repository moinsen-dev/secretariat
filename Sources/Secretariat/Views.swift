import SwiftUI
import SecretariatCore

struct MainView: View {
    @Bindable var model: AppModel
    @State private var deletingSecret: SecretReference?
    @State private var deletingProfile: Profile?

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Label("Alle Schlüssel", systemImage: "key.horizontal").tag("keys")
                Section("Projektprofile") {
                    ForEach(model.configuration.profiles.sorted { $0.name < $1.name }) { profile in
                        Label(profile.name, systemImage: "folder").tag(profile.id.uuidString)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 225)
            .safeAreaInset(edge: .bottom) {
                Button { model.profileEditor = ProfileDraft(revision: model.configuration.revision) } label: {
                    Label("Neues Profil", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.borderless).padding()
            }
        } detail: {
            Group {
                if model.loadFailed {
                    ContentUnavailableView {
                        Label("Daten konnten nicht geladen werden", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("Der vorhandene Stand bleibt erhalten. Bitte die Konfiguration prüfen und erneut laden.")
                    } actions: { Button("Erneut laden") { model.reload() } }
                } else if let profile = model.currentProfile { profileDetail(profile) }
                else { keyLibrary }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle("Secretariat")
        .onChange(of: model.selection) { model.copied = false }
        .toolbar {
            ToolbarItem { Button { model.reload() } label: { Label("Aktualisieren", systemImage: "arrow.clockwise") } }
        }
        .sheet(item: $model.secretEditor) { draft in SecretEditor(model: model, draft: draft) }
        .sheet(item: $model.agentSetup) { draft in AgentSetupView(model: model, draft: draft) }
        .sheet(item: $model.profileEditor) { draft in ProfileEditor(model: model, draft: draft) }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Schlüssel löschen?", isPresented: Binding(get: { deletingSecret != nil }, set: { if !$0 { deletingSecret = nil } })) {
            Button("Abbrechen", role: .cancel) { deletingSecret = nil }
            Button("Löschen", role: .destructive) {
                if let secret = deletingSecret { model.deleteSecret(secret) }; deletingSecret = nil
            }
        } message: { Text("‚\(deletingSecret?.name ?? "")‘ wird aus dem Schlüsselbund entfernt. Verwendete Schlüssel bleiben geschützt.") }
        .alert("Profil löschen?", isPresented: Binding(get: { deletingProfile != nil }, set: { if !$0 { deletingProfile = nil } })) {
            Button("Abbrechen", role: .cancel) { deletingProfile = nil }
            Button("Löschen", role: .destructive) {
                if let profile = deletingProfile { model.deleteProfile(profile) }; deletingProfile = nil
            }
        } message: { Text("Die Zuordnungen werden entfernt. Die gespeicherten Schlüssel bleiben erhalten.") }
    }

    private var keyLibrary: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deine Schlüssel").font(.largeTitle.bold())
                    Text("Einmal hinterlegen. In deinen Projekten verwenden.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Schlüssel hinzufügen", systemImage: "plus") { model.secretEditor = SecretDraft(revision: model.configuration.revision) }
                    .buttonStyle(.borderedProminent).disabled(model.loadFailed)
            }
            if model.configuration.secrets.isEmpty {
                ContentUnavailableView {
                    Label("Alles an einem Ort", systemImage: "key.horizontal.fill")
                } description: {
                    Text("Hinterlege deinen ersten API-Schlüssel. Sein Wert wird im macOS-Schlüsselbund gespeichert.")
                } actions: {
                    Button("Ersten Schlüssel hinzufügen") { model.secretEditor = SecretDraft(revision: model.configuration.revision) }
                }.frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.configuration.secrets.sorted { $0.name < $1.name }) { secret in
                            HStack(spacing: 14) {
                                Image(systemName: "key.fill").foregroundStyle(.tint).frame(width: 24)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(secret.name).font(.headline)
                                    let usages = model.usages(of: secret.id)
                                    Text(usages.isEmpty ? "Noch keinem Profil zugeordnet" : usages.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Text("••••••••").foregroundStyle(.tertiary).accessibilityLabel("Wert verdeckt")
                                Button("Bearbeiten") {
                                    model.secretEditor = SecretDraft(existingID: secret.id, name: secret.name, revision: model.configuration.revision)
                                }.accessibilityLabel("\(secret.name) bearbeiten")
                                Button { deletingSecret = secret } label: { Image(systemName: "trash") }
                                    .accessibilityLabel("\(secret.name) löschen")
                            }.padding(.vertical, 16)
                            Divider()
                        }
                    }
                }
            }
            Label("Die Werte bleiben im macOS-Schlüsselbund.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func profileDetail(_ profile: Profile) -> some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.name).font(.largeTitle.bold())
                    Label(profile.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button("Bearbeiten") { model.profileEditor = ProfileDraft(profile: profile, revision: model.configuration.revision) }
            }
            Divider()
            Text("Schlüssel für dieses Projekt").font(.headline)
            if profile.bindings.isEmpty {
                Text("Diesem Profil sind noch keine Schlüssel zugeordnet.").foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                    GridRow { Text("Variable").foregroundStyle(.secondary); Text("Verwendeter Schlüssel").foregroundStyle(.secondary) }
                    ForEach(profile.bindings) { binding in
                        GridRow {
                            Text(binding.variable).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Text(model.configuration.secrets.first { $0.id == binding.secretID }?.name ?? "Schlüssel fehlt")
                        }
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Im Terminal starten").font(.headline)
                Text(profile.command.isEmpty ? "Trage unter Bearbeiten einen Startbefehl ein." : profile.command)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Button(model.copied ? "Aufruf kopiert" : "Terminalaufruf kopieren", systemImage: model.copied ? "checkmark" : "terminal") {
                    model.copyLaunch(profile)
                }.buttonStyle(.borderedProminent).disabled(profile.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Den Aufruf im Terminal einfügen. Das Programm erhält die ausgewählten Schlüssel beim Start.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Mit Coding-Systemen verwenden").font(.headline)
                Text("Projektanweisungen für Codex, Claude Code und OpenCode vorbereiten.")
                    .foregroundStyle(.secondary)
                Button("Coding-System einrichten", systemImage: "terminal.fill") { model.openAgentSetup(profile) }
            }
            Spacer()
            Button("Profil löschen", role: .destructive) { deletingProfile = profile }.buttonStyle(.borderless)
        }
        }
    }
}
