import SwiftUI

/// A round glass button in the rail, below the tabs: Plugins, Settings and
/// Update Stou. (Back and the panel's button are toolbar items.) A
/// prominent one is filled with the accent colour, as macOS draws a default
/// action. The name is its tooltip and is read by VoiceOver.
struct ShellRoundButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let systemImage: String
    var size: CGFloat = Design.Size.roundButton
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
        .opacity(isEnabled ? 1 : Design.Opacity.disabled)
        .help(help ?? title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: AnyShapeStyle {
        if prominent { return AnyShapeStyle(.white) }
        return isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }
}

/// One tab in the rail's capsule: a symbol, in the accent colour on a
/// quiet circle when selected.
struct RailTab<Icon: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let isSelected: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon()
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: Design.Size.railTab, height: Design.Size.railTab)
                .background(isSelected ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : Design.Opacity.disabled)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
