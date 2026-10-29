import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SecretariatCore

/// A screenshot waiting for its title and note before it is sealed and stored.
struct ScreenshotDraft: Identifiable {
    let id = UUID()
    var image: Data
    var format: String
    var title = ""
    var note = ""
    /// Set when the image came from the clipboard: saving clears it there, unless something else was copied meanwhile.
    var clipboardChange: Int?
}

extension AppModel {
    func reloadScreenshots() {
        guard let library = screenshotLibrary else { return }
        do {
            let listing = try library.list()
            screenshots = listing.screenshots
            screenshotsPending = listing.pending
            screenshotsUnreadable = listing.unreadable
            thumbnails = thumbnails.filter { id, _ in listing.screenshots.contains { $0.id == id } }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Image from the clipboard (⌃⇧⌘4 puts a screenshot there), as PNG unless it came as a file.
    func screenshotFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let url = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL])?.first {
            return screenshotFromFile(url)
        }
        guard let image = NSImage(pasteboard: pasteboard), let png = image.pngData else {
            errorMessage = "The clipboard holds no image. Take a screenshot with ⌃⇧⌘4 (copies it) and try again."
            return
        }
        screenshotDraft = ScreenshotDraft(image: png, format: "png", clipboardChange: pasteboard.changeCount)
    }

    func screenshotFromFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            guard NSImage(data: data) != nil else { throw SecretariatError("\(url.lastPathComponent) is not an image.") }
            screenshotDraft = ScreenshotDraft(image: data, format: url.pathExtension.isEmpty ? "png" : url.pathExtension,
                                              title: url.deletingPathExtension().lastPathComponent)
        } catch { errorMessage = error.localizedDescription }
    }

    func chooseScreenshotFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { screenshotFromFile(url) }
    }

    @discardableResult func saveScreenshot(_ draft: ScreenshotDraft) -> Bool {
        guard let library = screenshotLibrary else { errorMessage = "Screenshots are still loading."; return false }
        do {
            let shot = try library.add(image: draft.image, format: draft.format, title: draft.title, note: draft.note)
            if let change = draft.clipboardChange, NSPasteboard.general.changeCount == change { NSPasteboard.general.clearContents() }
            reloadScreenshots(); selection = "screenshots"; selectedScreenshot = shot.id
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    /// Saves title and note on top of `shot`, the version the user edited. Returns the stored version,
    /// or nil when nothing was saved (the alert says why, e.g. another Mac changed it meanwhile).
    @discardableResult func updateScreenshot(_ shot: Screenshot, title: String, note: String) -> Screenshot? {
        guard let library = screenshotLibrary else { return nil }
        defer { reloadScreenshots() }
        do { return try library.update(shot.id, title: title, note: note, basedOn: shot.changed) }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    func deleteScreenshot(_ shot: Screenshot) {
        guard let library = screenshotLibrary else { return }
        do { try library.delete(shot.id); selectedScreenshot = nil; reloadScreenshots() }
        catch { errorMessage = error.localizedDescription }
    }

    func screenshotImage(_ shot: Screenshot) -> NSImage? {
        guard let library = screenshotLibrary else { return nil }
        do { return NSImage(data: try library.image(shot.id)) }
        catch { errorMessage = error.localizedDescription; return nil }
    }

    /// Full image, decrypted off the main thread. nil while iCloud is still downloading it.
    func loadImage(_ shot: Screenshot) async -> Result<NSImage, Error> {
        guard let library = screenshotLibrary else { return .failure(ScreenshotError.downloading) }
        let id = shot.id
        let data = await Task.detached { Result { try library.image(id) } }.value
        return data.flatMap { NSImage(data: $0).map(Result.success) ?? .failure(SecretariatError("The image can't be shown.")) }
    }

    func loadThumbnail(_ shot: Screenshot) async {
        guard thumbnails[shot.id] == nil, let library = screenshotLibrary else { return }
        let id = shot.id
        let data = await Task.detached { try? library.image(id) }.value
        if let data, let image = NSImage(data: data) { thumbnails[id] = image.thumbnail(maxSide: 96) }
    }

    func exportScreenshot(_ shot: Screenshot) {
        guard let library = screenshotLibrary else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (shot.title.isEmpty ? "Screenshot" : shot.title) + "." + shot.format
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try library.image(shot.id).write(to: url, options: .atomic) }
        catch { errorMessage = error.localizedDescription }
    }

    /// Copies the image marked as concealed (clipboard managers skip it) and clears it after 60 s,
    /// unless something else was copied meanwhile, like copied secrets.
    func copyScreenshot(_ shot: Screenshot) {
        guard let image = screenshotImage(shot) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        let count = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: .seconds(60))
            if pasteboard.changeCount == count { pasteboard.clearContents() }
        }
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    /// A small rendered copy that doesn't keep the full image alive.
    func thumbnail(maxSide: CGFloat) -> NSImage {
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let width = max(1, Int(size.width * scale * 2)), height = max(1, Int(size.height * scale * 2))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return NSImage() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: CGFloat(width) / 2, height: CGFloat(height) / 2))
        image.addRepresentation(bitmap)
        return image
    }
}

