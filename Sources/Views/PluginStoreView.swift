import SwiftUI

/// The plugin store, a second-level page across the window, left with Back:
/// every plugin by category as a row — its icon, name and what it does —
/// with its state and actions as symbols at the end, coloured by what they
/// do: Install in the accent colour; a spinner and Cancel while it installs;
/// Try Again in orange after a failure; and once it's installed a green
/// check, Remove… in red and Open. One link at the end leads to
/// the tools every plugin installs and their licences. A plugin installed
/// while the store is still in front opens by itself once it's ready.
struct PluginStoreView: View {
    var body: some View {
        FormScreen {
            ForEach(PluginCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.plugins) { id in
                        PluginRow(id: id)
                    }
                }
            }
            Section {
                Link("Included Tools and Licences", destination: ExtensionManager.toolsURL)
                    .help(ExtensionManager.toolsURL.absoluteString)
            }
        }
    }
}

private struct PluginRow: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
    // A plain State value: the @State macro needs Xcode's SwiftUIMacros plugin.
    private let confirmingRemoval = State(initialValue: false)
    let id: ExtensionID

    var body: some View {
        let state = extensions.state(for: id)

        HStack(alignment: .top, spacing: 12) {
            PluginIcon(id: id)
            VStack(alignment: .leading, spacing: 4) {
                Text(id.title)
                Text(id.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let line = statusLine(for: state) {
                    Text(line)
                        .font(.callout)
                        .foregroundStyle(state.isFailure ? AnyShapeStyle(Design.Status.failure) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: Design.Layout.buttonSpacing) {
                actionButtons(for: state)
            }
        }
        .padding(.vertical, 4)
        // Removal is undone only by installing again, which can take minutes,
        // so it is confirmed. The red button is the dialog's, as macOS does it.
        .confirmationDialog("Remove \(id.title)?", isPresented: confirmingRemoval.projectedValue) {
            Button("Remove", role: .destructive) { extensions.remove(id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removalMessage)
        }
    }

    private var removalMessage: String {
        let builtFromSource = extensions.components(for: id).contains {
            if case .builtFromSource = $0.source { return true }
            return false
        }
        let reinstall = builtFromSource
            ? "Installing it again builds it from source and can take several minutes."
            : "You can install it again from Plugins at any time."
        return "Files of these formats can’t be prepared until it’s installed again. Its settings and Homebrew packages stay. \(reinstall)"
    }

    /// The row's end, as symbols coloured by what they do; the one most
    /// likely to be wanted last.
    @ViewBuilder
    private func actionButtons(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installed:
            RowStatusIcon(systemImage: "checkmark.circle.fill", label: "\(id.title) is installed", tint: Design.Status.success)
            RowIconButton(systemImage: "trash.circle.fill", label: "Remove \(id.title)…", tint: AnyShapeStyle(Design.Status.failure)) {
                confirmingRemoval.wrappedValue = true
            }
            RowIconButton(systemImage: "arrow.up.forward.circle.fill", label: "Open \(id.title)") {
                settings.selection = .plugin(id)
            }
            // Workspaces don't switch mid-batch.
            .disabled(model.isProcessing)
        case .installing:
            ProgressView()
                .controlSize(.small)
                .frame(width: Design.Size.control, height: Design.Size.control)
            RowIconButton(systemImage: "xmark.circle.fill", label: "Cancel installing \(id.title)", tint: AnyShapeStyle(.secondary)) {
                extensions.cancelInstall(id)
            }
        case .cancelling, .removing:
            ProgressView()
                .controlSize(.small)
                .frame(width: Design.Size.control, height: Design.Size.control)
        case .failed:
            RowIconButton(systemImage: "arrow.clockwise.circle.fill", label: "Try installing \(id.title) again", tint: AnyShapeStyle(Design.Status.warning)) {
                settings.pluginToOpen = id
                extensions.install(id)
            }
        case .notInstalled:
            RowIconButton(systemImage: "arrow.down.circle.fill", label: "Install \(id.title)") {
                settings.pluginToOpen = id
                extensions.install(id)
            }
        }
    }

    private func statusLine(for state: ExtensionInstallState) -> String? {
        switch state {
        case .installing: return "Installing… This can take a few minutes."
        case .cancelling: return "Cancelling…"
        case .removing: return "Removing…"
        case .failed(let message): return message
        default: return nil
        }
    }
}
