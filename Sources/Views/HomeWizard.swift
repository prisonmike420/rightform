import SwiftUI

// The Home wizard's screen. Its logic — which actions fit the files,
// installing what an action needs and then running it — is in
// CompressionModel.

/// Home, once files are dropped there, built as Where to? is: what's being
/// worked on at the top — the files, as a plain list — then what to do with
/// them as cards, and the step's buttons along the bottom: Clear, and
/// Continue once a card is chosen. More files can still be dropped anywhere
/// on the work zone or added with Add Files…. Nothing changes before
/// Continue.
struct HomeWizard: View {
    @Environment(CompressionModel.self) private var model
    @Environment(ExtensionManager.self) private var extensions
    // Plain State values: the @State macro needs Xcode's SwiftUIMacros plugin.
    private let chosen = State<CompressionModel.HomeAction?>(initialValue: nil)
    private let showsAllFiles = State(initialValue: false)

    /// How many files show before Show All, so the choices stay in sight.
    private static let fileRowsShown = 4

    var body: some View {
        let files = model.items.filter { $0.state == .queued }
        let options = model.homeOptions(canRemoveDetails: extensions.state(for: .metadataCleaner).isInstalled)
        let all = options.main + options.more
        // When every option would end at the same size, it's said once with
        // the files instead of on each card. Compared as shown — size and
        // percent — so estimates a few kilobytes apart count as the same.
        let shown = Set(all.compactMap { $0.estimatedBytes.map { SizeTag.label(original: model.waitingPDFBytes, estimate: $0) } })
        let sharedEstimate = !model.isEstimating && shown.count == 1 && all.allSatisfy { $0.estimatedBytes != nil }
            ? all.first?.estimatedBytes : nil
        // A choice that no longer fits the files counts as none.
        let selection = Binding<CompressionModel.HomeAction?>(
            get: { chosen.wrappedValue.flatMap { action in all.contains { $0.action == action } ? action : nil } },
            set: { chosen.wrappedValue = $0 }
        )

        FormScreen {
            Section {
                let visible = showsAllFiles.wrappedValue ? files : Array(files.prefix(Self.fileRowsShown))
                ForEach(visible) { item in
                    FileRow(item: item) { model.removeWaiting(item.id) }
                }
                if files.count > Self.fileRowsShown {
                    Button(showsAllFiles.wrappedValue ? "Show Fewer" : "Show All \(files.count) Files") {
                        showsAllFiles.wrappedValue.toggle()
                    }
                    .buttonStyle(.link)
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Your files")
                    Text(summary(files, sharedEstimate: sharedEstimate))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Button("Add Files…") { model.pickFiles() }
                        .buttonStyle(.borderless)
                }
            }

            Section("What would you like to do?") {
                ChoiceGrid(ids: options.main.map(\.action), selection: selection) { action in
                    if let option = options.main.first(where: { $0.action == action }) {
                        card(option, selection: selection, showsEstimate: sharedEstimate == nil)
                    }
                }
            }

            if !options.more.isEmpty {
                Section("Other options") {
                    ChoiceGrid(ids: options.more.map(\.action), selection: selection, minimumWidth: 180) { action in
                        if let option = options.more.first(where: { $0.action == action }) {
                            card(option, selection: selection, showsEstimate: sharedEstimate == nil, compact: true)
                        }
                    }
                }
            }
        } actions: {
            // Takes the files off and leaves the empty window: the way back
            // from the first step.
            Button("Clear") { model.clearAll() }
            Spacer()
            Button("Continue") {
                if let action = selection.wrappedValue { model.start(action) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selection.wrappedValue == nil || model.isProcessing)
            .help(selection.wrappedValue == nil ? "Choose what to do" : "")
        }
    }

    /// "12 files · 60 MB", and the size every option would reach when
    /// they all reach the same one.
    private func summary(_ files: [CompressionItem], sharedEstimate: Int64?) -> String {
        let bytes = files.reduce(Int64(0)) { $0 + $1.originalBytes }
        var parts = [files.count == 1 ? "1 file" : "\(files.count) files", formatBytes(bytes)]
        if let sharedEstimate {
            parts.append("~\(formatBytes(sharedEstimate)) after")
        }
        return "· " + parts.joined(separator: " · ")
    }

    private func card(
        _ option: HomeOption,
        selection: Binding<CompressionModel.HomeAction?>,
        showsEstimate: Bool,
        compact: Bool = false
    ) -> some View {
        let original = model.waitingPDFBytes
        let estimate = showsEstimate ? option.estimatedBytes : nil

        return ChoiceCard(title: option.title, isSelected: selection.wrappedValue == option.action, compact: compact) {
            let size = compact ? Design.Size.rowIcon : Design.Size.cardIcon
            if let plugin = option.plugin {
                PluginIcon(id: plugin, size: size)
            } else if let symbol = option.symbol {
                SymbolTile(symbol: symbol, size: size)
            }
        } detail: {
            if let estimate, original > 0 {
                HStack(spacing: 4) {
                    Text("~\(formatBytes(estimate))").monospacedDigit()
                    if estimate < original {
                        SavingsBadge(percent: Int((Double(original - estimate) / Double(original) * 100).rounded()))
                    } else {
                        Text("· already light")
                    }
                }
            } else if option.isEstimating {
                // The size is being worked out by a trial run.
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Estimating size")
            } else {
                Text(option.detail)
            }
        } action: {
            selection.wrappedValue = option.action
        } onDoubleClick: {
            model.start(option.action)
        }
        .disabled(model.isProcessing)
    }
}
