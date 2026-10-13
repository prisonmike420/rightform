import SwiftUI
import AppKit

// Renders Stou's screens in offscreen windows and saves each as a PNG, to
// check layout without driving the app. Built by scripts/snapshot-screens.sh
// with every source except Sources/App/StouApp.swift, which holds @main.
//
// Liquid Glass doesn't render offscreen: the rail's capsules and the
// panel's glass are missing. The models use this program's own defaults
// domain, not the app's, so nothing in the real Stou changes.
@main
struct SnapshotHarness {
    @MainActor static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            FileHandle.standardError.write(Data("Usage: stou-snapshots <output folder> <sample image>\n".utf8))
            exit(64)
        }
        let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let sample = URL(fileURLWithPath: arguments[2])

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
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.orderFrontRegardless()
            // Long enough for thumbnails and layout to settle.
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            host.layoutSubtreeIfNeeded()
            defer { window.close() }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            let file = output.appendingPathComponent("\(name).png")
            do {
                try rep.representation(using: .png, properties: [:])?.write(to: file)
                print(file.path)
            } catch {
                FileHandle.standardError.write(Data("Couldn’t write \(file.path): \(error.localizedDescription)\n".utf8))
            }
        }

        // Zones
        snap("rail", width: Design.Layout.railWidth, height: 520, AppRail())
        snap("inspector", width: Design.Layout.panelWidth, height: 520, WorkspaceInspector())

        // The workspace's states, in a job's order
        snap("workspace-empty", WorkspaceView())
        model.add(urls: [sample])
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        snap("workspace-choose", WorkspaceView())
        snap("progress", JobProgressScreen())
        model.deliveryChoice = .nextToOriginals
        snap("whereto-next-to-originals", WhereToScreen())
        model.deliveryChoice = .folder(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true))
        snap("whereto-folder", WhereToScreen())
        model.deliveryChoice = .share
        snap("whereto-share", WhereToScreen())

        // The second level
        snap("store", width: 760, height: 700, PluginStoreView())
        snap("settings", width: 760, height: 700, SettingsPage())
    }
}
