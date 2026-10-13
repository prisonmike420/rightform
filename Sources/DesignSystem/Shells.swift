import SwiftUI

// The interface's levels, top to bottom. Each level knows only the slots of
// the one below it:
//
// 1. WindowShell — the window's zones: the toolbar (the header), the rail,
//    the work zone and the inspector on the right.
// 2. Zone shells — what every zone is made of: RailShell and RailGroup,
//    WorkZoneShell (a workspace's bar, notice and drop highlight) and
//    InspectorShell.
// 3. Screen shells — what fills the work zone: FormScreen, StatusScreen and
//    ListScreen.
// 4. Components (the rest of Sources/DesignSystem) inside them.

// MARK: - 1. Window

/// The window: the toolbar along the top, the rail on the left, the work
/// zone in the middle, and the inspector on the right while it's shown,
/// which pushes the work zone's edge rather than covering files. The window
/// is titled with the place in front, never the app's name (HIG).
struct WindowShell<Rail: View, WorkZone: View, Inspector: View, Toolbar: ToolbarContent>: View {
    let title: String
    let showsInspector: Bool
    @ViewBuilder let rail: () -> Rail
    @ViewBuilder let workZone: () -> WorkZone
    @ViewBuilder let inspector: () -> Inspector
    @ToolbarContentBuilder let toolbar: () -> Toolbar

    var body: some View {
        HStack(spacing: 0) {
            rail()
            workZone()
                .frame(minWidth: Design.Layout.workZoneMinWidth, maxWidth: .infinity, maxHeight: .infinity)
            if showsInspector {
                inspector()
                    .frame(width: Design.Layout.panelWidth)
                    .glassSurface(minimumRadius: Design.Radius.panel)
                    .padding([.top, .trailing, .bottom], Design.Layout.panelInset)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Design.Motion.standard, value: showsInspector)
        .navigationTitle(title)
        .toolbar(content: toolbar)
    }
}

// MARK: - 2. Zones

/// The rail: its groups top to bottom, below the toolbar. They scroll
/// together when the window is short, so nothing sits at its bottom edge.
struct RailShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Design.Layout.buttonSpacing) { content }
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
        .padding(.top, Design.Layout.panelInset)
        .padding(.bottom, 12)
        .frame(width: Design.Layout.railWidth)
    }
}

/// One group of rail tabs in a glass capsule, grouped by function (HIG,
/// Toolbars): the places, or the second level.
struct RailGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 4) { content }
            .padding(5)
            .glassEffect(.regular, in: Capsule())
    }
}

/// A workspace's work zone around its screen: the light accent fill while
/// files are dragged over, a notice floating at the top, and the bar for
/// decisions on the file list along the bottom, where a Mac puts a step's
/// buttons.
struct WorkZoneShell<Screen: View, Bar: View, Notice: View>: View {
    let isDropTargeted: Bool
    let showsBar: Bool
    let showsNotice: Bool
    @ViewBuilder let screen: () -> Screen
    @ViewBuilder let bar: () -> Bar
    @ViewBuilder let notice: () -> Notice

    var body: some View {
        screen()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { if isDropTargeted { DropHighlight() } }
            .overlay(alignment: .top) {
                if showsNotice {
                    notice()
                        .padding(Design.Layout.overlayPadding)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(Design.Motion.standard, value: showsNotice)
            .safeAreaBar(edge: .bottom, spacing: 0) {
                if showsBar {
                    bar()
                        .padding(Design.Layout.overlayPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Design.Motion.standard, value: showsBar)
    }
}

/// The inspector, the panel on the right: one surface with no cards inside,
/// its title, then its rows, which take the panel's row and switch styles.
struct InspectorShell<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Design.Layout.panelPadding)
                .frame(maxWidth: .infinity, minHeight: Design.Layout.panelTitleHeight, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Design.Layout.panelPadding)
                    .padding(.bottom, Design.Layout.panelPadding)
                    .labeledContentStyle(PanelRowStyle())
                    .toggleStyle(PanelToggleStyle())
            }
        }
    }
}

// MARK: - 3. Screens

/// A screen of grouped sections, as System Settings draws them, and, for a
/// step of a job, its buttons along the bottom, as Mac assistants (Installer,
/// Migration Assistant) have them: a leading button such as Clear, then a
/// `Spacer`, then Back and the step's actions with the default one last.
struct FormScreen<Content: View, Actions: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        let form = Form { content }.formStyle(.grouped)
        if Actions.self == EmptyView.self {
            form
        } else {
            form
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    FormButtonBar { actions }
                }
                // A firm edge between the sections scrolling under and the
                // buttons, so text never runs behind them.
                .scrollEdgeEffectStyle(.hard, for: .bottom)
        }
    }
}

extension FormScreen where Actions == EmptyView {
    /// A screen of sections with no buttons of its own.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.actions = EmptyView()
    }
}

/// A centred screen for a state rather than a list: the empty workspace,
/// progress, done.
struct StatusScreen<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: spacing) { content }
            .padding(Design.Layout.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A screen that is one list of rows, on the work zone's own background.
struct ListScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        List { content }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
    }
}
