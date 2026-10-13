import SwiftUI

// Every icon beside a row's text has the same shape: a rounded tile.

/// Plugin symbol on a rounded colour tile, in the style of System Settings:
/// 20 pt beside a list row's text, 32 pt where the plugin is the subject.
struct PluginIcon: View {
    let id: ExtensionID
    var size: CGFloat = Design.Size.subjectIcon
    /// Round, as a tab in the rail.
    var circular = false

    var body: some View {
        Image(systemName: id.symbolName)
            .font(.system(size: size * (circular ? 0.42 : 0.5), weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(id.tint.gradient, in: RoundedRectangle(cornerRadius: circular ? size / 2 : Design.Radius.tile(size), style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A plain grey tile for a symbol that isn't a plugin — routines and
/// destinations — so every row icon has the same shape as the plugins'.
struct SymbolTile: View {
    let symbol: String
    var size: CGFloat = Design.Size.rowIcon

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.gray.gradient, in: RoundedRectangle(cornerRadius: Design.Radius.tile(size), style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A file's cover: its thumbnail fitted inside a small tile with room around
/// it, a quiet fill and a hairline edge, so a white page or a transparent
/// image still reads as an object.
struct FileCover: View {
    let url: URL
    var size: CGFloat = Design.Size.fileCover

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Design.Radius.cover(size), style: .continuous)

        LazyThumbnail(url: url)
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(.background.secondary, in: shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}
