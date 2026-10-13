import SwiftUI
import UniformTypeIdentifiers

/// The main window, a WindowShell of fixed zones that pages only fill: the
/// window's toolbar (Back on a second-level page, the place's name and the
/// panel's button), the rail on the left (the places as tabs — Home and the
/// installed plugins — then Plugins, Settings and Update Stou), the work
/// zone in the middle, and the floating panel on the right. The store and Settings
/// are a second level across the whole width.
struct ContentView: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        @Bindable var model = model

        WindowShell(title: placeTitle, showsInspector: settings.inspectorIsShown) {
            AppRail()
        } workZone: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The work zone takes files anywhere in it.
                .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
                    model.acceptDrop(providers: providers)
                }
        } inspector: {
            WorkspaceInspector()
        } toolbar: {
            ShellToolbar(settings: settings)
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
        // The alert's title states the problem itself, not the app's name.
        .alert(model.alertMessage ?? "", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK") { model.alertMessage = nil }
        }
        .sheet(isPresented: Binding(
            get: { model.pdfReviewItemID != nil },
            set: { if !$0 { model.cancelPDFSimilarReview() } }
        )) {
            if let itemID = model.pdfReviewItemID {
                PDFDuplicateReviewView(itemID: itemID)
            }
        }
    }

    /// A plugin installed from the store opens with its panel showing, so
    /// its settings are found where they'll be used. Only while the store is
    /// still in front: an install takes minutes, and Stou doesn't pull someone
    /// out of what they went on to do. Workspaces don't switch mid-batch.
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
            PluginStoreView()
        case .settings:
            SettingsPage()
        case .workspace, .plugin:
            // Home and each plugin share the workspace; the model knows which.
            WorkspaceView()
        }
    }

    private var placeTitle: String {
        switch settings.selection {
        case .workspace: return "Home"
        case .plugin(let id): return id.title
        case .plugins: return "Plugins"
        case .settings: return "Settings"
        }
    }
}

/// The rail on the left, always visible, as a vertical tab bar: the
/// places — Home and the installed plugins, pinned ones first — as tabs in
/// one glass capsule at the top, each a symbol in the accent colour when
/// selected, as sidebar icons are. Right below them, in a second capsule,
/// the second level: Plugins, where more tabs come from, and Settings.
/// Last, on its own so nothing moves when it appears, Update Stou, filled
/// blue while there is an update. Three groups, by function. On the
/// store and Settings the places are disabled: Back leaves them. Each name
/// shows as a tooltip and is read by VoiceOver.
struct AppRail: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
    @Environment(UpdateChecker.self) private var updates

    var body: some View {
        RailShell {
            RailGroup {
                RailTab(title: "Home", isSelected: settings.selection == .workspace) {
                    Image(systemName: "plus").font(.system(size: 16))
                } action: {
                    settings.selection = .workspace
                }
                .disabled(model.isProcessing && settings.selection != .workspace)

                ForEach(pinned) { id in pluginItem(id) }
                // Pinned and other plugins are kept apart by space alone.
                if !pinned.isEmpty && !unpinned.isEmpty {
                    Spacer().frame(height: 6)
                }
                ForEach(unpinned) { id in pluginItem(id) }
            }
            .disabled(settings.selection.isSecondLevel)

            // The second level in a group of its own (HIG, Toolbars: group
            // by function, at most three groups).
            RailGroup {
                RailTab(title: "Plugins", isSelected: settings.selection == .plugins, help: "Plugins (⇧⌘P)") {
                    Image(systemName: "square.grid.2x2").font(.system(size: 16))
                } action: {
                    settings.selection = .plugins
                }
                RailTab(title: "Settings", isSelected: settings.selection == .settings, help: "Settings (⌘,)") {
                    Image(systemName: "gearshape").font(.system(size: 16))
                } action: {
                    settings.selection = .settings
                }
            }

            // Stou and the plugins update together. Settings shows the
            // download and anything that goes wrong.
            if updates.hasUpdate(extensions) {
                ShellRoundButton(
                    title: "Update Stou",
                    systemImage: "arrow.down",
                    prominent: true,
                    help: model.isProcessing ? "You can update once the current batch is done." : nil
                ) {
                    settings.selection = .settings
                    updates.update(extensions)
                }
                .disabled(model.isProcessing)
            }
        }
        .onAppear { extensions.refreshAll() }
    }

    private func pluginItem(_ id: ExtensionID) -> some View {
        let isPinned = settings.pinnedPlugins.contains(id)
        let busy = extensions.state(for: id).isBusy

        return RailTab(title: id.title, isSelected: settings.selection == .plugin(id)) {
            Image(systemName: id.symbolName)
                .font(.system(size: 16))
                .opacity(busy ? Design.Opacity.disabled : 1)
                .overlay { if busy { ProgressView().controlSize(.small) } }
        } action: {
            settings.selection = .plugin(id)
        }
        // Workspaces don't switch mid-batch.
        .disabled(model.isProcessing && settings.selection != .plugin(id))
        // Also View › Pin, so it isn't only a right-click.
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
