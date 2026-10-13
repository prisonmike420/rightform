import SwiftUI

// The shell's corner row. Its buttons and the panel's rows are in
// Sources/DesignSystem.

/// The window's top-right corner: the panel's button. It sits in the
/// panel's title row while the panel shows and floats over the work zone
/// otherwise, in the same place, so it never moves. Where there's no panel
/// it's disabled, not hidden.
struct ShellCornerButtons: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            ShellRoundButton(
                title: settings.inspectorIsShown ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                size: Design.Size.cornerButton,
                help: settings.inspectorIsShown ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)"
            ) {
                settings.showsInspector.toggle()
            }
            .disabled(!settings.selection.hasInspector)
        }
    }
}

/// The top-left of a second-level page — the store or Settings — in the
/// corner buttons' row: Back to the place it was opened from, and the
/// page's name.
struct ShellBackRow: View {
    @Environment(AppSettings.self) private var settings
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ShellRoundButton(title: "Back", systemImage: "chevron.left", size: Design.Size.cornerButton, help: "Back (⌘[)") {
                settings.goBack()
            }
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
