import AppKit
import SwiftUI
import SecretariatCore
import UniformTypeIdentifiers

struct ItemEditor: View {
    let model: AppModel
    @State var draft: ItemDraft
    @State private var error: String?
    @State private var importingField: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.existing == nil ? "Eintrag hinzufügen" : "Eintrag bearbeiten").font(.title2.bold())
            Form {
                TextField("Pfad", text: $draft.path, prompt: Text("moinsen/konto/name"))
                Picker("Art", selection: $draft.kind) {
                    ForEach(ItemKind.allCases, id: \.self) { kind in Label(kind.title, systemImage: kind.symbol).tag(kind) }
                }
                TextField("Herkunft", text: $draft.source, prompt: Text("Konsole, Datei oder Befehl"))
                TextField("Läuft ab", text: $draft.expires, prompt: Text("JJJJ-MM-TT (optional)"))
            }.textFieldStyle(.roundedBorder)
            .onChange(of: draft.kind) { _, kind in
                let untouched = draft.fields.allSatisfy { $0.value.isEmpty && $0.fileData == nil }
                if draft.existing == nil && untouched { draft.fields = kind.template.map { FieldDraft(name: $0.0, kind: $0.1) } }
            }
            Text("Felder").font(.headline)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($draft.fields) { $field in
                        HStack {
                            TextField("feldname", text: $field.name).textFieldStyle(.roundedBorder).frame(width: 140)
                                .accessibilityLabel("Feldname")
                            Picker("Feldart", selection: $field.kind) {
                                ForEach(FieldKind.allCases, id: \.self) { Text($0.title).tag($0) }
                            }.labelsHidden().frame(width: 130)
                            valueControl($field)
                            Button { draft.fields.removeAll { $0.id == field.id } } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).accessibilityLabel("Feld entfernen")
                        }
                    }
                    if draft.fields.isEmpty {
                        Text("Füge mindestens ein Feld hinzu.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 2)
            }.frame(minHeight: 60, maxHeight: 260)
            Button("Feld hinzufügen", systemImage: "plus") { draft.fields.append(FieldDraft(kind: .secret)) }
            Text(draft.existing == nil
                 ? "Kennungen sind lesbar. Geheimnisse und Dateien bekommen nur Programme, „Nur für mich“ bleibt in der App."
                 : "Lässt du ein geheimes Feld leer, bleibt sein bisheriger Wert erhalten.")
                .font(.callout).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    if model.saveItem(draft) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.fields.isEmpty)
            }
        }.padding(28).frame(width: 640)
        .fileImporter(isPresented: SwiftUI.Binding(get: { importingField != nil }, set: { if !$0 { importingField = nil } }),
                      allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard let id = importingField, let index = draft.fields.firstIndex(where: { $0.id == id }) else { return }
            importingField = nil
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 250 * 1024 else { error = "Dateien dürfen höchstens 250 KB groß sein."; return }
                draft.fields[index].fileData = data.base64EncodedString()
                draft.fields[index].fileName = url.lastPathComponent
            } catch { self.error = "Die Datei konnte nicht gelesen werden. Bitte erneut versuchen." }
        }
    }

    @ViewBuilder private func valueControl(_ field: SwiftUI.Binding<FieldDraft>) -> some View {
        let isStored = field.wrappedValue.storedName != nil
        switch field.wrappedValue.kind {
        case .identifier:
            TextField("Wert", text: field.value).textFieldStyle(.roundedBorder).accessibilityLabel("Wert der Kennung")
        case .secret, .personal:
            SecureField(isStored ? "Unverändert" : "Wert", text: field.value).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Geheimer Wert")
        case .file:
            HStack {
                Text(field.wrappedValue.fileName ?? "Keine Datei").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Button("Datei wählen …") { importingField = field.wrappedValue.id }
            }.frame(maxWidth: .infinity)
        }
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
            Text("Werte zuordnen").font(.headline)
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($draft.profile.bindings) { $binding in
                        HStack {
                            TextField("VARIABLE_NAME", text: $binding.variable).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Umgebungsvariable")
                            Picker("Feld", selection: SwiftUI.Binding(
                                get: { "\(binding.itemID)|\(binding.field)" },
                                set: { tag in
                                    if let field = model.usableFields.first(where: { $0.id == tag }) { binding.itemID = field.itemID; binding.field = field.field }
                                })) {
                                ForEach(model.usableFields) { field in Text(field.label).tag(field.id) }
                            }.labelsHidden().frame(width: 260).accessibilityLabel("Zugeordnetes Feld")
                            Button {
                                draft.profile.bindings.removeAll { $0.id == binding.id }
                            } label: { Image(systemName: "minus.circle") }.accessibilityLabel("Zuordnung entfernen")
                        }
                    }
                    if draft.profile.bindings.isEmpty {
                        Text("Wähle die Felder, die dieses Projekt beim Start benötigt.").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 2)
            }.frame(minHeight: 60, maxHeight: 200)
            Button("Feld zuordnen", systemImage: "plus") {
                if let first = model.usableFields.first {
                    draft.profile.bindings.append(SecretariatCore.Binding(variable: "", itemID: first.itemID, field: first.field))
                }
            }.disabled(model.usableFields.isEmpty)
            if model.usableFields.isEmpty { Text("Füge zuerst einen Eintrag mit Kennung, Geheimnis oder Datei hinzu.").font(.caption).foregroundStyle(.secondary) }
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
        }.padding(28).frame(width: 620)
        .fileImporter(isPresented: $choosingDirectory, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { draft.profile.directory = url.path }
            case .failure: error = "Der Ordner konnte nicht ausgewählt werden. Bitte erneut versuchen."
            }
        }
    }
}
