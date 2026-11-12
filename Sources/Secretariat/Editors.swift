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
    @FocusState private var nameFocused: Bool
    @State private var showRead = false
    @Environment(\.dismiss) private var dismiss
    static let providers = ["openai", "anthropic", "deepseek", "google-gemini", "mistral", "groq", "openrouter", "elevenlabs",
                            "resend", "stripe", "supabase", "cloudflare", "github", "expo", "apple-developer", "app-store-connect"]

    private var isNew: Bool { draft.existing == nil }
    private var kinds: [Template] { model.catalog.all.filter { $0.id != Capture.kind } }

    var body: some View {
        Form {
            Section { header }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            if let note = draft.readNote { Section { readFromScreenshot(note) } }
            if isNew {
                Section {
                    Picker(selection: SwiftUI.Binding(get: { draft.kind }, set: { id in
                        if let t = kinds.first(where: { $0.id == id }) { draft.template = t }
                    })) {
                        ForEach(kinds) { t in Label(t.title, systemImage: t.symbol).tag(t.id) }
                    } label: { Text("Kind") }
                    .accessibilityLabel("Kind")
                } footer: {
                    if !draft.template.explanation.isEmpty { Text(draft.template.explanation).foregroundStyle(.secondary) }
                }
            }
            Section {
                ForEach(draft.template.fields, id: \.name) { spec in
                    if spec.name != "env_var", let index = draft.fields.firstIndex(where: { $0.name == spec.name }) {
                        valueRow(spec.label, $draft.fields[index], prompt: spec.required ? "Required" : (spec.prompt.isEmpty ? "Optional" : spec.prompt))
                    }
                }
            } header: { Text(isNew ? "Values" : draft.template.title) } footer: {
                Text(isNew ? "Secrets reach programs only through Secretariat. “Only for me” never leaves the app."
                           : "Leave a secret empty to keep its current value.").foregroundStyle(.secondary)
            }
            if draft.template.fields.contains(where: { $0.envSuffix != nil }) && !draft.customPath {
                Section {
                    Toggle("Available to all tools", isOn: $draft.everywhere).accessibilityLabel("Available to all tools")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(everywhereHint).foregroundStyle(.secondary)
                        ForEach(everywhereConflicts, id: \.self) { Text($0).foregroundStyle(.orange) }
                    }
                }
            }
            Section {
                Toggle("Ask with Touch ID before a program uses it", isOn: $draft.approval)
                    .accessibilityLabel("Ask with Touch ID before a program uses it")
            } footer: {
                Text("Agents can switch this on; only you can switch it off.")
                    .foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("More Options", isExpanded: $advanced) { advancedSection }
            }
        }
        .formStyle(.grouped)
        .onAppear { if isNew && !draft.customPath { nameFocused = true } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if model.saveItem(draft) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.missing.isEmpty || draft.fields.isEmpty)
                .help(draft.missing.isEmpty ? "" : "Still missing: \(draft.missing.joined(separator: ", "))")
            }
            if let existing = draft.existing {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete …", role: .destructive) { dismiss(); model.pendingDelete = existing }
                }
            }
        }
        // Resizable sheet: text wraps instead of being cut off, and the window can be dragged larger.
        .frame(minWidth: 520, idealWidth: 560, maxWidth: .infinity, minHeight: 420, idealHeight: 560, maxHeight: .infinity)
        .background(ResizableSheet())
        .fileImporter(isPresented: SwiftUI.Binding(get: { importingField != nil }, set: { if !$0 { importingField = nil } }),
                      allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard let id = importingField, let index = draft.fields.firstIndex(where: { $0.id == id }) else { return }
            importingField = nil
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                guard data.count <= 250 * 1024 else { error = "Files can be at most 250 KB."; return }
                draft.fields[index].fileData = data.base64EncodedString()
                draft.fields[index].fileName = url.lastPathComponent
            } catch { self.error = "The file could not be read. Please try again." }
        }
        .onChange(of: draft.kind) { _, _ in
            let untouched = draft.fields.allSatisfy { $0.value.isEmpty && $0.fileData == nil }
            if draft.existing == nil && untouched { draft.fields = ItemDraft.fields(draft.template) }
            // Read from a screenshot: the new kind's fields, keeping values of the same name; the read key moves into its secret field.
            else if draft.existing == nil && draft.readNote != nil {
                let old = draft.fields
                draft.fields = ItemDraft.fields(draft.template)
                for index in draft.fields.indices { draft.fields[index].value = old.first { $0.name == draft.fields[index].name }?.value ?? "" }
                if let key = old.first(where: { $0.kind == .secret && !$0.value.isEmpty })?.value, !draft.fields.contains(where: { $0.value == key }),
                   let index = draft.fields.firstIndex(where: { $0.kind == .secret && $0.value.isEmpty }) { draft.fields[index].value = key }
            }
            if draft.existing == nil && draft.template.identity && draft.provider.isEmpty { draft.provider = "moinsen" }
        }
    }

    /// Passwords-style head: the kind's icon, the name as a title line, the purpose below, where it is saved underneath.
    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            KindIcon(symbol: draft.template.symbol, color: draft.template.color, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                if draft.customPath {
                    TextField("Location", text: $draft.typedPath, prompt: Text("account/name"))
                        .font(.title2.weight(.semibold)).textFieldStyle(.plain).labelsHidden()
                } else {
                    HStack(spacing: 6) {
                        TextField(draft.template.identity ? "Organisation" : "Provider", text: $draft.provider,
                                  prompt: Text(draft.template.identity ? "Organisation (required)" : "Provider, e.g. OpenAI (required)"))
                            .font(.title2.weight(.semibold)).textFieldStyle(.plain).labelsHidden().focused($nameFocused)
                        if !draft.template.identity {
                            Menu {
                                ForEach(Self.providers, id: \.self) { p in Button(p) { draft.provider = p } }
                            } label: {
                                Image(systemName: "chevron.down.circle.fill").foregroundStyle(.secondary).accessibilityLabel("Choose provider")
                            }
                                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Known providers")
                        }
                    }
                    if !draft.template.identity {
                        TextField("Project", text: $draft.label, prompt: Text("Project or purpose (optional)"))
                            .textFieldStyle(.plain).labelsHidden().foregroundStyle(.secondary)
                    }
                }
                Text(draft.path.isEmpty ? " " : draft.path)
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.tertiary)
                    .accessibilityLabel(draft.path.isEmpty ? "Not saved yet" : "Saved as \(draft.path)")
                if draft.providerIsPath {
                    HStack(alignment: .firstTextBaseline) {
                        Label("That looks like a whole location. Provider and project are separate.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                        Button("Split") { draft.splitProvider(); if draft.customPath { advanced = true } }.controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var everywhereVariables: [String] { draft.template.fields.compactMap(draft.variable) }
    private var everywhereHint: String {
        let names = draft.envPrefix.isEmpty ? "PROVIDER_API_KEY"
            : (everywhereVariables.isEmpty ? "a variable" : everywhereVariables.joined(separator: ", "))
        return "Tools you start through the profile “werkzeuge” (wrangler, gh, eas …) get it as \(names) in every folder."
    }
    /// Variables that the profile "werkzeuge" already gives to another item; saving would replace them.
    private var everywhereConflicts: [String] {
        guard let werkzeuge = model.configuration.profiles.first(where: { $0.name == "werkzeuge" }) else { return [] }
        return everywhereVariables.compactMap { name in
            guard let binding = werkzeuge.bindings.first(where: { $0.variable == name }), binding.itemID != draft.existing?.id else { return nil }
            let other = model.item(binding.itemID)?.path ?? "another item"
            return "\(name) currently comes from \(other). Turning this on replaces it for every tool."
        }
    }

    /// How a screenshot was read, and the read secrets on request, to compare with the screenshot character by character.
    private func readFromScreenshot(_ note: String) -> some View {
        let secrets = draft.fields.indices.filter { draft.fields[$0].kind.isSecret && !draft.fields[$0].value.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            Label(note, systemImage: "text.viewfinder").fixedSize(horizontal: false, vertical: true)
            if !secrets.isEmpty {
                if secrets.contains(where: { ScreenshotReading.hasLookAlikes(draft.fields[$0].value) }) {
                    Label("Text recognition can mix up characters like 0 and O, 1, l and I, or k and K. Compare the marked characters with the screenshot.",
                          systemImage: "exclamationmark.triangle").foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Toggle("Show read values", isOn: $showRead).toggleStyle(.checkbox)
                if showRead {
                    ForEach(secrets, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(draft.template.spec(draft.fields[index].name)?.label ?? draft.fields[index].name).font(.caption).foregroundStyle(.secondary)
                            Text(Self.markingLookAlikes(draft.fields[index].value)).font(.body.monospaced()).textSelection(.disabled)
                                .fixedSize(horizontal: false, vertical: true)
                            TextField("", text: $draft.fields[index].value).font(.body.monospaced()).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Correct the read value")
                        }
                    }
                }
            }
        }
        .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in showRead = false }
    }

    /// The value with characters text recognition mixes up in orange and underlined.
    static func markingLookAlikes(_ value: String) -> AttributedString {
        var marked = AttributedString()
        for character in value {
            var part = AttributedString(String(character))
            if ScreenshotReading.isLookAlike(character) { part.foregroundColor = .orange; part.underlineStyle = .single }
            marked += part
        }
        return marked
    }

    @ViewBuilder private var advancedSection: some View {
        if let index = draft.fields.firstIndex(where: { $0.name == "env_var" }), draft.template.spec("env_var") != nil {
            TextField("Variable name", text: $draft.fields[index].value,
                      prompt: Text(draft.envPrefix.isEmpty ? "<PROVIDER>_API_KEY" : "\(draft.envPrefix)_API_KEY"))
            Text("Only with “Available to all tools”. Set it when a tool expects a fixed name; never reuse one a tool already uses for something else (CLOUDFLARE_API_TOKEN overrides wrangler’s own login).")
                .font(.caption).foregroundStyle(.secondary)
        }
        TextField("Expires", text: $draft.expires, prompt: Text("YYYY-MM-DD"))
        TextField("Source", text: $draft.source, prompt: Text("e.g. platform.openai.com"))
        Toggle("Set location yourself", isOn: SwiftUI.Binding(get: { draft.customPath }, set: { on in
            if on { draft.typedPath = draft.path }
            draft.customPath = on
        }))
        ForEach($draft.fields) { $field in
            if draft.template.spec(field.name) == nil {
                HStack {
                    TextField("Field", text: $field.name, prompt: Text("field_name")).labelsHidden().frame(width: 130)
                        .accessibilityLabel("Field name")
                    Picker("Field kind", selection: $field.kind) { ForEach(FieldKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                        .labelsHidden().frame(width: 120)
                    valueControl($field, prompt: "")
                    Button { draft.fields.removeAll { $0.id == field.id } } label: { Image(systemName: "minus.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.red).accessibilityLabel("Remove field")
                }
            }
        }
        Button("Add Field", systemImage: "plus.circle.fill") { draft.fields.append(FieldDraft(kind: .secret)) }
            .buttonStyle(.borderless)
    }

    /// One labelled value row of the grouped form.
    @ViewBuilder private func valueRow(_ label: String, _ field: SwiftUI.Binding<FieldDraft>, prompt: String) -> some View {
        let isStored = field.wrappedValue.storedName != nil
        switch field.wrappedValue.kind {
        case .identifier:
            TextField(label, text: field.value, prompt: Text(prompt)).accessibilityLabel(label)
        case .secret, .personal:
            SecureField(label, text: field.value, prompt: Text(isStored ? "Unchanged" : prompt)).accessibilityLabel(label)
        case .file:
            LabeledContent(label) {
                HStack {
                    Text(field.wrappedValue.fileName ?? "No file").foregroundStyle(.secondary).lineLimit(1)
                    Button("Choose File …") { importingField = field.wrappedValue.id }
                }
            }
        }
    }

    @ViewBuilder private func valueControl(_ field: SwiftUI.Binding<FieldDraft>, prompt: String) -> some View {
        let isStored = field.wrappedValue.storedName != nil
        switch field.wrappedValue.kind {
        case .identifier:
            TextField("", text: field.value, prompt: Text(prompt)).textFieldStyle(.roundedBorder).accessibilityLabel("Identifier value")
        case .secret, .personal:
            SecureField("", text: field.value, prompt: Text(isStored ? "unchanged" : prompt)).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Secret value")
        case .file:
            HStack {
                Text(field.wrappedValue.fileName ?? "No file").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                Button("Choose File …") { importingField = field.wrappedValue.id }
            }.frame(maxWidth: .infinity)
        }
    }
}

/// SwiftUI sheets on macOS 14 have a fixed size; this lets the sheet window be dragged larger.
private struct ResizableSheet: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.styleMask.insert(.resizable) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ProfileEditor: View {
    let model: AppModel
    @State var draft: ProfileDraft
    @State private var error: String?
    @State private var choosingDirectory = false
    @Environment(\.dismiss) private var dismiss

    private var isNew: Bool { !model.configuration.profiles.contains { $0.id == draft.profile.id } }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    KindIcon(symbol: "folder.fill", color: .blue, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $draft.profile.name, prompt: Text("Project name"))
                            .font(.title2.weight(.semibold)).textFieldStyle(.plain).labelsHidden()
                        Text(draft.profile.directory.isEmpty ? "No folder chosen yet" : draft.profile.directory.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }.padding(.vertical, 6)
            }
            Section {
                LabeledContent("Folder") { Button("Choose …") { choosingDirectory = true } }
                TextField("Start command", text: $draft.profile.command, prompt: Text("e.g. pnpm dev"))
            } footer: {
                Text("The start command holds no key values and runs only when you launch it.").foregroundStyle(.secondary)
            }
            Section {
                ForEach($draft.profile.bindings) { $binding in
                    HStack {
                        TextField("Variable", text: $binding.variable, prompt: Text("VARIABLE_NAME")).labelsHidden()
                            .font(.system(.body, design: .monospaced)).accessibilityLabel("Environment variable")
                        Picker("Field", selection: SwiftUI.Binding(
                            get: { "\(binding.itemID)|\(binding.field)" },
                            set: { tag in
                                if let field = model.usableFields.first(where: { $0.id == tag }) { binding.itemID = field.itemID; binding.field = field.field }
                            })) {
                            ForEach(model.usableFields) { field in Text(field.label).tag(field.id) }
                        }.labelsHidden().frame(width: 240).accessibilityLabel("Bound field")
                        Button { draft.profile.bindings.removeAll { $0.id == binding.id } } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless).foregroundStyle(.red).accessibilityLabel("Remove binding")
                    }
                }
                Button("Add Value", systemImage: "plus.circle.fill") {
                    if let first = model.usableFields.first {
                        draft.profile.bindings.append(SecretariatCore.Binding(variable: "", itemID: first.itemID, field: first.field))
                    }
                }.buttonStyle(.borderless).disabled(model.usableFields.isEmpty)
            } header: { Text("Values") } footer: {
                Text(model.usableFields.isEmpty ? "First add an item with an identifier, secret or file."
                                                : "The values this project gets when it starts through Secretariat.").foregroundStyle(.secondary)
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save") {
                    if model.saveProfile(draft.profile, expectedRevision: draft.revision) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.disabled(draft.profile.name.isEmpty || draft.profile.directory.isEmpty)
            }
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 440, idealHeight: 540)
        .fileImporter(isPresented: $choosingDirectory, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { draft.profile.directory = url.path }
            case .failure: error = "The folder could not be chosen. Please try again."
            }
        }
    }
}

