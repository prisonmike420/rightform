import SwiftUI
import AppKit

/// Where to?, asked for every job after choosing what to do: next to the
/// originals, a favourite or chosen folder, the clipboard or the Share
/// sheet; and what happens to the originals afterwards. Nothing is
/// remembered from the last job.
struct WhereToScreen: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings

    private var favorites: [URL] {
        settings.favoriteFolders.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    var body: some View {
        @Bindable var model = model
        let names = settings.snapshot()

        Form {
            Section {
                LabeledContent {
                    Text(model.queuedCount == 1 ? "1 file" : "\(model.queuedCount) files")
                        .foregroundStyle(.secondary)
                } label: {
                    Text(model.jobTitle).font(.headline)
                }
            }

            Section("Where to?") {
                DestinationRow(
                    title: "Next to the originals",
                    detail: "As \(names.prefix)photo\(names.suffix).jpg",
                    symbol: "folder",
                    isSelected: model.deliveryChoice == .nextToOriginals
                ) { model.deliveryChoice = .nextToOriginals }

                ForEach(favorites, id: \.self) { folder in
                    DestinationRow(
                        title: folder.lastPathComponent,
                        detail: (folder.path as NSString).abbreviatingWithTildeInPath,
                        symbol: "star",
                        isSelected: model.deliveryChoice == .folder(folder)
                    ) { model.deliveryChoice = .folder(folder) }
                }

                // A folder chosen just for this job.
                if case .folder(let folder) = model.deliveryChoice, !favorites.contains(folder) {
                    DestinationRow(
                        title: folder.lastPathComponent,
                        detail: (folder.path as NSString).abbreviatingWithTildeInPath,
                        symbol: "folder.badge.gearshape",
                        isSelected: true
                    ) {}
                }

                DestinationRow(title: "Choose Folder…", detail: "For this time only", symbol: "folder.badge.plus", isSelected: false) {
                    if let folder = chooseFolder() { model.deliveryChoice = .folder(folder) }
                }

                DestinationRow(
                    title: "Copy",
                    detail: "Paste anywhere",
                    symbol: "doc.on.doc",
                    isSelected: model.deliveryChoice == .copy
                ) { model.deliveryChoice = .copy }

                DestinationRow(
                    title: "Share…",
                    detail: "Mail, Messages, AirDrop and more",
                    symbol: "square.and.arrow.up",
                    isSelected: model.deliveryChoice == .share
                ) { model.deliveryChoice = .share }
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
        }
        .formStyle(.grouped)
        // Buttons sit below the form at the trailing edge, as in Mac forms:
        // the default action last.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormButtonBar {
                Spacer()
                Button("Back") { model.cancelDelivery() }
                    .keyboardShortcut(.cancelAction)
                Button("Start") { model.confirmDelivery() }
                    .keyboardShortcut(.defaultAction)
            }
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

/// One destination: an icon, a title and a detail line, and a checkmark
/// when selected.
private struct DestinationRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ListRowButton(title: title, detail: detail, singleLineDetail: true, isSelected: isSelected) {
            SymbolTile(symbol: symbol)
        } accessory: {
            if isSelected { RowCheckmark() }
        } action: {
            action()
        }
    }
}
