import SwiftUI

/// Stou's design tokens: every size, radius, opacity, motion and status
/// colour that more than one view relies on. Views use these instead of
/// literals, so the window's parts keep the same proportions. Values that
/// only make sense inside one component (a symbol's share of its tile, say)
/// stay in that component.
enum Design {

    // MARK: - Layout

    /// The window's fixed zones: the rail, the work zone and the panel.
    enum Layout {
        /// The rail on the left.
        static let railWidth: CGFloat = 60
        /// The work zone never gets narrower than this.
        static let workZoneMinWidth: CGFloat = 360
        /// The floating panel on the right.
        static let panelWidth: CGFloat = 280
        /// The panel's gap from the toolbar and the window's edges, and the
        /// rail's from the toolbar.
        static let panelInset: CGFloat = 8
        /// The panel's title row.
        static let panelTitleHeight: CGFloat = 44
        /// The panel's title's and rows' distance from its edges.
        static let panelPadding: CGFloat = 14
        /// A centred screen's margin: progress, done, the empty workspace.
        static let screenPadding: CGFloat = 24
        /// A floating bar's or notice's gap from the work zone's edges.
        static let overlayPadding: CGFloat = 12
        /// The done screen's list of files.
        static let resultListWidth: CGFloat = 440
        /// A notice floating over the work zone is no wider than this.
        static let noticeMaxWidth: CGFloat = 420
        /// Between choice cards, across and down.
        static let cardSpacing: CGFloat = 10
        /// Between buttons that have a bezel or glass, and around them: about
        /// 12 pt, as the HIG asks for (Accessibility › Controls).
        static let buttonSpacing: CGFloat = 12
    }

    // MARK: - Sizes

    /// Icons, tiles and round buttons.
    enum Size {
        /// A round button in the rail.
        static let roundButton: CGFloat = 38
        /// A tab in the rail's capsule.
        static let railTab: CGFloat = 34
        /// A tile beside a list row's text.
        static let rowIcon: CGFloat = 20
        /// A tile where the plugin is the subject, as in the store.
        static let subjectIcon: CGFloat = 32
        /// A file's cover in a list.
        static let fileCover: CGFloat = 40
        /// A choice card's tile or symbol.
        static let cardIcon: CGFloat = 28
        /// A choice card is never narrower than this; as many fit to a row
        /// as the width allows.
        static let cardMinWidth: CGFloat = 140
        /// A choice card's height, so a row of them lines up.
        static let cardMinHeight: CGFloat = 96
        /// macOS's default control size, 28 × 28 pt (HIG, Accessibility): the
        /// hit area of a symbol button at a row's end.
        static let control: CGFloat = 28
        /// The smallest control macOS allows, 20 × 20 pt (HIG, Accessibility):
        /// the hit area of a borderless symbol or a value that opens a menu.
        static let minimumControl: CGFloat = 20
    }

    // MARK: - Radii

    /// Glass surfaces take these as their smallest radius and are otherwise
    /// concentric with what holds them, as Liquid Glass asks.
    enum Radius {
        /// The floating panel and notices over the work zone.
        static let panel: CGFloat = 16
        /// The batch bar along the bottom of the work zone.
        static let bar: CGFloat = 18
        /// A choice card.
        static let card: CGFloat = 10

        /// A rounded tile, in the proportions of System Settings' icons.
        static func tile(_ size: CGFloat) -> CGFloat { size * 0.225 }
        /// A file's cover, a little rounder than a tile.
        static func cover(_ size: CGFloat) -> CGFloat { size * 0.2 }
    }

    // MARK: - Opacity

    enum Opacity {
        /// A control that can't be used right now, and a busy plugin's tile.
        static let disabled: Double = 0.4
        /// The work zone's fill while files are dragged over it.
        static let dropHighlight: Double = 0.08
    }

    // MARK: - Motion

    enum Motion {
        /// The panel, bars and notices coming and going.
        static let standard: Animation = .smooth(duration: 0.2)
        /// The empty workspace's hint taking the accent colour.
        static let hint: Animation = .smooth(duration: 0.18)
    }

    // MARK: - Status colours

    /// What a state means, never the only sign of it: each comes with a
    /// symbol or words.
    enum Status {
        /// Done, installed, smaller.
        static let success: Color = .green
        /// Part of a batch failed, AI labels found or lost.
        static let warning: Color = .orange
        /// A file or an install failed.
        static let failure: Color = .red
    }
}
