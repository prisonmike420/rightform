import SwiftUI

// Surfaces over and around the work zone: glass, a form's button bar, a
// centred screen's heading and the drop highlight.

extension View {
    /// The shell's one surface: regular glass whose corners are concentric
    /// with what holds it — the window, for the panel — and never smaller
    /// than `minimumRadius`: the panel, the batch bar, a notice.
    func glassSurface(minimumRadius: CGFloat) -> some View {
        glassEffect(.regular, in: ConcentricRectangle(corners: .concentric(minimum: .fixed(minimumRadius)), isUniform: true))
    }
}

/// A step's buttons, along the bottom of the work zone at the trailing
/// edge, as in Mac assistants: Back, then the step's actions with the
/// default one last. A `Spacer` comes first, after any leading button.
struct FormButtonBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Design.Layout.buttonSpacing) { content }
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
