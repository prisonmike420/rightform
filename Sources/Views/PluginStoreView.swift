import SwiftUI

/// The plugin store, a second-level page across the window, left with Back:
/// every plugin by category as a row — its icon, name and what it does —
/// with one button at the end: + to install, a spinner while it installs,
/// ↻ after a failure, and a green check once it's installed, which opens
/// it. An installed plugin's row has Remove…. One link at the end leads to
/// the tools every plugin installs and their licences. A plugin installed
/// while the store is still in front opens by itself once it's ready.
struct PluginStoreView: View {
    var body: some View {
        Form {
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
        .formStyle(.grouped)
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
                        .foregroundStyle(state.isFailure ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                rowLink(for: state)
            }
            Spacer(minLength: 8)
            actionButton(for: state)
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

    /// Under the description: Cancel while it installs, Remove… once it's
    /// installed.
    @ViewBuilder
    private func rowLink(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installing:
            Button("Cancel") { extensions.cancelInstall(id) }
                .buttonStyle(.link)
                .font(.callout)
                .padding(.top, 2)
                .accessibilityLabel("Cancel installing \(id.title)")
        case .installed:
            Button("Remove…") { confirmingRemoval.wrappedValue = true }
                .buttonStyle(.link)
                .font(.callout)
                .padding(.top, 2)
                .accessibilityLabel("Remove \(id.title)")
        default:
            EmptyView()
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

    @ViewBuilder
    private func actionButton(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installed:
            cornerButton(systemImage: "checkmark", label: "Open \(id.title)", tint: .green) {
                settings.selection = .plugin(id)
            }
            // Workspaces don't switch mid-batch.
            .disabled(model.isProcessing)
        case .installing, .cancelling, .removing:
            ProgressView()
                .controlSize(.small)
                .frame(width: 32, height: 32)
        case .notInstalled, .failed:
            cornerButton(
                systemImage: state.isFailure ? "arrow.clockwise" : "plus",
                label: state.isFailure ? "Try installing \(id.title) again" : "Install \(id.title)",
                tint: nil
            ) {
                settings.pluginToOpen = id
                extensions.install(id)
            }
        }
    }

    /// The row's one button: a bordered square, or a green-tinted one with
    /// a check once installed.
    private func cornerButton(systemImage: String, label: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.map { AnyShapeStyle($0.opacity(0.2)) } ?? AnyShapeStyle(.background))
                }
                .overlay {
                    if tint == nil {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.separator)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
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
