import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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
        enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
    }

    /// The last known result. It stays while a new check runs, so only the
    /// check button reflects `isChecking`.
    private(set) var status: UpdateStatus = .checking
    private(set) var isChecking = false

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
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/prisonmike420/stou/releases/latest")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let release = try JSONDecoder().decode(Release.self, from: data)
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

    func openHomebrewUpdate() {
        let command = "for helper in /opt/homebrew/bin/stou /usr/local/bin/stou; do if [ -x \"$helper\" ]; then exec \"$helper\" update; fi; done; printf 'STOU was not found in Homebrew. Install it with: brew tap prisonmike420/stou https://github.com/prisonmike420/stou && brew install --cask prisonmike420/stou/stou\\n' >&2; exit 1"
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

