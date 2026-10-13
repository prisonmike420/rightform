import SwiftUI

/// The window's toolbar, with system toolbar items: Back at the leading
/// edge on a second-level page — the store or Settings — and the panel's
/// button at the trailing edge, in the same place on every page. Where
/// there's no panel it's disabled, not hidden. Both are also in the View
/// menu.
struct ShellToolbar: ToolbarContent {
    let settings: AppSettings

    var body: some ToolbarContent {
        if settings.selection.isSecondLevel {
            ToolbarItem(placement: .navigation) {
                Button("Back", systemImage: "chevron.left") { settings.goBack() }
                    .help("Back (⌘[)")
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
