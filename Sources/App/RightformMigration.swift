import Foundation

/// Stou was called Rightform until 0.19. Its bundle identifier and data
/// folder changed with the name, so on the first launch after the rename
/// this carries over what the old app kept. Runs before anything reads
/// settings or touches Application Support.
enum RightformMigration {
    private static let oldBundleID = "com.rightform.app"
    private static let doneKey = "migratedFromRightform"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        migrateSettings(into: defaults)
        migrateDataFolder()
        defaults.set(true, forKey: doneKey)
    }

    /// Copies the old app's preferences, unless Stou already has its own.
    private static func migrateSettings(into defaults: UserDefaults) {
        guard let newID = Bundle.main.bundleIdentifier,
              defaults.persistentDomain(forName: newID)?.isEmpty ?? true,
              let old = defaults.persistentDomain(forName: oldBundleID) else { return }
        for (key, value) in old {
            defaults.set(value, forKey: key)
        }
    }

    /// Moves ~/Library/Application Support/Rightform to …/Stou and leaves a
    /// link behind: plugins built from source may refer to their old path.
    private static func migrateDataFolder() {
        let fm = FileManager.default
        let support = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let old = support.appendingPathComponent("Rightform", isDirectory: true)
        let new = support.appendingPathComponent("Stou", isDirectory: true)

        let oldIsLink = (try? old.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
        guard !oldIsLink,
              fm.fileExists(atPath: old.path),
              !fm.fileExists(atPath: new.path) else { return }
        do {
            try fm.moveItem(at: old, to: new)
            try fm.createSymbolicLink(at: old, withDestinationURL: new)
        } catch {
            // Leave whatever is there; plugins can be reinstalled from Plugins.
        }
    }
}
