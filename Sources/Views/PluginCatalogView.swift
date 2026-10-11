import SwiftUI

/// Every plugin, by category, like a small store: each row says what the
/// plugin does and, once installed, opens its workspace. A row opens the
/// plugin's page, where it is installed or removed and configured.
struct PluginCatalogView: View {
    var body: some View {
        // Pushed pages use the main window's navigation stack.
        Form {
            ForEach(PluginCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.plugins) { id in
                        NavigationLink(value: id) {
                            CatalogRow(id: id)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Plugins")
        .navigationDestination(for: ExtensionID.self) { id in
            PluginDetailView(id: id)
                .navigationTitle(id.title)
        }
    }
}

private struct CatalogRow: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    let id: ExtensionID

    var body: some View {
        let state = extensions.state(for: id)

        HStack(spacing: 12) {
            PluginIcon(id: id)
            VStack(alignment: .leading, spacing: 2) {
                Text(id.title)
                Text(id.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            // Installing happens on the plugin's page; here an installed
            // plugin can be opened, and the rest show nothing.
            if state.isBusy {
                ProgressView().controlSize(.small)
            } else if state.isInstalled {
                Button("Open") { settings.selection = .plugin(id) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }
}
