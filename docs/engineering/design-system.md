# Design system

Stou's interface is built from one small set of tokens and components in [`Sources/DesignSystem`](../../Sources/DesignSystem). Screens in `Sources/Views` compose them; they don't define their own sizes, radii, status colours or row shapes.

Native controls come first: grouped `Form`s, `Section`s, `Toggle`s, `Picker`s and the system's button styles (`.borderedProminent`, `.glass`, `.glassProminent`, `.link`). The design system only covers what macOS doesn't draw by itself.

## Levels

The interface is built in four levels, and each knows only the slots of the one below it. A new screen picks its shell first and fills it with components; it never sets up its own `Form`, `List`, bar, padding or glass.

1. **Window** — `WindowShell` (`Shells.swift`): the toolbar (the header), the rail, the work zone and the inspector on the right. `ContentView` fills its slots; the toolbar's items are `ShellToolbar`.
2. **Zones** — what each zone is made of:
   - Rail: `RailShell` with `RailGroup` capsules (the places; Plugins and Settings) and Update Stou on its own.
   - Work zone of a workspace: `WorkZoneShell` — the screen, the batch bar along the bottom, the AI label notice and the drop highlight. The store and Settings fill the work zone with a screen directly.
   - Inspector: `InspectorShell` — the panel's title, then its `PanelSection`s with the panel's row and switch styles.
