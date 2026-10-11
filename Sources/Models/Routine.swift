import SwiftUI

// MARK: - Routines

/// What the files are for, in the words a person would use. A routine sets
/// the goal-level parts of processing — quality, size, format, colour and
/// hidden details — on top of the plugin settings, which keep the finer
/// format controls. Delivery and originals follow General settings. Every
/// routine but `custom` sets all of these itself, so My Settings never
/// change what the others do.
enum Routine: String, CaseIterable, Identifiable, Sendable {
    case chat
    case email
    case website
    case social
    case print
    case keep
    /// The user's own size, format, quality, colour and details, set under
    /// My Settings in Settings.
    case custom

    var id: Self { self }

    /// Completes "I want to …".
    var title: String {
        switch self {
        case .chat: return "Send in a chat"
        case .email: return "Attach to an email"
        case .website: return "Put on a website"
        case .social: return "Post on social media"
        case .print: return "Print"
        case .keep: return "Keep for later"
        case .custom: return "Use my settings"
        }
    }

    var symbolName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .email: return "envelope"
        case .website: return "globe"
        case .social: return "person.2"
        case .print: return "printer"
        case .keep: return "archivebox"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// What will happen to the files, in plain words. It only promises
    /// removing hidden details when Metadata Cleaner is installed.
    func summary(canRemoveDetails: Bool) -> String {
        switch self {
        case .chat:
            return canRemoveDetails ? "Lighter, sharp text, location removed" : "Lighter, sharp text"
        case .email:
            return "Small enough to attach"
        case .website:
            return canRemoveDetails ? "Web size and format, details removed" : "Web size and format"
        case .social:
            return canRemoveDetails ? "Feed size, private details removed" : "Feed size, colors that look right"
        case .print:
            return "Full size and quality"
        case .keep:
            return "Nothing lost, all details kept"
        case .custom:
            return "Size, format and quality from Settings"
        }
    }

    /// The routine's part of the processing settings.
    func apply(to base: SettingsSnapshot, canRemoveDetails: Bool) -> SettingsSnapshot {
        var s = base
        let removeDetails: MetadataMode = canRemoveDetails ? .removeAll : .keep

        switch self {
        case .chat:
            s.mode = .recommended
            s.output = .keepOriginal
            s.resizeMode = .maxLongEdge
            s.resizeSize = 2048
            s.allowLossyOptimization = true
            s.optimizeColorForSharing = true
            s.preserveColorProfile = true
            s.metadataMode = removeDetails
            s.pdfCompressionMode = .balanced
        case .email:
            s.mode = .smaller
            s.output = .keepOriginal
            s.resizeMode = .maxLongEdge
            s.resizeSize = 1600
            s.allowLossyOptimization = true
            s.optimizeColorForSharing = true
            s.preserveColorProfile = true
            s.metadataMode = .keep
            // Smaller, but text and vectors stay selectable.
            s.pdfCompressionMode = .aggressive
        case .website:
            s.mode = .recommended
            // The format for each file is planned in `plan(for:_:)`.
            s.output = .keepOriginal
            s.resizeMode = .maxLongEdge
            s.resizeSize = 2400
            s.allowLossyOptimization = true
            s.optimizeColorForSharing = true
            s.preserveColorProfile = true
            s.metadataMode = removeDetails
            s.pdfCompressionMode = .balanced
        case .social:
            s.mode = .recommended
            s.output = .keepOriginal
            s.resizeMode = .maxLongEdge
            s.resizeSize = 2048
            s.allowLossyOptimization = true
            s.optimizeColorForSharing = true
            s.preserveColorProfile = true
            s.metadataMode = removeDetails
            s.pdfCompressionMode = .balanced
        case .print:
            s.mode = .bestQuality
            s.output = .keepOriginal
            s.resizeMode = .original
            s.allowLossyOptimization = false
            s.optimizeColorForSharing = false
            s.preserveColorProfile = true
            s.metadataMode = .keep
            s.pdfCompressionMode = .light
        case .keep:
            s.mode = .bestQuality
            s.output = .keepOriginal
            s.resizeMode = .original
            s.allowLossyOptimization = false
            s.optimizeColorForSharing = false
            s.preserveColorProfile = true
            s.metadataMode = .keep
            s.pdfCompressionMode = .light
        case .custom:
            // My Settings are the base settings themselves.
            break
        }
        return s
    }
}