struct TemplateEditor: View {
    let model: AppModel
    @State var draft: TemplateDraft
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isNew ? "New Template" : "Edit Template").font(.title2.weight(.semibold))
            Form {
                if draft.isNew {
                    LabeledContent("ID") {
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("", text: $draft.template.id, prompt: Text("bank-account")).accessibilityLabel("ID")
                            Text("lowercase, e.g. bank-account").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    LabeledContent("ID") { Text(draft.template.id).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
                }
                TextField("Title", text: $draft.template.title, prompt: Text("Bank account"))
                LabeledContent("Symbol") {
                    HStack {
                        TextField("", text: $draft.template.symbol, prompt: Text("SF Symbol name, e.g. banknote")).accessibilityLabel("Symbol")
                        Image(systemName: draft.template.symbol.isEmpty ? "square.dashed" : draft.template.symbol)
                            .font(.title3).foregroundStyle(.tint).frame(width: 28)
                    }
                }
                TextField("Explanation", text: $draft.template.explanation, prompt: Text("What is this for?"), axis: .vertical).lineLimit(1...3)
                Toggle("Identity — export to company.md (who you work as)", isOn: $draft.template.identity)
            }.textFieldStyle(.roundedBorder)
            Text("Fields").font(.headline)
            ScrollView {
                VStack(spacing: 8) {
                    if !draft.fields.isEmpty {
                        HStack(spacing: 6) {
                            Text("Name").frame(width: 110, alignment: .leading)
                            Text("Label").frame(width: 130, alignment: .leading)
                            Text("Kind").frame(width: 110, alignment: .leading)
                            Text("Req.").frame(width: 34, alignment: .leading)
                            Text("Prompt").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Env suffix").frame(width: 90, alignment: .leading)
                            Spacer().frame(width: 76)
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach($draft.fields) { $row in
                        HStack(spacing: 6) {
                            TextField("", text: $row.spec.name, prompt: Text("field_name")).frame(width: 110).accessibilityLabel("Field name")
                            TextField("", text: $row.spec.label, prompt: Text("Label")).frame(width: 130).accessibilityLabel("Field label")
                            Picker("Field kind", selection: $row.spec.kind) { ForEach(FieldKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                                .labelsHidden().frame(width: 110)
                            Toggle("Required", isOn: $row.spec.required).labelsHidden().frame(width: 34)
                            TextField("", text: $row.spec.prompt, prompt: Text("optional")).accessibilityLabel("Prompt")
                            TextField("", text: SwiftUI.Binding(get: { row.spec.envSuffix ?? "" }, set: { row.spec.envSuffix = $0.isEmpty ? nil : $0 }),
                                      prompt: Text("optional")).frame(width: 90).accessibilityLabel("Env suffix")
                            HStack(spacing: 2) {
                                Button { move(row.id, by: -1) } label: { Image(systemName: "chevron.up") }
                                    .disabled(draft.fields.first?.id == row.id).accessibilityLabel("Move up")
                                Button { move(row.id, by: 1) } label: { Image(systemName: "chevron.down") }
                                    .disabled(draft.fields.last?.id == row.id).accessibilityLabel("Move down")
                                Button { draft.fields.removeAll { $0.id == row.id } } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Remove field")
                            }.buttonStyle(.borderless).frame(width: 76)
                        }.textFieldStyle(.roundedBorder)
                    }
                    if draft.fields.isEmpty {
                        Text("No fields yet. Items of this template then only get the fields you add per item.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.vertical, 2)
            }.frame(minHeight: 80, maxHeight: 280)
            Button("Add Field", systemImage: "plus") { draft.fields.append(FieldSpecDraft(spec: FieldSpec("", "", .identifier))) }
            Text("Env suffix: with “Give to all tools” the field becomes <PROVIDER>[_<PROJECT>]_<suffix>, e.g. OPENAI_API_KEY.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
        }.padding(28).frame(width: 860)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button(draft.isNew ? "Add" : "Save") {
                    if model.saveTemplate(draft) { dismiss() }
                    else { error = model.errorMessage; model.errorMessage = nil }
                }.keyboardShortcut(.defaultAction)
                    .disabled(draft.template.id.isEmpty || draft.template.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = draft.fields.firstIndex(where: { $0.id == id }), draft.fields.indices.contains(index + offset) else { return }
        draft.fields.swapAt(index, index + offset)
    }
}