3. **Screens** — what fills the work zone: `FormScreen` (grouped sections, and a step's buttons along the bottom, at the trailing edge), `StatusScreen` (a centred state) and `ListScreen` (one list of rows).
4. **Components** — the rest of `Sources/DesignSystem`, below.

### The work zone's states

`WorkspaceScreen` (`Sources/Views/WorkspaceView.swift`) lists every state a workspace's work zone can be in; the first that applies wins.

| State | Screen | Shell | Step buttons |
| --- | --- | --- | --- |
| `empty` | the drop hint | `StatusScreen` | — (a click opens the picker) |
| `labelReport` | `LabelReportScreen` | `FormScreen` | Back, Remove Labels, New Task |
| `whereTo` | `WhereToScreen` | `FormScreen` (job row, `ChoiceGrid` of destinations) | Back, Start |
| `choose` | `HomeWizard` | `FormScreen` (`FileRow` list, `ChoiceGrid` of actions) | Clear, Continue |
| `progress` | `JobProgressScreen` | `StatusScreen` | Stop or Cancel, in the screen |
| `done` | `JobDoneScreen` | `StatusScreen` (`RowGroup` of `FileRow`s) | Show in Finder or Share…, New Task, in the screen |
| `fileList` | `FileListView` | `ListScreen` | in the batch bar |

The second level fills the work zone across the window: the store (`PluginStoreView`) and Settings (`SettingsPage`) are `FormScreen`s. The PDF review sheet is a `FormScreen` too.

## Using it

- Reach for a component before writing a new `HStack` of icon, title and detail.
- A number that more than one view needs is a token in `Design`. Add it there, with a comment saying where it's used, instead of repeating the literal.
- A value that only makes sense inside one component (a symbol's share of its tile, a ring's width) stays in that component.
- Colour comes from the system: the accent people choose in System Settings › Appearance (`.tint`, `Color.accentColor`); Stou sets no accent of its own. Push buttons are grey except the default one, as on every Mac.
- Status colours never carry meaning alone: each comes with a symbol or words.
- Toolbar and rail items are grouped by function, at most three groups (HIG, Toolbars): the rail has the places, the second level (Plugins, Settings) and Update Stou.
- A step's buttons sit at the bottom right, as in Mac assistants (Installer, Migration Assistant) and sheets: a leading Clear, then Back and the default action last; the batch bar too. A firm scroll edge keeps sections from running behind them. The rail keeps nothing at its bottom edge (HIG, Sidebars).
- Choosing one of a few things is a `ChoiceGrid` of `ChoiceCard`s, as System Settings' Appearance: accent ring and checkmark for the chosen one, arrow keys to move, Return for the step's default button, double-click for both. Content (files) stays rows, never cards, so it never looks like something to choose.
- Buttons follow Apple's Human Interface Guidelines for macOS: symbols with familiar meanings and a tooltip, coloured by role, where a row repeats the same actions (the store), and push buttons with text elsewhere, a hit area of at least 20 × 20 pt (28 × 28 pt by default), about 12 pt between bezelled buttons, and glass buttons on glass surfaces. A sheet's Done is paired with Cancel.
- There are no SwiftUI previews: the build has no Xcode, and `#Preview` needs Xcode's macro plugin. Check a component in the running app, or with `scripts/snapshot-screens.sh`, which renders the rail, the inspector, each workspace state, Where to?, the store and Settings offscreen and saves them as PNGs in `build/snapshots`. Liquid Glass doesn't render offscreen, so the rail's capsules and the panel's glass are missing there; the harness (`scripts/snapshot/Harness.swift`) uses its own defaults, never the app's. A new screen or state gets a line in the harness.

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
| `Design.Layout.cardSpacing` | 10 | Between choice cards. |
| `Design.Layout.resultListWidth` | 440 | The done screen's list of files. |
| `Design.Layout.buttonSpacing` | 12 | Between bezelled or glass buttons, and between the rail's groups. |
| `Design.Size.roundButton` | 38 | Round buttons in the rail. |
| `Design.Size.railTab` | 34 | A tab in the rail's capsule. |
| `Design.Size.rowIcon` | 20 | A tile beside a row's text. |
| `Design.Size.subjectIcon` | 32 | A tile where the plugin is the subject. |
| `Design.Size.fileCover` | 40 | A file's cover in a list. |
| `Design.Size.cardIcon` | 28 | A choice card's tile or symbol. |
| `Design.Size.cardMinWidth` / `cardMinHeight` | 140 / 96 | A choice card's smallest size. |
| `Design.Size.control` | 28 | macOS's default control size: a symbol button at a row's end. |
| `Design.Size.minimumControl` | 20 | The smallest hit area macOS allows: a borderless symbol, a value that opens a menu. |
| `Design.Radius.panel` | 16 | The panel, notices: the smallest radius; glass is otherwise concentric. |
| `Design.Radius.bar` | 18 | The batch bar: the smallest radius. |
| `Design.Radius.card` | 10 | A choice card, a row group. |
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
| `WindowShell`, `RailShell`, `RailGroup`, `WorkZoneShell`, `InspectorShell`, `FormScreen`, `StatusScreen`, `ListScreen` | `Shells.swift` | The levels above components; see Levels. |
| `ShellRoundButton` | `Buttons.swift` | The rail's round glass button on its own: Update Stou, `prominent`, filled with the accent. |
| `RailTab` | `Buttons.swift` | A tab in one of the rail's capsules — places, or Plugins and Settings: a symbol in the system accent colour, as Finder's sidebar icons, grey in an inactive window; a quiet circle marks the selected one. |
| `RowIconButton` | `Buttons.swift` | A symbol button at a row's end, coloured by what it does (accent forward, red removal, orange retry), named on hover and for VoiceOver. |
| `RowStatusIcon` | `Buttons.swift` | A state at a row's end, as Installed: a coloured symbol, not a button. |
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
| `FormButtonBar` | `Surfaces.swift` | A step's buttons along the bottom of the work zone (in a `safeAreaBar`): a leading button, then Back and the default action last. |
| `ChoiceCard`, `ChoiceGrid` | `Choices.swift` | A card to choose (tile or symbol, title, detail; compact as one line) and the grid of them; `balanced` keeps a few cards in one row or two to a row. |
| `SavingsBadge` | `Rows.swift` | How much smaller, as a green "−N%" capsule. |
| `RowGroup` | `Rows.swift` | Rows in a quiet rounded box with hairlines, outside a form. |
| `ScreenHeading` | `Surfaces.swift` | A centred screen's title and subtitle. |
| `DropHighlight` | `Surfaces.swift` | The accent fill over the work zone while files are dragged over it. |

The window's toolbar — Back and the panel's button as system toolbar items — is `ShellToolbar` in `Sources/Views/Shell.swift`.
