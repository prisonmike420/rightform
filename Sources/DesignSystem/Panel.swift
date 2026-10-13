import SwiftUI

// The floating panel's rows. The panel sets `PanelRowStyle` and
// `PanelToggleStyle` once, so `LabeledContent` and `Toggle` inside it take
// this shape by themselves.

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
