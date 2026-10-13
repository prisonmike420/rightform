import SwiftUI

/// The plugin store, a second-level page across the window, left with Back,
/// laid out as the App Store and System Settings are: the installed plugins
/// first, then the rest by category. Each row is a plugin — its icon, name
/// and what it does, and under that what's happening to it — with one
/// action at its end, in words: Install, Try Again after a failure, or
/// Open; while it installs, a progress ring that stops it. An installed
/// plugin's ⋯ menu holds the rare things: its tools and licences, and
/// Remove…. A plugin installed while the store is still in front opens by
/// itself once it's ready.
struct PluginStoreView: View {
    @Environment(ExtensionManager.self) private var extensions

    var body: some View {
        let installed = ExtensionID.ordered.filter(isInInstalled)

        FormScreen {
            if !installed.isEmpty {
                Section("Installed") {
                    ForEach(installed) { id in
                        PluginRow(id: id)
                    }
                }
            }
            ForEach(PluginCategory.allCases) { category in
                let available = category.plugins.filter { !isInInstalled($0) }
                if !available.isEmpty {
                    Section(category.title) {
                        ForEach(available) { id in
                            PluginRow(id: id)
                        }
                    }
                }
            }
            Section {
                Link("Included Tools and Licences", destination: ExtensionManager.toolsURL)
                    .help(ExtensionManager.toolsURL.absoluteString)
            }
        }
    }

    /// Installed, or being removed: it stays among the installed until it's
    /// gone.
    private func isInInstalled(_ id: ExtensionID) -> Bool {
        switch extensions.state(for: id) {
        case .installed, .removing: return true
        default: return false
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

        HStack(alignment: .center, spacing: 12) {
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
            HStack(spacing: 8) {
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

    /// The row's end: one action in words, as the App Store's Get and Open,
    /// none of them prominent in a page of many; an installed plugin's ⋯
    /// menu beside it.
    @ViewBuilder
    private func actionButtons(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installed:
            Button("Open") { settings.selection = .plugin(id) }
                .accessibilityLabel("Open \(id.title)")
                // Workspaces don't switch mid-batch.
                .disabled(model.isProcessing)
                .rowCapsule()
            MoreMenu(title: id.title) {
                Link("Included Tools and Licences", destination: ExtensionManager.toolsURL)
                Divider()
                Button("Remove \(id.title)…") { confirmingRemoval.wrappedValue = true }
            }
        case .installing:
            StopProgressButton(label: "Stop installing \(id.title)") {
                extensions.cancelInstall(id)
            }
        case .cancelling, .removing:
            ProgressView()
                .controlSize(.small)
                .frame(width: Design.Size.control, height: Design.Size.control)
        case .failed:
            Button("Try Again") {
                settings.pluginToOpen = id
                extensions.install(id)
            }
            .accessibilityLabel("Try installing \(id.title) again")
            .rowCapsule()
        case .notInstalled:
            Button("Install") {
                settings.pluginToOpen = id
                extensions.install(id)
            }
            .accessibilityLabel("Install \(id.title)")
            .rowCapsule()
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
