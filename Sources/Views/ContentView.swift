import SwiftUI
import UniformTypeIdentifiers

/// The main window, a shell of four fixed zones that pages only fill:
/// the rail on the left (Home, Plugins, installed plugins, Settings), a
/// header along the top with no divider (where you are; Update Stou and the
/// panel's button on the right), the work zone in the middle, and the
/// floating panel on the right. Only the work zone and the panel change from
/// page to page; the rail and the header's buttons stay where they are.
struct ContentView: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(UpdateChecker.self) private var updates

    /// The floating panel's width and its gap from the window's edges.
    static let panelWidth: CGFloat = 280
    static let panelInset: CGFloat = 8

    var body: some View {
        @Bindable var model = model
        let showsPanel = settings.showsInspector && settings.selection.hasInspector

        HStack(spacing: 0) {
            AppRail()
            VStack(spacing: 0) {
                ShellHeader()
                HStack(spacing: 0) {
                    detail
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                        // The work zone takes files anywhere in it.
                        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
                            model.acceptDrop(providers: providers)
                        }
                    if showsPanel {
                        // It pushes the work zone's edge rather than covering files.
                        WorkspaceInspector()
                            .frame(width: Self.panelWidth)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding([.trailing, .bottom], Self.panelInset)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.2), value: showsPanel)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .sheet(isPresented: Bindable(settings).showsPluginStore) {
            PluginStoreView()
        }
        // Choosing a workspace switches what dropped files are for.
        .onChange(of: settings.selection) { _, selection in
            switch selection {
            case .workspace: model.useWorkspace(nil)
            case .plugin(let id): model.useWorkspace(id)
            case .settings: break
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
            set: { if !$0 { model.finishPDFSimilarReview() } }
        )) {
            if let itemID = model.pdfReviewItemID {
                PDFDuplicateReviewView(itemID: itemID)
            }
        }
    }

    /// A plugin installed from the store opens with its panel showing, so
    /// its settings are found where they'll be used. Only while the store is
    /// still open: an install takes minutes, and Stou doesn't pull someone
    /// out of what they went on to do. Workspaces don't switch mid-batch.
    private func openInstalledPlugin() {
        guard let id = settings.pluginToOpen else { return }
        let state = extensions.state(for: id)
        guard !state.isBusy else { return }
        settings.pluginToOpen = nil
        guard state.isInstalled, settings.showsPluginStore, !model.isProcessing else { return }
        settings.showsPluginStore = false
        settings.selection = .plugin(id)
        settings.showsInspector = true
    }

    @ViewBuilder
    private var detail: some View {
        switch settings.selection {
        case .settings:
            SettingsPage()
        case .workspace, .plugin:
            // Home and each plugin share the workspace; the model knows which.
            WorkspaceView()
        }
    }
}

/// The rail on the left, always visible: Home and Plugins as symbols, then
/// the installed plugins as their colour tiles, pinned ones first, and
/// Settings at the bottom. Each
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

                    // The store opens over the window; the page beneath stays.
                    RailItem(title: "Plugins", isSelected: settings.showsPluginStore) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 16))
                    } action: {
                        settings.showsPluginStore = true
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

/// The header along the top of the work zone and panel, level with the
/// window's close, minimise and zoom buttons, with no divider: where you
/// are on the left; on the right Update Stou while there is an update, and
/// the panel's button, rightmost so it sits over the panel. The buttons
/// never move: the panel's button is only disabled where there is no panel.
/// Dragging the header moves the window.
struct ShellHeader: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
    @Environment(UpdateChecker.self) private var updates

    static let height: CGFloat = 52

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)

            // Stou and the plugins update together. Settings shows the
            // download and anything that goes wrong.
            if updates.hasUpdate(extensions) {
                Button {
                    settings.selection = .settings
                    updates.update(extensions)
                } label: {
                    Label("Update Stou", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.glassProminent)
                .disabled(model.isProcessing)
                .help(model.isProcessing ? "You can update once the current batch is done." : "Update Stou")
            }

            Button {
                settings.showsInspector.toggle()
            } label: {
                Label(settings.showsInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glass)
            .disabled(!settings.selection.hasInspector)
            .help(settings.showsInspector ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)")
        }
        .padding(.leading, 16)
        .padding(.trailing, ContentView.panelInset + 4)
        .frame(height: Self.height)
        .contentShape(Rectangle())
        .gesture(WindowDragGesture())
    }

    private var title: String {
        switch settings.selection {
        case .workspace: return "Home"
        case .plugin(let id): return id.title
        case .settings: return "Settings"
        }
    }
}
