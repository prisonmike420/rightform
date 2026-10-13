import SwiftUI

// MARK: - Buttons

/// A round glass button, the shell's one button shape: in the rail
/// (Plugins, Update Stou, Settings), Back, and the panel's button. A
/// prominent one is filled with the accent colour, as macOS draws a default
/// action. The name is its tooltip and is read by VoiceOver.
struct ShellRoundButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let systemImage: String
    var size: CGFloat = 38
    var isSelected = false
    var prominent = false
    var help: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: prominent ? .semibold : .medium))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background { if prominent { Circle().fill(Color.accentColor) } }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .opacity(isEnabled ? 1 : 0.4)
        .help(help ?? title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: AnyShapeStyle {
        if prominent { return AnyShapeStyle(.white) }
        return isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }
}

/// The window's top-right corner: the panel's button. It sits in the
/// panel's title row while the panel shows and floats over the work zone
/// otherwise, in the same place, so it never moves. Where there's no panel
/// it's disabled, not hidden.
struct ShellCornerButtons: View {
    @Environment(AppSettings.self) private var settings

    /// The row they sit in, along the top of the panel and the work zone.
    static let rowHeight: CGFloat = 44
    /// Their distance from the panel's edge, and the panel's title's.
    static let inset: CGFloat = 14

    var body: some View {
        HStack(spacing: 6) {
            ShellRoundButton(
                title: settings.inspectorIsShown ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.trailing",
                size: 28,
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
            ShellRoundButton(title: "Back", systemImage: "chevron.left", size: 28, help: "Back (⌘[)") {
                settings.goBack()
            }
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: - Panel rows

/// A choice in a panel row, drawn as its value with the system's up-down
/// chevrons instead of a bordered pop-up button; it opens the same menu.
struct PanelPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            // The panel's row styles would otherwise reach the menu's items.
            .toggleStyle(.automatic)
            .labeledContentStyle(.automatic)
        } label: {
            HStack(spacing: 4) {
                Text(label(selection))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}

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
