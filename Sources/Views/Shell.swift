import SwiftUI

/// The window's toolbar, with system toolbar items. At the leading edge:
/// Back on a second-level page — the store or Settings — then Plugins, and
/// beside it Update Stou, filled blue, while there is an update. At the
/// trailing edge, the panel's button, in the same place on every page;
/// where there's no panel it's disabled, not hidden. Each is also in the
/// menu bar.
struct ShellToolbar: ToolbarContent {
    let settings: AppSettings
    let model: CompressionModel
    let updates: UpdateChecker
    let extensions: ExtensionManager

    var body: some ToolbarContent {
        if settings.selection.isSecondLevel {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.left") { settings.goBack() }
                    .help("Back (⌘[)")
            }
            ToolbarSpacer(.fixed, placement: .navigation)
        }
        ToolbarItem(placement: .navigation) {
            // Filled while the store is in front.
            Button("Plugins", systemImage: settings.selection == .plugins ? "square.grid.2x2.fill" : "square.grid.2x2") {
                settings.selection = .plugins
            }
            .help("Plugins (⇧⌘P)")
        }
        // Stou and the plugins update together. Settings shows the download
        // and anything that goes wrong.
        if updates.hasUpdate(extensions) {
            ToolbarItem(placement: .navigation) {
                Button("Update Stou", systemImage: "arrow.down") {
                    settings.selection = .settings
                    updates.update(extensions)
                }
                .buttonStyle(.glassProminent)
                .help(model.isProcessing ? "You can update once the current batch is done." : "Update Stou")
                .disabled(model.isProcessing)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(
                settings.inspectorIsShown ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing"
            ) {
                settings.showsInspector.toggle()
            }
            .help(settings.inspectorIsShown ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)")
            .disabled(!settings.selection.hasInspector)
        }
    }
}