// MARK: - Middle column

struct ScreenshotList: View {
    @Bindable var model: AppModel
    let query: String

    private var shots: [Screenshot] {
        guard !query.isEmpty else { return model.screenshots }
        return model.screenshots.filter { $0.title.lowercased().contains(query) || $0.note.lowercased().contains(query) }
    }

    var body: some View {
        let shots = shots
        List(selection: $model.selectedScreenshot) {
            ForEach(shots) { shot in
                HStack(spacing: 10) {
                    Group {
                        if let thumbnail = model.thumbnails[shot.id] { Image(nsImage: thumbnail).resizable().scaledToFill() }
                        else { Image(systemName: "photo").foregroundStyle(.secondary) }
                    }
                    .frame(width: 48, height: 36).clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shot.title.isEmpty ? "Screenshot" : shot.title).lineLimit(1)
                        Text(shot.note.isEmpty ? shot.created.formatted(date: .abbreviated, time: .shortened) : shot.note)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .task { await model.loadThumbnail(shot) }
                .tag(shot.id)
                .contextMenu {
                    Button("Copy Image") { model.copyScreenshot(shot) }
                    Button("Export …") { model.exportScreenshot(shot) }
                    Button("Delete …", role: .destructive) { model.pendingScreenshotDelete = shot }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Screenshots")
        .navigationSubtitle(shots.count == 1 ? "1 screenshot" : "\(shots.count) screenshots")
        .onDeleteCommand { if let shot = model.screenshots.first(where: { $0.id == model.selectedScreenshot }) { model.pendingScreenshotDelete = shot } }
        .onPasteCommand(of: [.image, .fileURL]) { _ in model.screenshotFromClipboard() }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.screenshotFromFile(url); return true
        }
        .safeAreaInset(edge: .bottom) { footer }
        .overlay {
            if shots.isEmpty {
                if !query.isEmpty { ContentUnavailableView.search(text: query) }
                else {
                    ContentUnavailableView {
                        Label("No Screenshots Yet", systemImage: "photo.on.rectangle")
                    } description: {
                        Text("Press ⌃⇧⌘4 to copy a screenshot, then paste it here with ⌘V. Or drop an image file. Image and note are encrypted; only Secretariat can open them.")
                    } actions: {
                        Button("Paste Screenshot") { model.screenshotFromClipboard() }
                        Button("Choose File …") { model.chooseScreenshotFile() }
                    }
                }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button("Paste", systemImage: "doc.on.clipboard") { model.screenshotFromClipboard() }
                Button("Choose File …", systemImage: "folder") { model.chooseScreenshotFile() }
            }.controlSize(.small)
            Group {
                switch model.screenshotLibrary?.location {
                case .iCloud?: Label("Encrypted in iCloud Drive, synced to your Macs", systemImage: "lock.icloud")
                case .local?: Label(model.paths.isDefault ? "Only on this Mac: iCloud Drive isn't available for Secretariat" : "Test home: stored only here",
                                    systemImage: "lock.laptopcomputer")
                case nil: Label("Loading …", systemImage: "hourglass")
                }
            }.font(.caption).foregroundStyle(.secondary)
            if model.screenshotsPending > 0 {
                Text("\(model.screenshotsPending) still downloading from iCloud").font(.caption).foregroundStyle(.secondary)
            }
            if model.screenshotsUnreadable > 0 {
                Text("\(model.screenshotsUnreadable) can't be opened yet (key not synced or file damaged)").font(.caption).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.bar)
    }
}

// MARK: - Detail

struct ScreenshotDetail: View {
    let model: AppModel
    let shot: Screenshot
    @State private var title = ""
    @State private var note = ""
    /// The version the fields were loaded from or last saved as; edits are saved on top of it.
    @State private var base: Screenshot?
    @State private var image: NSImage?
    @State private var imageError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title).textFieldStyle(.plain).font(.title2.weight(.semibold))
                .onSubmit(save)
            Text("\(shot.created.formatted(date: .long, time: .shortened)) · \(shot.format.uppercased()) · \(ByteCountFormatter.string(fromByteCount: Int64(shot.byteCount), countStyle: .file))")
                .font(.caption).foregroundStyle(.secondary)
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
                        .onDrag { NSItemProvider(object: image) }
                } else if let imageError {
                    ContentUnavailableView(imageError, systemImage: "icloud.and.arrow.down").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            Text("Note").font(.headline)
            TextEditor(text: $note).font(.body).frame(minHeight: 80, maxHeight: 160)
                .scrollContentBackground(.hidden).padding(6)
                .background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("Save Note", action: save).keyboardShortcut("s").disabled(!edited)
                Spacer()
                Button("Copy Image") { model.copyScreenshot(shot) }
                Button("Export …") { model.exportScreenshot(shot) }
                Button("Delete …", role: .destructive) { model.pendingScreenshotDelete = shot }
            }
        }
        .padding(20)
        .onAppear { adopt(shot) }
        // Another Mac (or a reload) brought a newer version: take it unless the user is in the middle of an edit.
        .onChange(of: shot.changed) { _, _ in if !edited { adopt(shot) } }
        .task {
            switch await model.loadImage(shot) {
            case .success(let loaded): image = loaded
            case .failure(let error): imageError = error.localizedDescription
            }
        }
        .onDisappear(perform: save)
    }

    private var edited: Bool { base.map { title != $0.title || note != $0.note } ?? false }
    private func adopt(_ version: Screenshot) { base = version; title = version.title; note = version.note }
    private func save() {
        guard edited, let base else { return }
        if let stored = model.updateScreenshot(base, title: title, note: note) { self.base = stored }
        else if let current = model.screenshots.first(where: { $0.id == base.id }) { adopt(current) }
    }
}

// MARK: - New screenshot

struct ScreenshotComposer: View {
    let model: AppModel
    @State var draft: ScreenshotDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Screenshot").font(.title2.weight(.semibold))
            if let image = NSImage(data: draft.image) {
                Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 320)
                    .background(Color(nsColor: .controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
            }
            TextField("Title, e.g. Stripe webhook secret", text: $draft.title)
            Text("Note").font(.headline)
            TextEditor(text: $draft.note).frame(height: 90).scrollContentBackground(.hidden).padding(6)
                .background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
            Text("Encrypted before it is stored. Only Secretariat on your Macs can open it; no program or agent gets it.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { if model.saveScreenshot(draft) { dismiss() } }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 560)
    }
}
