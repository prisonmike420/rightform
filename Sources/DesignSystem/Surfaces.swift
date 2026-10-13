import SwiftUI

// Surfaces over and around the work zone: glass, a form's button bar, a
// centred screen's heading and the drop highlight.

extension View {
    /// The shell's one surface: regular glass in a continuous rounded
    /// rectangle — the panel, the batch bar, a notice.
    func glassSurface(cornerRadius: CGFloat) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A form's buttons, below it as in Mac forms: the default action last.
/// Put a `Spacer` first to keep them all at the trailing edge.
struct FormButtonBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
    }
}

/// A centred screen's title and the line below it.
struct ScreenHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

/// While files are dragged over, the whole workspace takes a light accent
/// fill, with no frame; the hint names what happens on release.
struct DropHighlight: View {
    var body: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(Design.Opacity.dropHighlight))
            .allowsHitTesting(false)
    }
}
