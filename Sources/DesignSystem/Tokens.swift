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
        /// The rail's first button sits clear of the close, minimise and
        /// zoom buttons.
        static let railTopClearance: CGFloat = 42
        /// The work zone never gets narrower than this.
        static let workZoneMinWidth: CGFloat = 360
        /// The floating panel on the right.
        static let panelWidth: CGFloat = 280
        /// The panel's gap from the window's edges.
        static let panelInset: CGFloat = 8
        /// The row along the top of the panel and the work zone: the corner
        /// buttons, Back and the panel's title.
        static let cornerRowHeight: CGFloat = 44
        /// The corner buttons' distance from the panel's edge, and the
        /// panel's title's and rows'.
        static let cornerInset: CGFloat = 14
        /// The work zone's content starts below the corner buttons' row.
        static let topClearance: CGFloat = panelInset + cornerRowHeight
        /// A centred screen's margin: progress, done, the empty workspace.
        static let screenPadding: CGFloat = 24
        /// A centred screen's column: the progress checklist and its bar.
        static let contentColumnWidth: CGFloat = 280
        /// A floating bar's or notice's gap from the work zone's edges.
        static let overlayPadding: CGFloat = 12
        /// A notice floating over the work zone is no wider than this.
        static let noticeMaxWidth: CGFloat = 420
    }

    // MARK: - Sizes

    /// Icons, tiles and round buttons.
    enum Size {
        /// A round button in the rail.
        static let roundButton: CGFloat = 38
        /// A round button in the corner row: Back and the panel's button.
        static let cornerButton: CGFloat = 28
        /// A tab in the rail's capsule.
        static let railTab: CGFloat = 34
        /// A tile beside a list row's text.
        static let rowIcon: CGFloat = 20
        /// A tile where the plugin is the subject, as in the store.
        static let subjectIcon: CGFloat = 32
        /// A file's cover in a list.
        static let fileCover: CGFloat = 40
        /// A square button at the end of a row, and the spinner in its place.
        static let squareButton: CGFloat = 32
    }

    // MARK: - Radii

    enum Radius {
        /// The floating panel and notices over the work zone.
        static let panel: CGFloat = 16
        /// The batch bar along the bottom of the work zone.
        static let bar: CGFloat = 18
        /// A square button at the end of a row.
        static let control: CGFloat = 8

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
        /// The fill behind a tinted square button.
        static let tintedFill: Double = 0.2
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
