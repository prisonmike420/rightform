import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit
import CryptoKit

// MARK: - Homebrew updates

enum UpdateStatus: Equatable {
    /// Not known yet: no check has finished since launch.
    case checking
    case current
    case available(version: String)
    case unavailable
}

@MainActor
@Observable
final class UpdateChecker {
    private static let lastCheckKey = "lastUpdateCheck"
    private static let latestReleaseKey = "latestRelease"
    private static let automaticCheckInterval: TimeInterval = 86_400
    private struct Release: Decodable {
        let tagName: String
        let assets: [Asset]
        enum CodingKeys: String, CodingKey { case tagName = "tag_name", assets }
    }
    private struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        /// GitHub's checksum of the uploaded file, as `sha256:<hex>`.
        let digest: String?
        enum CodingKeys: String, CodingKey { case name, browserDownloadURL = "browser_download_url", digest }
    }

    /// Where an update installed by Stou itself stands. A Homebrew install
    /// updates in Terminal instead and stays `.idle`.
    enum InstallStep: Equatable {
        case idle
        /// Upgrading plugins' Homebrew formulae, before Stou itself.
        case updatingPlugins
        case downloading
        case installing
        case failed(String)
        /// The plugins couldn't be updated; Stou itself wasn't touched, so
        /// there is no release page to offer.
        case pluginsFailed(String)
    }

    /// The last known result. It stays while a new check runs, so only the
    /// check button reflects `isChecking`.
    private(set) var status: UpdateStatus = .checking
    private(set) var isChecking = false
    private(set) var installStep: InstallStep = .idle
    private var installTask: Task<Void, Never>?

    func check(force: Bool = false) {
        let defaults = UserDefaults.standard
        if !force,
           let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.automaticCheckInterval {
            // A release found earlier stays offered until it is installed.
            if let latest = defaults.string(forKey: Self.latestReleaseKey), Self.isNewer(latest, than: Self.currentVersion) {
                status = .available(version: latest)
            } else {
                status = .current
            }
            return
        }
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                let release = try await Self.latestRelease()
                status = Self.isNewer(release.tagName, than: Self.currentVersion) ? .available(version: release.tagName) : .current
                defaults.set(Date(), forKey: Self.lastCheckKey)
                defaults.set(release.tagName, forKey: Self.latestReleaseKey)
            } catch {
                status = .unavailable
            }
        }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/prisonmike420/stou/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    static let releasesPage = URL(string: "https://github.com/prisonmike420/stou/releases/latest")!

    /// Installed from the Cask, Homebrew owns the app and updates it.
    private static var installedWithHomebrew: Bool {
        ["/opt/homebrew/bin/stou", "/usr/local/bin/stou"].contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Whether Stou or any installed plugin has a newer version. To the
    /// person using Stou these are one update: the plugins are part of it.
    func hasUpdate(_ extensions: ExtensionManager) -> Bool {
        if case .available = status { return true }
        return !extensions.pluginsWithUpdates.isEmpty
    }

    /// Asks GitHub about Stou and Homebrew about the plugins' engines.
    func checkAll(_ extensions: ExtensionManager) {
        check(force: true)
        extensions.checkFormulaeUpdates(force: true)
    }

    /// Every update in one go: the plugins first, because updating Stou
    /// itself quits it. Stou updates through Homebrew in Terminal when it
    /// came from the Cask; otherwise it downloads the release, replaces this
    /// app and reopens it. If the plugins fail, Stou waits, so the failure
    /// stays on screen.
    func update(_ extensions: ExtensionManager) {
        guard installTask == nil else { return }
        installStep = .idle
        installTask = Task {
            defer { installTask = nil }
            if !extensions.pluginsWithUpdates.isEmpty {
                installStep = .updatingPlugins
                if let failure = await extensions.updateOutdatedPlugins() {
                    installStep = .pluginsFailed("The update didn’t finish: \(failure) Try again.")
                    return
                }
                installStep = .idle
            }
            guard case .available = status else { return }
            if Self.installedWithHomebrew {
                openHomebrewUpdate()
            } else {
                await install()
            }
        }
    }

    /// Stops a download. Once the app is being replaced it can't be stopped.
    func cancelUpdate() {
        guard installStep == .downloading else { return }
        installTask?.cancel()
    }

    private func install() async {
        let app = Bundle.main.bundleURL
        // Opened straight from the disk image (or a download macOS moved
        // aside), the app runs from a read-only copy it can't replace.
        if app.path.contains("/AppTranslocation/") || app.path.hasPrefix("/Volumes/") {
            installStep = .failed("Stou is running from the disk image or a download folder macOS protects. Drag Stou to Applications, open it from there and update again.")
            return
        }
        let folder = app.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            installStep = .failed("Stou can’t replace itself in “\(folder.lastPathComponent)”. Download the new version from the release page and drag it there.")
            return
        }
        installStep = .downloading
        do {
            let release = try await Self.latestRelease()
            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            guard let asset = release.assets.first(where: { $0.name == "Stou-\(version).zip" }),
                  let digest = asset.digest, digest.hasPrefix("sha256:") else {
                throw CompressionError.message("Release \(version) has no download Stou can check. Download it from the release page instead.")
            }
            let (download, response) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            try Task.checkCancellation()
            installStep = .installing
            try await Task.detached {
                try Self.replace(app, with: download, version: version, sha256: String(digest.dropFirst("sha256:".count)))
            }.value
            Self.reopen(app)
        } catch is CancellationError {
            installStep = .idle
        } catch let error as URLError where error.code == .cancelled {
            installStep = .idle
        } catch let error as CompressionError {
            installStep = .failed(error.description)
        } catch {
            installStep = .failed("The download failed: \(error.localizedDescription) Check the connection and try again.")
        }
    }

    /// Checks the downloaded ZIP and swaps it in for the running app. The
    /// old app stays in place until the new one is complete and checked.
    nonisolated private static func replace(_ app: URL, with zip: URL, version: String, sha256: String) throws {
        let data = try Data(contentsOf: zip, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == sha256.lowercased() else {
            throw CompressionError.message("The download is damaged: it doesn’t match the release. Try again.")
        }
        let fileManager = FileManager.default
        // On the app's own volume, so the swap below is a rename.
        let work = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: app, create: true)
        defer { try? fileManager.removeItem(at: work) }
        try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", zip.path, work.path])
        let newApp = work.appendingPathComponent("Stou/Stou.app")
        guard let bundle = Bundle(url: newApp),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version else {
            throw CompressionError.message("The download doesn’t contain Stou \(version). Download it from the release page instead.")
        }
        let check = try ProcessRunner.runWithStatus(URL(fileURLWithPath: "/usr/bin/codesign"), ["--verify", "--deep", newApp.path])
        guard check.status == 0 else {
            throw CompressionError.message("The downloaded app is incomplete. Try again.")
        }
        do {
            _ = try fileManager.replaceItemAt(app, withItemAt: newApp)
        } catch {
            throw CompressionError.message("Stou couldn’t replace itself: \(error.localizedDescription) Download the new version from the release page instead.")
        }
    }

    /// Quits, and opens the new app once this process has gone.
    private static func reopen(_ app: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"", app.path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private func openHomebrewUpdate() {
        let command = "for helper in /opt/homebrew/bin/stou /usr/local/bin/stou; do if [ -x \"$helper\" ]; then exec \"$helper\" update; fi; done; printf 'Stou was not found in Homebrew. Install it with: brew tap prisonmike420/stou https://github.com/prisonmike420/stou && brew install --cask prisonmike420/stou/stou\\n' >&2; exit 1"
        let shellCommand = "/bin/zsh -lc \(Self.shellQuote(command))"
        let script = "tell application \"Terminal\"\nactivate\ndo script \"\(Self.appleScriptString(shellCommand))\"\nend tell"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    private static func shellQuote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func isNewer(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }
        let currentParts = current.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(remoteParts.count, currentParts.count) {
            let left = index < remoteParts.count ? remoteParts[index] : 0
            let right = index < currentParts.count ? currentParts[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}

