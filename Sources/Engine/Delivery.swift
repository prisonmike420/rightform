import AppKit
import Foundation

// MARK: - Delivery

/// Where prepared files go, chosen for each job in Where to?.
enum Delivery: Hashable, Sendable {
    case nextToOriginals
    case folder(URL)
    case copy
    case share

    /// Whether originals can be moved to the Trash afterwards: only when
    /// the new files are saved somewhere for good.
    var canTrashOriginals: Bool {
        switch self {
        case .nextToOriginals, .folder: return true
        case .copy, .share: return false
        }
    }
}

/// Delivers a batch's prepared files from its Results folder and applies
/// what happens to the originals afterwards. Originals go to the Trash only
/// after their new file is in place, never by deletion, and RAW originals
/// are always kept.
enum DeliveryManager {
    struct File {
        let original: URL
        let originalFormat: ImageFormat
        let prepared: URL
    }

    struct Outcome {
        /// Where each prepared file ended up, by original.
        var delivered: [URL: URL] = [:]
        var failures: [URL: String] = [:]
    }

    static func deliver(
        _ files: [File],
        to delivery: Delivery,
        trashOriginals: Bool,
        prefix: String,
        suffix: String,
        preserveModificationDate: Bool
    ) -> Outcome {
        var outcome = Outcome()
        let fm = FileManager.default

        for file in files {
            do {
                switch delivery {
                case .copy, .share:
                    // They stay in the Results folder while they may be used.
                    outcome.delivered[file.original] = file.prepared

                case .nextToOriginals, .folder:
                    let directory: URL
                    if case .folder(let folder) = delivery {
                        directory = folder
                    } else {
                        directory = file.original.deletingLastPathComponent()
                    }
                    try fm.createDirectory(at: directory, withIntermediateDirectories: true)

                    let trash = trashOriginals && delivery.canTrashOriginals && file.originalFormat != .raw
                    let stem = file.original.deletingPathExtension().lastPathComponent
                    let ext = file.prepared.pathExtension
                    // Next to an original that goes to the Trash, the new
                    // file takes its name; otherwise it gets the suffix.
                    let name: String
                    if case .nextToOriginals = delivery, !trash {
                        let base = Compressor.outputStem(stem, prefix: prefix, suffix: suffix)
                        name = "\(prefix)\(base)\(suffix)"
                    } else {
                        name = stem
                    }

                    if trash, fm.fileExists(atPath: file.original.path) {
                        try fm.trashItem(at: file.original, resultingItemURL: nil)
                    }
                    let target = uniqueURL(in: directory, name: name, extension: ext)
                    try fm.moveItem(at: file.prepared, to: target)
                    if preserveModificationDate,
                       let date = try? file.original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        try? fm.setAttributes([.modificationDate: date], ofItemAtPath: target.path)
                    }
                    outcome.delivered[file.original] = target
                }
            } catch {
                outcome.failures[file.original] = error.localizedDescription
            }
        }
        return outcome
    }

    /// Puts the files on the clipboard, as files, so they paste into Finder,
    /// Mail, Messages or a chat.
    @MainActor
    static func copyToPasteboard(_ urls: [URL]) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        return pasteboard.changeCount
    }

    private static func uniqueURL(in directory: URL, name: String, extension ext: String) -> URL {
        let fm = FileManager.default
        var candidate = directory.appendingPathComponent(name).appendingPathExtension(ext)
        var number = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name)_\(number)").appendingPathExtension(ext)
            number += 1
        }
        return candidate
    }
}
