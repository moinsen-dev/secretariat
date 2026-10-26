import AppKit
import SwiftUI
import SecretariatCore
import UniformTypeIdentifiers

struct ItemEditor: View {
    let model: AppModel
    @State var draft: ItemDraft
    @State private var error: String?
    @State private var importingField: UUID?
    @State private var advanced = false
    @Environment(\.dismiss) private var dismiss
    static let providers = ["openai", "anthropic", "deepseek", "google-gemini", "mistral", "groq", "openrouter", "elevenlabs",
                            "resend", "stripe", "supabase", "cloudflare", "github", "expo", "apple-developer", "app-store-connect"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.existing == nil ? "Eintrag hinzufügen" : "Eintrag bearbeiten").font(.title2.bold())
            if draft.existing == nil { kindPicker }
            Form {
                if !draft.customPath {
                    LabeledContent("Anbieter oder Konto") {
                        HStack {
                            TextField("", text: $draft.provider, prompt: Text("z. B. openai, deepseek, cloudflare"))
                            Menu { ForEach(Self.providers, id: \.self) { p in Button(p) { draft.provider = p } } } label: { Image(systemName: "chevron.down") }
                                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Anbieter auswählen")
                        }
                    }
                    TextField("Zusatz (optional)", text: $draft.label, prompt: Text("leer = Hauptschlüssel, sonst z. B. Projektname"))
                }
                ForEach(draft.kind.fields, id: \.name) { spec in
                    if let index = draft.fields.firstIndex(where: { $0.name == spec.name }) {
                        LabeledContent(spec.label + (spec.required ? " *" : "")) { valueControl($draft.fields[index], prompt: spec.prompt) }
                    }
                }
                if draft.kind.fields.contains(where: { $0.envSuffix != nil }) && !draft.customPath {
                    Toggle(isOn: $draft.everywhere) {
                        Text("In allen Projekten und Werkzeugen nutzbar")
                        Text(everywhereHint).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.textFieldStyle(.roundedBorder)
            .onChange(of: draft.kind) { _, kind in
                let untouched = draft.fields.allSatisfy { $0.value.isEmpty && $0.fileData == nil }
                if draft.existing == nil && untouched { draft.fields = ItemDraft.template(kind) }
            }
            .onChange(of: draft.provider) { _, _ in
                if draft.kind == .api, let i = draft.fields.firstIndex(where: { $0.name == "env_var" }) {
                    draft.fields[i].value = draft.envPrefix.isEmpty ? "" : "\(draft.envPrefix)_API_KEY"
                }
            }
            Text(draft.path.isEmpty ? "Ablage: –" : "Ablage: \(draft.path)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            DisclosureGroup("Erweitert", isExpanded: $advanced) { advancedSection }
            Text(draft.existing == nil
                 ? "Kennungen sind lesbar. Geheimnisse und Dateien bekommen nur Programme, „Nur für mich“ bleibt in der App."
                 : "Lässt du ein geheimes Feld leer, bleibt sein bisheriger Wert erhalten.")
                .font(.callout).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                if let existing = draft.existing {
                    Button("Löschen …", role: .destructive) { dismiss(); model.pendingDelete = existing }
                }
                if !draft.missing.isEmpty { Text("Fehlt noch: \(draft.missing.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Speichern") {
                    if model.saveItem(draft) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(!draft.missing.isEmpty || draft.fields.isEmpty)
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

    private var everywhereHint: String {
        let names = draft.kind.fields.compactMap { spec in spec.envSuffix.map { _ in spec } }.map { spec in
            spec.name == "api_key" ? (draft.field("env_var")?.value.isEmpty == false ? draft.field("env_var")!.value : "\(draft.envPrefix)_API_KEY")
                                   : "\(draft.envPrefix)_\(spec.envSuffix!)"
        }
        return "Als \(names.joined(separator: ", ")) im Profil „werkzeuge“ – `secretariat run werkzeuge -- …` in jedem Ordner."
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Was speicherst du?").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(ItemKind.allCases, id: \.self) { kind in
                    Button { draft.kind = kind } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.symbol).font(.title3)
                            Text(kind.title).font(.caption).multilineTextAlignment(.center).lineLimit(2)
                        }.frame(maxWidth: .infinity, minHeight: 48).padding(6)
                        .background(draft.kind == kind ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(draft.kind == kind ? Color.accentColor : .clear))
                    }.buttonStyle(.plain).accessibilityLabel(kind.title)
                }
            }
            Text(draft.kind.explanation).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Ablage selbst festlegen", isOn: SwiftUI.Binding(get: { draft.customPath }, set: { on in
                if on { draft.typedPath = draft.path }
                draft.customPath = on
            }))
            if draft.customPath {
                TextField("Ablage", text: $draft.typedPath, prompt: Text("moinsen/konto/name")).textFieldStyle(.roundedBorder)
            }
            TextField("Herkunft", text: $draft.source, prompt: Text("Wo kommt der Wert her? z. B. platform.openai.com")).textFieldStyle(.roundedBorder)
            TextField("Läuft ab", text: $draft.expires, prompt: Text("JJJJ-MM-TT, optional")).textFieldStyle(.roundedBorder)
            Text("Weitere Felder").font(.subheadline.bold())
            ForEach($draft.fields) { $field in
                if draft.kind.spec(field.name) == nil {
                    HStack {
                        TextField("feldname", text: $field.name).textFieldStyle(.roundedBorder).frame(width: 140).accessibilityLabel("Feldname")
                        Picker("Feldart", selection: $field.kind) { ForEach(FieldKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                            .labelsHidden().frame(width: 130)
                        valueControl($field, prompt: "")
                        Button { draft.fields.removeAll { $0.id == field.id } } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).accessibilityLabel("Feld entfernen")
                    }
                }
            }
            Button("Feld hinzufügen", systemImage: "plus") { draft.fields.append(FieldDraft(kind: .secret)) }
        }.padding(.top, 6)
    }

    @ViewBuilder private func valueControl(_ field: SwiftUI.Binding<FieldDraft>, prompt: String) -> some View {
        let isStored = field.wrappedValue.storedName != nil
        switch field.wrappedValue.kind {
        case .identifier:
            TextField("", text: field.value, prompt: Text(prompt)).textFieldStyle(.roundedBorder).accessibilityLabel("Wert der Kennung")
        case .secret, .personal:
            SecureField("", text: field.value, prompt: Text(isStored ? "unverändert" : prompt)).textFieldStyle(.roundedBorder)
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
