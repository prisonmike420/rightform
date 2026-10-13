import SwiftUI

// Choosing one of a few things as large cards, as System Settings' Light,
// Dark and Auto: what to do with the files at Home, where they go on Where
// to?. A card is chosen by a click, the arrow keys move the choice, and
// the step's default button goes on; a double-click chooses and goes on.

/// One card to choose: a symbol or tile, a title and a quieter detail —
/// what it does, or how big the result will be. The chosen card has the
/// accent ring and a checkmark, so the choice never rests on colour alone,
/// and VoiceOver reads it as selected. A compact card is one line, for
/// options that shouldn't compete with the main ones.
struct ChoiceCard<Icon: View, Detail: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let isSelected: Bool
    var compact = false
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let detail: () -> Detail
    let action: () -> Void
    /// Chooses and goes on, as the step's default button would.
    var onDoubleClick: (() -> Void)?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Design.Radius.card, style: .continuous)

        Button(action: action) {
            content
                .padding(compact ? 8 : 10)
                // Cards in a row are as tall as the tallest, their titles level.
                .frame(
                    maxWidth: .infinity,
                    minHeight: compact ? nil : Design.Size.cardMinHeight,
                    maxHeight: compact ? nil : .infinity,
                    alignment: compact ? .leading : .top
                )
                .background(.fill.quaternary, in: shape)
                .overlay {
                    shape.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .padding(6)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick?() })
        .opacity(isEnabled ? 1 : Design.Opacity.disabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        if compact {
            HStack(spacing: 8) {
                icon()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                    detail()
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 4) {
                icon()
                    .padding(.bottom, 2)
                Text(title)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                detail()
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Cards to choose from, as many to a row as fit. A balanced grid keeps a
/// few cards even instead: all in one row, or two to a row when they don't
/// fit, never three and one. The arrow keys move the choice: left and up
/// to the previous card, right and down to the next.
struct ChoiceGrid<ID: Hashable, Content: View>: View {
    let ids: [ID]
    @Binding var selection: ID?
    var minimumWidth: CGFloat = Design.Size.cardMinWidth
    var balanced = false
    @ViewBuilder let card: (ID) -> Content

    var body: some View {
        Group {
            if balanced {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Design.Layout.cardSpacing) {
                        ForEach(ids, id: \.self) { id in
                            card(id).frame(minWidth: minimumWidth, maxWidth: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    grid(columns: Array(repeating: GridItem(.flexible(), spacing: Design.Layout.cardSpacing), count: 2))
                }
            } else {
                grid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: Design.Layout.cardSpacing)])
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard !ids.isEmpty else { return }
            let current = selection.flatMap { ids.firstIndex(of: $0) }
            switch direction {
            case .left, .up:
                selection = ids[max(0, (current ?? 1) - 1)]
            case .right, .down:
                selection = ids[min(ids.count - 1, (current ?? -1) + 1)]
            @unknown default:
                break
            }
        }
    }

    private func grid(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: Design.Layout.cardSpacing) {
            ForEach(ids, id: \.self) { id in card(id) }
        }
    }
}
