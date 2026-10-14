import Foundation

// MARK: - Plugin workspaces

/// Each installed plugin has its own workspace in the sidebar: a drop zone
/// that does that plugin's one job. Unlike a routine it takes only the
/// formats the plugin works with, and it uses the plugin's own settings.
extension ExtensionID {
    /// Completes "Drop files to …".
    var workspaceAction: String {
        switch self {
        case .imageProcessing: return "make them lighter"
        case .highQualityJPEG: return "make JPEGs lighter with jpegli"
        case .applePhotos: return "turn them into JPEG"
        case .photography: return "turn them into everyday images"
        case .animation: return "make animations lighter"
        case .legacyFormats: return "turn them into modern formats"
        case .metadataCleaner: return "remove hidden details"
        case .aiProvenance: return "check them for AI labels"
        case .pdfTools: return "make PDFs lighter"
        case .markdown: return "turn them into Markdown"
        }
    }

    /// The empty workspace's title and hint.
    var dropTitle: String {
        switch self {
        case .imageProcessing, .metadataCleaner, .aiProvenance: return "Drop images here"
        case .highQualityJPEG: return "Drop JPEGs here"
        case .applePhotos: return "Drop HEIC or AVIF images here"
        case .photography: return "Drop camera photos here"
        case .animation: return "Drop animations here"
        case .legacyFormats: return "Drop old images here"
        case .pdfTools: return "Drop PDFs here"
        case .markdown: return "Drop web pages here"
        }
    }

    var dropHint: String {
        switch self {
        case .imageProcessing: return "They’ll get lighter and keep their format."
        case .highQualityJPEG: return "They’ll get lighter with jpegli."
        case .applePhotos: return "They’ll become JPEG, which opens anywhere."
        case .photography: return "They’ll become everyday images. RAW files are kept."
        case .animation: return "They’ll get lighter and keep moving."
        case .legacyFormats: return "They’ll become formats that open anywhere."
        case .metadataCleaner: return "Location and camera details will be removed."
        case .aiProvenance: return "They’ll be checked for AI labels. Nothing is changed."
        case .pdfTools: return "They’ll get lighter. Text stays selectable."
        case .markdown: return "They’ll become Markdown notes with their title, author and date."
        }
    }

    /// The formats the workspace takes, in plain words.
    var workspaceFormats: String {
        switch self {
        case .imageProcessing: return "JPEG, PNG and WebP"
        case .highQualityJPEG: return "JPEG"
        case .applePhotos: return "HEIC, HEIF and AVIF"
        case .photography: return "RAW, DNG and TIFF"
        case .animation: return "GIF, APNG and animated WebP"
        case .legacyFormats: return "BMP, TGA, PCX, PICT and other old formats"
        case .metadataCleaner: return "JPEG, PNG, WebP, HEIC, AVIF and TIFF"
        case .aiProvenance: return "JPEG, PNG and WebP"
        case .pdfTools: return "PDF"
        case .markdown: return "HTML"
        }
    }

    func workspaceAccepts(_ format: ImageFormat) -> Bool {
        switch self {
        case .imageProcessing, .aiProvenance: return [.jpeg, .png, .webp].contains(format)
        case .highQualityJPEG: return format == .jpeg
        case .applePhotos: return [.heic, .avif].contains(format)
        case .photography: return [.raw, .tiff].contains(format)
        case .animation: return format.isAnimation
        case .legacyFormats: return format.isLegacy
        case .metadataCleaner: return [.jpeg, .png, .webp, .heic, .avif, .tiff].contains(format)
        case .pdfTools: return format == .pdf
        case .markdown: return format == .html
        }
    }

    /// The workspace's processing settings on top of the plugins' own. Only
    /// the plugin's job changes the files; everything else stays as it was.
    func applyWorkspace(to base: SettingsSnapshot) -> SettingsSnapshot {
        var s = base
        // Untouched unless the job needs it: same format, size and details.
        s.output = .keepOriginal
        s.resizeMode = .original
        s.metadataMode = .keep
        s.optimizeColorForSharing = false
        s.preserveColorProfile = true

        switch self {
        case .imageProcessing, .animation:
            s.mode = .recommended
            s.allowLossyOptimization = true
        case .highQualityJPEG:
            s.mode = .recommended
            s.allowLossyOptimization = true
            s.useHighQualityJPEG = true
        case .applePhotos:
            s.mode = .recommended
            s.output = .jpeg
            s.allowLossyOptimization = true
            s.optimizeColorForSharing = true
        case .photography, .legacyFormats, .pdfTools, .markdown:
            // Their own settings decide the output.
            s.mode = .recommended
        case .metadataCleaner:
            s.mode = .bestQuality
            s.allowLossyOptimization = false
            s.metadataMode = .removeAll
        case .aiProvenance:
            s.mode = .bestQuality
            s.allowLossyOptimization = false
            s.useAIProvenance = true
        }
        return s
    }
}
