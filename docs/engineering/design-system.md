# Design system

Stou's interface is built from one small set of tokens and components in [`Sources/DesignSystem`](../../Sources/DesignSystem). Screens in `Sources/Views` compose them; they don't define their own sizes, radii, status colours or row shapes.

Native controls come first: grouped `Form`s, `Section`s, `Toggle`s, `Picker`s and the system's button styles (`.borderedProminent`, `.glass`, `.glassProminent`, `.link`). The design system only covers what macOS doesn't draw by itself.

## Using it

- Reach for a component before writing a new `HStack` of icon, title and detail.
- A number that more than one view needs is a token in `Design`. Add it there, with a comment saying where it's used, instead of repeating the literal.
- A value that only makes sense inside one component (a symbol's share of its tile, a ring's width) stays in that component.
- Status colours never carry meaning alone: each comes with a symbol or words.
- There are no SwiftUI previews: the build has no Xcode, and `#Preview` needs Xcode's macro plugin. Check a component in the running app.

## Tokens — `Tokens.swift`

| Token | Value | Where |
| --- | --- | --- |
| `Design.Layout.railWidth` | 60 | The rail on the left. |
| `Design.Layout.railTopClearance` | 42 | The rail's first button, clear of the window's traffic lights. |
| `Design.Layout.workZoneMinWidth` | 360 | The work zone's narrowest width. |
| `Design.Layout.panelWidth` | 280 | The floating panel on the right. |
| `Design.Layout.panelInset` | 8 | The panel's gap from the window's edges. |
| `Design.Layout.cornerRowHeight` | 44 | The row of corner buttons, Back and the panel's title. |
| `Design.Layout.cornerInset` | 14 | Corner buttons' and the panel's content inset. |
| `Design.Layout.topClearance` | 52 | Where the work zone's content starts (`panelInset + cornerRowHeight`). |
| `Design.Layout.screenPadding` | 24 | A centred screen's margin. |
| `Design.Layout.contentColumnWidth` | 280 | The progress checklist and its bar. |
| `Design.Layout.overlayPadding` | 12 | A floating bar's or notice's gap from the work zone's edges. |
| `Design.Layout.noticeMaxWidth` | 420 | A notice over the work zone. |
| `Design.Size.roundButton` | 38 | Round buttons in the rail. |
| `Design.Size.cornerButton` | 28 | Back and the panel's button. |
| `Design.Size.railTab` | 34 | A tab in the rail's capsule. |
| `Design.Size.rowIcon` | 20 | A tile beside a row's text. |
| `Design.Size.subjectIcon` | 32 | A tile where the plugin is the subject. |
| `Design.Size.fileCover` | 40 | A file's cover in a list. |
| `Design.Size.squareButton` | 32 | The square button at a row's end, and its spinner. |
| `Design.Radius.panel` | 16 | The panel, notices. |
| `Design.Radius.bar` | 18 | The batch bar. |
| `Design.Radius.control` | 8 | The square button. |
| `Design.Radius.tile(size)` | size × 0.225 | Plugin and symbol tiles. |
| `Design.Radius.cover(size)` | size × 0.2 | File covers. |
| `Design.Opacity.disabled` | 0.4 | Unavailable custom controls, a busy plugin's tile. |
| `Design.Opacity.dropHighlight` | 0.08 | The accent fill while files are dragged over. |
| `Design.Opacity.tintedFill` | 0.2 | Behind a tinted square button. |
| `Design.Motion.standard` | smooth, 0.2 s | The panel, bars and notices coming and going. |
| `Design.Motion.hint` | smooth, 0.18 s | The empty workspace's hint. |
| `Design.Status.success` | green | Done, installed, smaller. |
| `Design.Status.warning` | orange | Partly failed, AI labels found or lost. |
| `Design.Status.failure` | red | A file or an install failed. |

Plugin tile colours belong to the plugin's group: `PluginCategory.tint` in `Sources/Engine/Extensions.swift`.

## Components

| Component | File | What it is |
| --- | --- | --- |
| `ShellRoundButton` | `Buttons.swift` | The shell's round glass button: rail, Back, the panel's button. `prominent` fills it with the accent. |
| `RailTab` | `Buttons.swift` | A tab in the rail's capsule: Home's symbol, or a plugin's round tile with a ring. |
| `SquareIconButton` | `Buttons.swift` | One bordered or tinted square button at a row's end, as in the store. |
| `PanelSection` | `Panel.swift` | A group of panel rows with an optional title and note, divided by hairlines. |
| `PanelPicker` | `Panel.swift` | A choice in a panel row, drawn as its value with up-down chevrons. |
| `PanelRowStyle` | `Panel.swift` | `LabeledContent` in the panel: name left, value right. |
| `PanelToggleStyle` | `Panel.swift` | `Toggle` in the panel: name left, small switch right. |
| `PluginIcon` | `Tiles.swift` | A plugin's symbol on its group's colour tile; round in the rail. |
| `SymbolTile` | `Tiles.swift` | A grey tile for routines and destinations. |
| `FileCover` | `Tiles.swift` | A file's thumbnail in a quiet tile with a hairline edge. |
| `TitleDetail` | `Rows.swift` | A row's title over a secondary detail line; optionally one line cut in the middle. |
| `ListRowButton` | `Rows.swift` | A whole-row button: icon, `TitleDetail`, and an accessory at the end. |
| `RowChevron`, `RowCheckmark` | `Rows.swift` | The accessory for a row that opens something, or one that's chosen. |
| `SizeTag` | `Rows.swift` | An estimated size and how much smaller, or "Already light". |
| `ChecklistStep` | `Rows.swift` | A step of a short checklist: done, running or waiting. |
| `glassSurface(cornerRadius:)` | `Surfaces.swift` | Regular glass in a continuous rounded rectangle. |
| `FormButtonBar` | `Surfaces.swift` | A form's buttons below it, default action last. |
| `ScreenHeading` | `Surfaces.swift` | A centred screen's title and subtitle. |
| `DropHighlight` | `Surfaces.swift` | The accent fill over the work zone while files are dragged over it. |

The shell's own pieces, which read the app's state, stay with the views: `ShellCornerButtons` and `ShellBackRow` in `Sources/Views/Shell.swift`.
