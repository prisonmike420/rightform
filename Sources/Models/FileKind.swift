import Foundation

// MARK: - File kinds

/// How the Home wizard groups dropped files: by what a person would call
/// them, not by codec.
enum FileKind: Int, CaseIterable, Comparable, Sendable {
    case image
    case photo
    case animation
    case pdf
    case legacy

    init(_ format: ImageFormat) {
        if format == .pdf { self = .pdf }
        else if format.isAnimation { self = .animation }
        else if format == .raw || format == .tiff { self = .photo }
        else if format.isLegacy { self = .legacy }
        else { self = .image }
    }

    static func < (lhs: FileKind, rhs: FileKind) -> Bool { lhs.rawValue < rhs.rawValue }

    func title(count: Int) -> String {
        switch self {
        case .image: return count == 1 ? "1 image" : "\(count) images"
        case .photo: return count == 1 ? "1 camera photo" : "\(count) camera photos"
        case .animation: return count == 1 ? "1 animation" : "\(count) animations"
        case .pdf: return count == 1 ? "1 PDF" : "\(count) PDFs"
        case .legacy: return count == 1 ? "1 image in an old format" : "\(count) images in old formats"
        }
    }

    var symbolName: String {
        switch self {
        case .image: return "photo"
        case .photo: return "camera.aperture"
        case .animation: return "play.rectangle"
        case .pdf: return "doc.richtext"
        case .legacy: return "archivebox"
        }
    }
}

extension Routine {
    /// Whether the routine makes sense for these kinds of files.
    func fits(_ kinds: Set<FileKind>) -> Bool {
        switch self {
        case .chat, .email, .keep, .custom: return true
        case .website: return !kinds.contains(.legacy) || kinds.count > 1
        case .social: return kinds.isSubset(of: [.image, .photo, .animation])
        case .print: return kinds.isSubset(of: [.image, .photo, .pdf, .legacy])
        }
    }

    /// What the routine does, worded for these files: PDFs keep their text.
    func summary(for kinds: Set<FileKind>, canRemoveDetails: Bool) -> String {
        guard kinds == [.pdf] else { return summary(canRemoveDetails: canRemoveDetails) }
        switch self {
        case .chat: return "Lighter, text stays selectable"
        case .email: return "Small enough to attach, text kept"
        case .website: return "Lighter to download"
        case .social: return summary(canRemoveDetails: canRemoveDetails)
        case .print: return "Full quality"
        case .keep: return "Nothing lost"
        case .custom: return summary(canRemoveDetails: canRemoveDetails)
        }
    }
}

// MARK: - Processing planner

extension Routine {
    /// The per-file part of a routine: what this file becomes, given what
    /// it is. A screenshot or graphic stays PNG so text and transparency
    /// stay sharp; photos take the format the goal needs; formats that most
    /// places can't open become JPEG; for print and keeping, nothing changes
    /// format.
    func plan(for format: ImageFormat, _ base: SettingsSnapshot) -> SettingsSnapshot {
        var s = base
        switch self {
        case .website:
            switch format {
            case .jpeg, .heic, .avif, .tiff: s.output = .webp
            case .png, .webp: s.output = .keepOriginal
            default: s.output = .keepOriginal
            }
            s.photographyRAWOutput = .webp
        case .chat, .email, .social:
            switch format {
            case .heic, .avif, .tiff: s.output = .jpeg
            default: s.output = .keepOriginal
            }
            s.photographyRAWOutput = .jpeg
        case .print, .keep:
            s.output = .keepOriginal
        case .custom:
            // The format chosen in My Settings applies to every image.
            break
        }
        return s
    }
}
