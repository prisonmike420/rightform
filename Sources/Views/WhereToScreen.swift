import SwiftUI
import AppKit

/// Where to?, asked for every job after choosing what to do: four
/// mutually exclusive choices as radio buttons — next to the originals, in
/// a folder, the clipboard or the Share sheet — with the folder chosen from
/// a pop-up of favourites and Choose Folder…; and what happens to the
/// originals afterwards. Nothing is remembered from the last job.
struct WhereToScreen: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    // Plain State values: the @State macro needs Xcode's SwiftUIMacros plugin.
    /// The folder last picked here, so leaving In a folder and coming back
    /// keeps it.
    private let lastFolder = State<URL?>(initialValue: nil)

    private enum Kind: Hashable { case nextToOriginals, folder, copy, share }

    /// A pop-up item: a folder, or Choose Folder…, which opens the panel.
    private enum FolderItem: Hashable { case folder(URL), choose, none }

    private var favorites: [URL] {
        settings.favoriteFolders.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// The folder In a folder uses: the chosen one, or the one picked last,
    /// or the first favourite.
    private var currentFolder: URL? {
        if case .folder(let folder) = model.deliveryChoice { return folder }
        return lastFolder.wrappedValue ?? favorites.first
    }

    /// Favourites, then a folder chosen just for this job.
    private var folders: [URL] {
        guard let current = currentFolder, !favorites.contains(current) else { return favorites }
        return favorites + [current]
    }

    var body: some View {
        @Bindable var model = model

        FormScreen {
            Section {
                LabeledContent {
                    Text(model.queuedCount == 1 ? "1 file" : "\(model.queuedCount) files")
                        .foregroundStyle(.secondary)
                } label: {
                    Text(model.jobTitle).font(.headline)
                }
            }

            Section {
                Picker("Where to?", selection: kind) {
                    Text("Next to the originals").tag(Kind.nextToOriginals)
                    Text("In a folder").tag(Kind.folder)
                    Text("Copy").tag(Kind.copy)
                    Text("Share").tag(Kind.share)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                // Choosing a folder here also chooses In a folder.
                Picker("Folder", selection: folderItem) {
                    if folders.isEmpty {
                        Text("None").tag(FolderItem.none)
                    }
                    ForEach(folders, id: \.self) { folder in
                        Text(folder.lastPathComponent).tag(FolderItem.folder(folder))
                    }
                    Divider()
                    Text("Choose Folder…").tag(FolderItem.choose)
                }
                .pickerStyle(.menu)
            } header: {
                Text("Where to?")
            } footer: {
                Text(destinationDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Section {
                Toggle("Move originals to Trash", isOn: $model.trashChoice)
                    .disabled(!model.deliveryChoice.canTrashOriginals)
            } header: {
                Text("Afterwards")
            } footer: {
                Text(model.deliveryChoice.canTrashOriginals
                     ? "Only after the new files are saved. RAW files are always kept."
                     : "Originals are kept when files are copied or shared.")
                    .foregroundStyle(.secondary)
            }
        } actions: {
            Button("Back") { model.cancelDelivery() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Start") { model.confirmDelivery() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var kind: Binding<Kind> {
        Binding(
            get: {
                switch model.deliveryChoice {
                case .nextToOriginals: return .nextToOriginals
                case .folder: return .folder
                case .copy: return .copy
                case .share: return .share
                }
            },
            set: { kind in
                switch kind {
                case .nextToOriginals: model.deliveryChoice = .nextToOriginals
                case .copy: model.deliveryChoice = .copy
                case .share: model.deliveryChoice = .share
                case .folder:
                    // With no folder yet, ask for one; Cancel keeps the last choice.
                    if let folder = currentFolder ?? chooseFolder() { use(folder) }
                }
            }
        )
    }

    private var folderItem: Binding<FolderItem> {
        Binding(
            get: { currentFolder.map(FolderItem.folder) ?? .none },
            set: { item in
                switch item {
                case .folder(let folder): use(folder)
                case .choose: if let folder = chooseFolder() { use(folder) }
                case .none: break
                }
            }
        )
    }

    private func use(_ folder: URL) {
        lastFolder.wrappedValue = folder
        model.deliveryChoice = .folder(folder)
    }

    /// What the chosen destination means, under the choices.
    private var destinationDetail: String {
        switch model.deliveryChoice {
        case .nextToOriginals:
            let names = settings.snapshot()
            return "Saved as \(names.prefix)photo\(names.suffix).jpg beside each original."
        case .folder(let folder):
            return "Saved in \((folder.path as NSString).abbreviatingWithTildeInPath)."
        case .copy:
            return "On the clipboard, ready to paste anywhere."
        case .share:
            return "The Share sheet: Mail, Messages, AirDrop and more."
        }
    }

    private func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Choose where these files go."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}
