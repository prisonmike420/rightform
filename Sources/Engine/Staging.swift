import Foundation

// MARK: - Staging

/// Intermediate files live in ~/Library/Application Support/STOU/Staging,
/// one folder per job, instead of the shared system temporary directory.
/// A job's folder is removed when the job ends; anything left behind by a
/// crash is cleared on the next launch.
///
/// Final outputs are still written next to their destination first, so the
/// last rename stays on one volume and is atomic.
enum Staging {
    @TaskLocal static var jobDirectory: URL?

    static let root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/STOU/Staging", isDirectory: true)

    /// The current job's folder, or a shared folder for work outside a job
    /// such as a PDF preflight.
    static var directory: URL {
        let url = jobDirectory ?? root.appendingPathComponent("shared", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func file(_ name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Runs `body` with its own staging folder and removes the folder afterwards.
    static func withJob<T>(_ body: () throws -> T) rethrows -> T {
        let folder = root.appendingPathComponent("job-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        return try $jobDirectory.withValue(folder, operation: body)
    }

    /// Called once at launch, before any job can start.
    static func clearLeftovers() {
        try? FileManager.default.removeItem(at: root)
    }
}

// MARK: - Results

/// Prepared files wait in ~/Library/Application Support/STOU/Results,
/// one folder per batch, until they are delivered. Saved files move out
/// and their folder goes; copied or shared files stay as long as they may
/// still be pasted or sent.
enum Results {
    static let root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/STOU/Results", isDirectory: true)

    static func makeBatchFolder() throws -> URL {
        let folder = root.appendingPathComponent("batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Removes batch folders other than `keeping`. At launch, only those
    /// older than a day go, so a copy made just before quitting still pastes.
    static func prune(keeping: Set<URL> = [], olderThan age: TimeInterval = 0) {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let keep = Set(keeping.map(\.standardizedFileURL))
        for folder in folders where !keep.contains(folder.standardizedFileURL) {
            if age > 0,
               let date = try? folder.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               Date().timeIntervalSince(date) < age {
                continue
            }
            try? fm.removeItem(at: folder)
        }
    }

    static func removeIfEmpty(_ folder: URL) {
        let fm = FileManager.default
        if (try? fm.contentsOfDirectory(atPath: folder.path))?.isEmpty ?? false {
            try? fm.removeItem(at: folder)
        }
    }
}
