import Foundation
import CryptoKit

// MARK: - Engines built by Stou

/// An engine Stou builds itself (scripts/build-engine.sh) and hosts as a
/// release asset, so a plugin can install it without Homebrew. The catalogue
/// lives in Resources/engines.json; an engine that isn't listed there is still
/// installed the old way.
struct EnginePackage: Decodable {
    let version: String
    let url: URL
    let sha256: String
}

enum EngineInstaller {
    private struct Catalog: Decodable {
        let schemaVersion: Int
        let engines: [String: EnginePackage]
    }

    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Stou/Engines", isDirectory: true)

    /// The packaged engine called `name`, or nil when Stou doesn't host one.
    static func package(for name: String) -> EnginePackage? {
        guard let url = Bundle.main.url(forResource: "engines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data),
              catalog.schemaVersion == 1 else { return nil }
        return catalog.engines[name]
    }

    /// Downloads, verifies and installs one engine under Engines/<name>.
    /// Throws a message that says what failed. Blocks until done.
    static func install(_ name: String, package: EnginePackage) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let stage = root.appendingPathComponent(".stage-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: stage) }

        let archive = try download(package.url)
        defer { try? fm.removeItem(at: archive) }
        guard try sha256(of: archive) == package.sha256.lowercased() else {
            throw CompressionError.message("The \(name) download failed verification (SHA-256 mismatch). Nothing was installed.")
        }

        guard let ditto = Toolchain.locate("ditto") else {
            throw CompressionError.message("macOS archive tool is unavailable.")
        }
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        try ProcessRunner.runVoid(ditto, ["-x", "-k", archive.path, stage.path])
        // ditto copies a quarantine mark from the archive onto what it unpacks.
        removeQuarantine(under: stage)

        let candidate = stage.appendingPathComponent(name, isDirectory: true)
        guard fm.fileExists(atPath: candidate.appendingPathComponent("bin").path) else {
            throw CompressionError.message("The \(name) package has an unexpected layout. Nothing was installed.")
        }

        let destination = root.appendingPathComponent(name, isDirectory: true)
        let backup = root.appendingPathComponent(".\(name)-backup-\(UUID().uuidString)", isDirectory: true)
        if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: backup) }
        do {
            try fm.moveItem(at: candidate, to: destination)
            try? fm.removeItem(at: backup)
        } catch {
            if fm.fileExists(atPath: backup.path) { try? fm.moveItem(at: backup, to: destination) }
            throw error
        }
    }

    private static func download(_ url: URL) throws -> URL {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var location: URL?
        nonisolated(unsafe) var failure: Error?
        let task = URLSession.shared.downloadTask(with: url) { temporary, response, error in
            defer { semaphore.signal() }
            if let error { failure = error; return }
            guard (response as? HTTPURLResponse)?.statusCode == 200, let temporary else {
                failure = CompressionError.message("Could not download \(url.lastPathComponent).")
                return
            }
            // The system deletes the temporary file when this handler returns.
            let kept = FileManager.default.temporaryDirectory.appendingPathComponent("stou-engine-\(UUID().uuidString).zip")
            do { try FileManager.default.moveItem(at: temporary, to: kept); location = kept } catch { failure = error }
        }
        task.resume()
        semaphore.wait()
        if let failure { throw failure }
        guard let location else { throw CompressionError.message("Could not download \(url.lastPathComponent).") }
        return location
    }

    private static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func removeQuarantine(under directory: URL) {
        let names = FileManager.default.enumerator(atPath: directory.path)?.allObjects as? [String] ?? []
        for path in [directory.path] + names.map({ directory.appendingPathComponent($0).path }) {
            removexattr(path, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }
}
