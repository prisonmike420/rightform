import SwiftUI

// MARK: - Buttons

/// A round glass button, the shell's one button shape: in the rail
/// (Plugins, Settings) and in the window's top-right corner. A dot marks a
/// status, such as a waiting update; the name is its tooltip and is read by
/// VoiceOver.
struct ShellRoundButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let systemImage: String
    var size: CGFloat = 38
    var isSelected = false
    var badge = false
    var help: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .overlay(alignment: .topTrailing) {
            if badge {
                Circle()
                    .fill(.tint)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .help(help ?? title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The window's top-right corner: Update Stou, with a dot, while there is
/// an update, and the panel's button. They sit in the panel's title row
/// while it shows and float over the work zone otherwise, in the same place,
/// so they never move. Where there's no panel its button is disabled, not
/// hidden.
struct ShellCornerButtons: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model
    @Environment(UpdateChecker.self) private var updates

    /// The row they sit in, along the top of the panel and the work zone.
    static let rowHeight: CGFloat = 44
    /// Their distance from the panel's edge, and the panel's title's.
    static let inset: CGFloat = 14

    var body: some View {
        HStack(spacing: 6) {
            // Stou and the plugins update together. Settings shows the
            // download and anything that goes wrong.
            if updates.hasUpdate(extensions) {
                ShellRoundButton(
                    title: "Update Stou",
                    systemImage: "arrow.down",
                    size: 28,
                    badge: true,
                    help: model.isProcessing ? "You can update once the current batch is done." : nil
                ) {
                    settings.selection = .settings
                    updates.update(extensions)
                }
                .disabled(model.isProcessing)
            }

            ShellRoundButton(
                title: settings.showsInspector ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                size: 28,
                help: settings.showsInspector ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)"
            ) {
                settings.showsInspector.toggle()
            }
            .disabled(!settings.selection.hasInspector)
        }
    }
}

// MARK: - Panel rows

/// A group of rows in the panel, with no card behind it: an optional title,
/// rows divided by hairlines, and an optional note below.
struct PanelSection<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { subviews in
                ForEach(subviews) { subview in
                    if subview.id != subviews.first?.id {
                        Divider()
                    }
                    subview.padding(.vertical, 7)
                }
            }
            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }
}

/// A panel row: the name on the left, its value or control on the right.
struct PanelRowStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) { configuration.label }
            Spacer(minLength: 8)
            configuration.content
        }
    }
}

/// A panel row for a switch: the name on the left, the switch on the right.
/// The switch keeps the name for VoiceOver.
struct PanelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) { configuration.label }
                .accessibilityHidden(true)
            Spacer(minLength: 8)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
