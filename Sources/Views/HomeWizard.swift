import SwiftUI

// The Home wizard's screen. Its logic — the files by kind, which actions fit
// them, installing what an action needs and then running it — is in
// CompressionModel.

/// Home, once files are dropped there: what was added, by kind, and what can
/// be done with these files in particular. Choosing an action installs any
/// plugin it needs and then runs it; nothing changes before that.
struct HomeWizard: View {
    @Environment(CompressionModel.self) private var model
    @Environment(ExtensionManager.self) private var extensions

    var body: some View {
        let groups = model.waitingKinds
        let options = model.homeOptions(canRemoveDetails: extensions.state(for: .metadataCleaner).isInstalled)
        // When every option would end at the same size, it's said once with
        // the files instead of on each row.
        // Compared as shown — size and percent — so estimates a few
        // kilobytes apart count as the same.
        let all = options.main + options.more
        let shown = Set(all.compactMap { $0.estimatedBytes.map { SizeTag.label(original: model.waitingPDFBytes, estimate: $0) } })
        let sharedEstimate = !model.isEstimating && shown.count == 1 && all.allSatisfy { $0.estimatedBytes != nil }
            ? all.first?.estimatedBytes : nil

        FormScreen {
            Section {
                ForEach(groups, id: \.kind) { group in
                    // A size every option shares is shown once, on the files.
                    KindRow(
                        kind: group.kind,
                        items: group.items,
                        estimate: group.kind == .pdf ? sharedEstimate : nil
                    )
                }
            } header: {
                HStack {
                    Text("Your files")
                    Spacer()
                    Button("Clear") { model.clearAll() }
                        .buttonStyle(.borderless)
                }
            }

            Section("What would you like to do?") {
                ForEach(options.main) { option in
                    optionRow(option, showsEstimate: sharedEstimate == nil)
                }
            }

            if !options.more.isEmpty {
                Section("Other options") {
                    ForEach(options.more) { option in
                        optionRow(option, showsEstimate: sharedEstimate == nil)
                    }
                }
            }
        }
    }

    private func optionRow(_ option: HomeOption, showsEstimate: Bool) -> some View {
        let estimate = showsEstimate ? option.estimatedBytes : nil
        let original = model.waitingPDFBytes

        return ListRowButton(title: option.title, detail: option.detail) {
            if let plugin = option.plugin {
                PluginIcon(id: plugin, size: Design.Size.rowIcon)
            } else if let symbol = option.symbol {
                SymbolTile(symbol: symbol)
            }
        } accessory: {
            if let estimate, original > 0 {
                SizeTag(original: original, estimate: estimate)
            } else if option.isEstimating {
                // The size is being worked out by a trial run.
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Estimating size")
            }
            RowChevron()
        } action: {
            model.start(option.action)
        }
        .disabled(model.isProcessing)
    }
}

/// One kind of file: previews on the left, then how many, which formats and
/// how big.
private struct KindRow: View {
    let kind: FileKind
    let items: [CompressionItem]
    var estimate: Int64?

    private var detail: String {
        let formats = Dictionary(grouping: items, by: \.format).mapValues(\.count)
            .sorted { $0.value > $1.value }
            .map { format -> String in
                "\(format.key.rawValue) \(format.value)"
            }
        let bytes = items.reduce(Int64(0)) { $0 + $1.originalBytes }
        // A single format is already in the title ("1 PDF").
        let shown = formats.count > 1 ? formats : []
        return (shown + [formatBytes(bytes)]).joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Up to three previews, fanned slightly when there are several.
            ZStack(alignment: .leading) {
                ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                    FileCover(url: item.url)
                        .offset(x: CGFloat(index) * 8)
                        .zIndex(Double(-index))
                }
            }
            .frame(width: Design.Size.fileCover + CGFloat(min(items.count, 3) - 1) * 8, alignment: .leading)
            .accessibilityHidden(true)

            TitleDetail(title: kind.title(count: items.count), detail: detail)
            Spacer(minLength: 0)
            if let estimate {
                SizeTag(original: items.reduce(Int64(0)) { $0 + $1.originalBytes }, estimate: estimate)
            }
        }
    }
}
