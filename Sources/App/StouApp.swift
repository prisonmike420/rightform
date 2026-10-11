import SwiftUI
import AppKit

@main
struct StouApp: App {
    // The App value is created once per process, so it can own the models
    // directly. (The @State macro for Observable classes needs Xcode's
    // SwiftUIMacros plugin, which the Command Line Tools do not include.)
    private let settings: AppSettings
    private let stats: StatisticsStore
    private let extensions: ExtensionManager
    private let model: CompressionModel
    private let updates: UpdateChecker

    init() {
        RightformMigration.run()
        Staging.clearLeftovers()
        Results.prune(olderThan: 86_400)
        let settings = AppSettings()
        let stats = StatisticsStore()
        self.settings = settings
        self.stats = stats
        extensions = ExtensionManager()
        updates = UpdateChecker()
        // Every launch asks GitHub right away; later checks, such as reopening
        // the window or Settings, wait a day.
        updates.check(force: true)
        model = CompressionModel(settings: settings, stats: stats)
        model.extensions = extensions
    }

    var body: some Scene {
        // Stou works on one batch at a time, so it uses a single window
        // rather than a document-style WindowGroup.
        Window("Stou", id: StouApp.mainWindowID) {
            // Opens compact, 480 × 600; it can be resized and taken full screen.
            ContentView()
                .frame(minWidth: 420, minHeight: 480)
                .onAppear { settings.appearance.apply() }
                .onOpenURL { url in
                    model.add(urls: [url])
                }
                .environment(settings)
                .environment(stats)
                .environment(extensions)
                .environment(model)
                .environment(updates)
        }
        .defaultSize(width: 480, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            StouCommands(settings: settings, model: model, updates: updates)
        }
    }

    static let mainWindowID = "main"
}

struct StouCommands: Commands {
    let settings: AppSettings
    let model: CompressionModel
    let updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    private static let repository = URL(string: "https://github.com/prisonmike420/stou")!

    var body: some Commands {
        // About and Settings are one page of the main window.
        CommandGroup(replacing: .appInfo) {
            Button("About Stou") { showSettings() }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { showSettings() }
                .keyboardShortcut(",")
        }

        CommandGroup(replacing: .newItem) {
            Button("Add Files…") {
                openWindow(id: StouApp.mainWindowID)
                model.pickFiles()
            }
            .keyboardShortcut("o")
            .disabled(model.isProcessing)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Clear List") { model.clearAll() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(model.isProcessing || model.items.isEmpty)
        }

        CommandMenu("Batch") {
            Button("Show in Finder") { model.revealResults() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!model.hasRevealableResults)
            Divider()
            Button("Stop") { model.cancelBatch() }
                .keyboardShortcut(".")
                .disabled(!model.isProcessing || model.isCancelling)
        }

        // Help: where to get support and what changed, and updates. Stou
        // has no help book, so the system's Help search item is replaced.
        CommandGroup(replacing: .help) {
            Button("Get Support") {
                NSWorkspace.shared.open(Self.repository.appendingPathComponent("issues"))
            }
            Button("Release Notes") {
                NSWorkspace.shared.open(Self.repository.appendingPathComponent("releases"))
            }
            Button("Source Code") {
                NSWorkspace.shared.open(Self.repository)
            }
            Divider()
            if case .available(let version) = updates.status {
                Button("Update to \(version.trimmingCharacters(in: CharacterSet(charactersIn: "v")))") {
                    showSettings()
                    updates.update()
                }
                .disabled(model.isProcessing)
            } else {
                // Opens Settings, which shows the result.
                Button("Check for Updates…") {
                    showSettings()
                    updates.check(force: true)
                }
                .disabled(updates.isChecking)
            }
        }
    }

    private func showSettings() {
        settings.selection = .settings
        openWindow(id: StouApp.mainWindowID)
    }
}
