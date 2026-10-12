import SwiftUI

/// Every plugin, by category, like a small store, in a sheet over the
/// window: each row says what the plugin does and installs it in place. An
/// installed plugin opens in its workspace, where the panel on the right
/// manages and configures it. Done or Esc closes the sheet; an install
/// carries on without it.
struct PluginStoreView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ForEach(PluginCategory.allCases) { category in
                    Section(category.title) {
                        ForEach(category.plugins) { id in
                            CatalogRow(id: id)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Done") { settings.showsPluginStore = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(minWidth: 460, idealWidth: 540, minHeight: 420, idealHeight: 600)
        .navigationTitle("Plugins")
    }
}

private struct CatalogRow: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
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
            Button("Open") {
                settings.showsPluginStore = false
                settings.selection = .plugin(id)
            }
            .accessibilityLabel("Open \(id.title)")
            // Workspaces don't switch mid-batch.
            .disabled(model.isProcessing && settings.selection != .plugin(id))
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
