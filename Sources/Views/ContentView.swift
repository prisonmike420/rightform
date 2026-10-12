import SwiftUI
import UniformTypeIdentifiers

/// The main window: a narrow rail that is always there — Home, the Plugins
/// catalogue, each installed plugin's workspace, and Settings at the bottom —
/// and the chosen page beside it.
struct ContentView: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        @Bindable var model = model

        HStack(spacing: 0) {
            AppRail()
            NavigationStack {
                detail
            }
        }
        // Choosing a workspace switches what dropped files are for.
        .onChange(of: settings.selection) { _, selection in
            switch selection {
            case .workspace: model.useWorkspace(nil)
            case .plugin(let id): model.useWorkspace(id)
            case .plugins, .settings: break
            }
        }
        // Launch already checked; this one waits a day. A release found earlier is remembered.
        .task { updates.check() }
        // The plugins' Homebrew packages are checked at most once a week.
        .task { extensions.checkFormulaeUpdates() }
        .onChange(of: extensions.states, initial: true) {
            settings.coerceToInstalledCapabilities(extensions)
            openInstalledPlugin()
            // A plugin removed while its workspace is open falls back to Home.
            if case .plugin(let id) = settings.selection, !extensions.state(for: id).isInstalled,
               !extensions.state(for: id).isBusy {
                settings.selection = .workspace
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
            model.acceptDrop(providers: providers)
        }
        // The alert's title states the problem itself, not the app's name.
        .alert(model.alertMessage ?? "", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK") { model.alertMessage = nil }
        }
        .sheet(isPresented: Binding(
            get: { model.pdfReviewItemID != nil },
            set: { if !$0 { model.finishPDFSimilarReview() } }
        )) {
            if let itemID = model.pdfReviewItemID {
                PDFDuplicateReviewView(itemID: itemID)
            }
        }
    }

    /// A plugin installed from the catalogue opens with its panel showing,
    /// so its settings are found where they'll be used. Only while the
    /// catalogue is still in front: an install takes minutes, and Stou
    /// doesn't pull someone out of what they went on to do.
    private func openInstalledPlugin() {
        guard let id = settings.pluginToOpen else { return }
        let state = extensions.state(for: id)
        guard !state.isBusy else { return }
        settings.pluginToOpen = nil
        guard state.isInstalled, settings.selection == .plugins, !model.isProcessing else { return }
        settings.selection = .plugin(id)
        settings.showsInspector = true
    }

    @ViewBuilder
    private var detail: some View {
        switch settings.selection {
        case .plugins:
            PluginCatalogView()
        case .settings:
            SettingsPage()
        case .workspace, .plugin:
            // Home and each plugin share the workspace; the model knows which.
            WorkspaceView()
        }
    }
}

/// The rail on the left, always visible: Home and Plugins as symbols, then
/// the installed plugins as their colour tiles, pinned ones first; at the
/// bottom an update button while a newer version exists, and Settings. Each
/// name shows as a tooltip and is read by VoiceOver.
struct AppRail: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    RailItem(title: "Home", isSelected: settings.selection == .workspace) {
                        Image(systemName: "plus").font(.system(size: 16))
                    } action: {
                        settings.selection = .workspace
                    }
                    .disabled(model.isProcessing && settings.selection != .workspace)

                    RailItem(title: "Plugins", isSelected: settings.selection == .plugins) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 16))
                    } action: {
                        settings.selection = .plugins
                    }

                    if !pinned.isEmpty || !unpinned.isEmpty {
                        Divider().frame(width: 24).padding(.vertical, 4)
                    }
                    ForEach(pinned) { id in pluginItem(id) }
                    if !pinned.isEmpty && !unpinned.isEmpty {
                        Divider().frame(width: 16).padding(.vertical, 2)
                    }
                    ForEach(unpinned) { id in pluginItem(id) }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)

            // Stou and the plugins update together.
            if let title = updates.updateTitle(extensions) {
                RailItem(title: title, isSelected: false) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .tint)
                } action: {
                    // Settings shows the download and anything that goes wrong.
                    settings.selection = .settings
                    updates.update(extensions)
                }
                .disabled(model.isProcessing)
            }

            RailItem(title: "Settings", isSelected: settings.selection == .settings) {
                Image(systemName: "gearshape").font(.system(size: 16))
            } action: {
                settings.selection = .settings
            }
        }
        // Clear of the window's close, minimise and zoom buttons.
        .padding(.top, 46)
        .padding(.bottom, 12)
        .frame(width: 64)
        .ignoresSafeArea(.container, edges: .top)
        .onAppear { extensions.refreshAll() }
    }

    private func pluginItem(_ id: ExtensionID) -> some View {
        let isPinned = settings.pinnedPlugins.contains(id)
        let busy = extensions.state(for: id).isBusy

        return RailItem(title: id.title, isSelected: settings.selection == .plugin(id)) {
            PluginIcon(id: id, size: 24)
                .opacity(busy ? 0.4 : 1)
                .overlay { if busy { ProgressView().controlSize(.small) } }
        } action: {
            settings.selection = .plugin(id)
        }
        // Workspaces don't switch mid-batch.
        .disabled(model.isProcessing && settings.selection != .plugin(id))
        .contextMenu {
            Button(isPinned ? "Unpin" : "Pin") { settings.togglePin(id) }
        }
    }

    /// Installed plugins only; one being installed or removed stays until it
    /// finishes.
    private var installedPlugins: [ExtensionID] {
        ExtensionID.ordered.filter {
            let state = extensions.state(for: $0)
            return state.isInstalled || state.isBusy
        }
    }
    private var pinned: [ExtensionID] { settings.pinnedPlugins.filter(installedPlugins.contains) }
    private var unpinned: [ExtensionID] { installedPlugins.filter { !pinned.contains($0) } }
}

/// One rail button: its icon on a quiet fill when selected.
private struct RailItem<Icon: View>: View {
    let title: String
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon()
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 40, height: 40)
                .background(
                    isSelected ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
