import SwiftUI

/// Every plugin, by category, like a small store: each row says what the
/// plugin does and installs it in place. An installed plugin opens in its
/// workspace, where the panel on the right manages and configures it.
struct PluginCatalogView: View {
    @Environment(ExtensionManager.self) private var extensions

    var body: some View {
        Form {
            ForEach(PluginCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.plugins) { id in
                        CatalogRow(id: id)
                    }
                }
            }

            // Homebrew is asked about every installed plugin at once, so the
            // check is offered once, here; each plugin's panel lists its own
            // newer versions.
            if ExtensionID.allCases.contains(where: { extensions.state(for: $0).isInstalled && !extensions.formulae(for: $0).isEmpty }) {
                Section {
                    HStack {
                        Text(extensions.isCheckingFormulae ? "Checking for updates…" : lastCheckText)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Button("Check Now") { extensions.checkFormulaeUpdates(force: true) }
                            .disabled(extensions.isCheckingFormulae)
                    }
                } header: {
                    Text("Engine Updates")
                } footer: {
                    Text("Updates come from Homebrew. Stou checks once a week.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Plugins")
    }

    private var lastCheckText: String {
        guard let last = extensions.lastFormulaeCheck else { return "Not checked yet." }
        return "Checked \(last.formatted(date: .abbreviated, time: .omitted))."
    }
}

private struct CatalogRow: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
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
                // Once installed, the plugin's panel links to its tools.
                if !state.isInstalled {
                    Link("Included Tools and Licences", destination: extensions.toolsURL(for: id))
                        .font(.callout)
                        .help(extensions.toolsURL(for: id).absoluteString)
                }
            }
            Spacer(minLength: 8)
            actionButton(for: state)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func actionButton(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installed:
            Button("Open") { settings.selection = .plugin(id) }
                .accessibilityLabel("Open \(id.title)")
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Button("Cancel") { extensions.cancelInstall(id) }
                    .accessibilityLabel("Cancel installing \(id.title)")
            }
        case .cancelling, .removing:
            ProgressView().controlSize(.small)
        case .notInstalled, .failed:
            Button(state.isFailure ? "Try Again" : "Install") {
                settings.pluginToOpen = id
                extensions.install(id)
            }
            .accessibilityLabel("Install \(id.title)")
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
