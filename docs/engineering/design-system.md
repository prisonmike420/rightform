# Design system

Stou's interface is built from one small set of tokens and components in [`Sources/DesignSystem`](../../Sources/DesignSystem). Screens in `Sources/Views` compose them; they don't define their own sizes, radii, status colours or row shapes.

Native controls come first: grouped `Form`s, `Section`s, `Toggle`s, `Picker`s and the system's button styles (`.borderedProminent`, `.glass`, `.glassProminent`, `.link`). The design system only covers what macOS doesn't draw by itself.

## Using it

- Reach for a component before writing a new `HStack` of icon, title and detail.
- A number that more than one view needs is a token in `Design`. Add it there, with a comment saying where it's used, instead of repeating the literal.
- A value that only makes sense inside one component (a symbol's share of its tile, a ring's width) stays in that component.
- Status colours never carry meaning alone: each comes with a symbol or words.
- Nothing that matters sits at the window's or the rail's bottom edge (HIG, Layout and Sidebars): step buttons and the batch bar run along the top.
- Buttons follow Apple's Human Interface Guidelines for macOS: system push buttons with text where a symbol wouldn't say what happens, a hit area of at least 20 × 20 pt (28 × 28 pt by default), about 12 pt between bezelled buttons, and glass buttons on glass surfaces. A sheet's Done is paired with Cancel.
- There are no SwiftUI previews: the build has no Xcode, and `#Preview` needs Xcode's macro plugin. Check a component in the running app.

## Tokens — `Tokens.swift`

| Token | Value | Where |
| --- | --- | --- |
| `Design.Layout.railWidth` | 60 | The rail on the left. |
| `Design.Layout.workZoneMinWidth` | 360 | The work zone's narrowest width. |
| `Design.Layout.panelWidth` | 280 | The floating panel on the right. |
| `Design.Layout.panelInset` | 8 | The panel's gap from the toolbar and the window's edges; the rail's from the toolbar. |
| `Design.Layout.panelTitleHeight` | 44 | The panel's title row. |
| `Design.Layout.panelPadding` | 14 | The panel's title and rows from its edges. |
| `Design.Layout.screenPadding` | 24 | A centred screen's margin. |
| `Design.Layout.contentColumnWidth` | 280 | The progress checklist and its bar. |
| `Design.Layout.overlayPadding` | 12 | A floating bar's or notice's gap from the work zone's edges. |
| `Design.Layout.noticeMaxWidth` | 420 | A notice over the work zone. |
| `Design.Layout.buttonSpacing` | 12 | Between bezelled or glass buttons, and between the rail's tabs and buttons. |
| `Design.Size.roundButton` | 38 | Round buttons in the rail. |
| `Design.Size.railTab` | 34 | A tab in the rail's capsule. |
| `Design.Size.rowIcon` | 20 | A tile beside a row's text. |
| `Design.Size.subjectIcon` | 32 | A tile where the plugin is the subject. |
| `Design.Size.fileCover` | 40 | A file's cover in a list. |
| `Design.Size.minimumControl` | 20 | The smallest hit area macOS allows: a borderless symbol, a value that opens a menu. |
| `Design.Radius.panel` | 16 | The panel, notices: the smallest radius; glass is otherwise concentric. |
| `Design.Radius.bar` | 18 | The batch bar: the smallest radius. |
| `Design.Radius.tile(size)` | size × 0.225 | Plugin and symbol tiles. |
| `Design.Radius.cover(size)` | size × 0.2 | File covers. |
| `Design.Opacity.disabled` | 0.4 | Unavailable custom controls, a busy plugin's tile. |
| `Design.Opacity.dropHighlight` | 0.08 | The accent fill while files are dragged over. |
| `Design.Motion.standard` | smooth, 0.2 s | The panel, bars and notices coming and going. |
| `Design.Motion.hint` | smooth, 0.18 s | The empty workspace's hint. |
| `Design.Status.success` | green | Done, installed, smaller. |
| `Design.Status.warning` | orange | Partly failed, AI labels found or lost. |
| `Design.Status.failure` | red | A file or an install failed. |

Plugin tile colours belong to the plugin's group: `PluginCategory.tint` in `Sources/Engine/Extensions.swift`.

## Components

| Component | File | What it is |
| --- | --- | --- |
| `ShellRoundButton` | `Buttons.swift` | The rail's round glass buttons below the tabs: Plugins, Settings, Update Stou. `prominent` fills it with the accent. |
| `RailTab` | `Buttons.swift` | A tab in the rail's capsule: a symbol, in the accent colour when selected. |
| `PanelSection` | `Panel.swift` | A group of panel rows with an optional title and note, divided by hairlines. |
| `PanelPicker` | `Panel.swift` | A choice in a panel row, drawn as its value with up-down chevrons. |
| `PanelRowStyle` | `Panel.swift` | `LabeledContent` in the panel: name left, value right. |
| `PanelToggleStyle` | `Panel.swift` | `Toggle` in the panel: name left, mini switch right. |
| `PluginIcon` | `Tiles.swift` | A plugin's symbol on its group's colour tile, in rows. |
| `SymbolTile` | `Tiles.swift` | A grey tile for routines and destinations. |
| `FileCover` | `Tiles.swift` | A file's thumbnail in a quiet tile with a hairline edge. |
| `TitleDetail` | `Rows.swift` | A row's title over a secondary detail line. |
| `ListRowButton` | `Rows.swift` | A whole-row button: icon, `TitleDetail`, and an accessory at the end. |
| `RowChevron` | `Rows.swift` | The accessory for a row that opens something. |
| `SizeTag` | `Rows.swift` | An estimated size and how much smaller, or "Already light". |
| `ChecklistStep` | `Rows.swift` | A step of a short checklist: done, running or waiting. |
| `glassSurface(minimumRadius:)` | `Surfaces.swift` | Regular glass, concentric with its container, never with a smaller radius than the minimum. |
| `FormButtonBar` | `Surfaces.swift` | A step's buttons along the top of the work zone (in a `safeAreaBar`): Back first, the default action last. |
| `ScreenHeading` | `Surfaces.swift` | A centred screen's title and subtitle. |
| `DropHighlight` | `Surfaces.swift` | The accent fill over the work zone while files are dragged over it. |

The window's toolbar — Back and the panel's button as system toolbar items — is `ShellToolbar` in `Sources/Views/Shell.swift`.
