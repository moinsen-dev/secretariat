import AppKit
import SwiftUI
import SecretariatCore
import UniformTypeIdentifiers

struct SecretEditor: View {
    let model: AppModel
    @State var draft: SecretDraft
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(draft.existingID == nil ? "Schlüssel hinzufügen" : "Schlüssel bearbeiten").font(.title2.bold())
            Form {
                TextField("Name", text: $draft.name, prompt: Text("OpenAI Entwicklung"))
                SecureField(draft.existingID == nil ? "Wert" : "Neuer Wert", text: $draft.value)
            }.textFieldStyle(.roundedBorder)
            Text(draft.existingID == nil ? "Der Wert wird lokal im macOS-Schlüsselbund gespeichert." : "Lasse den neuen Wert leer, um den bisherigen Wert zu behalten. Änderungen gelten beim nächsten Projektstart.")
                .font(.callout).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    if model.saveSecret(draft) { draft.value = ""; dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft.existingID == nil && draft.value.isEmpty))
            }
        }.padding(28).frame(width: 440)
    }
}

struct ProfileEditor: View {
    let model: AppModel
    @State var draft: ProfileDraft
    @State private var error: String?
    @State private var choosingDirectory = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(model.configuration.profiles.contains { $0.id == draft.profile.id } ? "Profil bearbeiten" : "Neues Projektprofil")
                .font(.title2.bold())
            Form {
                TextField("Profilname", text: $draft.profile.name, prompt: Text("cooking-ai-local"))
                LabeledContent("Projektordner") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.profile.directory.isEmpty ? "Noch kein Ordner ausgewählt" : draft.profile.directory)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Button("Ordner auswählen …") { choosingDirectory = true }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                TextField("Startbefehl", text: $draft.profile.command, prompt: Text("pnpm dev"))
            }.textFieldStyle(.roundedBorder)
            Text("Schlüssel zuordnen").font(.headline)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($draft.profile.bindings) { $binding in
                        HStack {
                            TextField("VARIABLE_NAME", text: $binding.variable).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Umgebungsvariable")
                            Picker("Schlüssel", selection: $binding.secretID) {
                                ForEach(model.configuration.secrets) { secret in Text(secret.name).tag(secret.id) }
                            }.labelsHidden().frame(width: 200).accessibilityLabel("Zugeordneter Schlüssel")
                            Button {
                                draft.profile.bindings.removeAll { $0.id == binding.id }
                            } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Zuordnung entfernen")
                        }
                    }
                    if draft.profile.bindings.isEmpty {
                        Text("Wähle die Schlüssel, die dieses Projekt beim Start benötigt.").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 2)
            }.frame(minHeight: 60, maxHeight: 200)
            Button("Schlüssel zuordnen", systemImage: "plus") {
                if let first = model.configuration.secrets.first {
                    draft.profile.bindings.append(Binding(variable: "", secretID: first.id))
                }
            }.disabled(model.configuration.secrets.isEmpty)
            if model.configuration.secrets.isEmpty { Text("Füge zuerst einen Schlüssel hinzu.").font(.caption).foregroundStyle(.secondary) }
            Text("Der Startbefehl enthält keine Schlüsselwerte und wird erst durch deinen Aufruf im Terminal ausgeführt.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    if model.saveProfile(draft.profile, expectedRevision: draft.revision) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.profile.name.isEmpty || draft.profile.directory.isEmpty)
            }
        }.padding(28).frame(width: 560)
        .fileImporter(isPresented: $choosingDirectory, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { draft.profile.directory = url.path }
            case .failure: error = "Der Ordner konnte nicht ausgewählt werden. Bitte erneut versuchen."
            }
        }
    }
}
