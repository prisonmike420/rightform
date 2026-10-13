import SwiftUI
import AppKit

// Renders Stou's screens in windows of their own and saves each as a PNG,
// to check layout without driving the app. Built by
// scripts/snapshot-screens.sh with every source except
// Sources/App/StouApp.swift, which holds @main.
//
// Each window shows for about a second at the screen's bottom-left corner
// and is captured by the window server (`screencapture -l`), so glass and
// bars along the bottom draw as they do in the app; drawing a view into a
// bitmap leaves those out. Windows behind it don't matter. It needs the
// Screen Recording permission the terminal already has for screencapture.
// The models use this program's own defaults domain, not the app's, so
// nothing in the real Stou changes.
@main
struct SnapshotHarness {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            FileHandle.standardError.write(Data("Usage: stou-snapshots <output folder> <sample file>…\n".utf8))
            exit(64)
        }
        let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let samples = arguments.dropFirst(2).map { URL(fileURLWithPath: $0) }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let settings = AppSettings()
        let stats = StatisticsStore()
        let extensions = ExtensionManager()
        let updates = UpdateChecker()
        let model = CompressionModel(settings: settings, stats: stats)
        model.extensions = extensions

        func snap<V: View>(_ name: String, width: CGFloat = 620, height: CGFloat = 560, _ view: V) {
            let root = view
                .environment(settings)
                .environment(stats)
                .environment(extensions)
                .environment(model)
                .environment(updates)
                .frame(width: width, height: height)
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: root)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.orderFrontRegardless()
            // Long enough for thumbnails and layout to settle.
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            defer { window.close() }
            let file = output.appendingPathComponent("\(name).png")
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), file.path]
            do {
                try capture.run()
                capture.waitUntilExit()
                guard capture.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
                print(file.path)
            } catch {
                FileHandle.standardError.write(Data("Couldn’t capture \(name): \(error.localizedDescription)\n".utf8))
            }
        }

        // Zones
        snap("rail", width: Design.Layout.railWidth, height: 520, AppRail())
        snap("inspector", width: Design.Layout.panelWidth, height: 520, WorkspaceInspector())

        // The workspace's states, in a job's order
        snap("workspace-empty", WorkspaceView())
        model.add(urls: samples)
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        snap("workspace-choose", height: 760, WorkspaceView())
        // Choosing a routine leads to Where to?.
        model.start(.routine(.website))
        snap("whereto-next-to-originals", height: 620, WorkspaceView())
        model.deliveryChoice = .folder(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true))
        snap("whereto-folder", WhereToScreen())
        model.deliveryChoice = .share
        snap("whereto-share", WhereToScreen())

        // A job under way: the files and the batch bar, with made-up states.
        // Nothing is prepared for real, so nothing is written.
        for index in model.items.indices.prefix(2) {
            model.items[index].outputBytes = model.items[index].originalBytes / 5
            model.items[index].state = .done
        }
        if model.items.count > 2 { model.items[2].state = .squeezing }
        model.isProcessing = true
        snap("working", height: 620, WorkZoneShell(isDropTargeted: false, showsBar: true, showsNotice: false) {
            FileListView()
        } bar: {
            BatchBar()
        } notice: {
            EmptyView()
        })
        model.isProcessing = false

        // The done screen, with made-up results for the samples.
        for index in model.items.indices {
            model.items[index].outputBytes = model.items[index].originalBytes * Int64(15 + index * 5) / 100
            model.items[index].state = .done
        }
        snap("done", height: 620, JobDoneScreen())

        // The second level
        snap("store", width: 760, height: 700, PluginStoreView())
        snap("settings", width: 760, height: 700, SettingsPage())
    }
}
