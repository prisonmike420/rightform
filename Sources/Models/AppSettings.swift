import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

// MARK: - Settings

/// What the main window shows: Home (`workspace`), an installed plugin's
/// workspace, or Settings (with About). The plugin store is a sheet.
enum SidebarItem: Hashable {
    case workspace
    case plugin(ExtensionID)
    case settings

    /// Home and each plugin have the panel on the right; Settings doesn't.
    var hasInspector: Bool {
        switch self {
        case .workspace, .plugin: return true
        case .settings: return false
        }
    }
}

enum CompressionMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case recommended
    case smaller
    case bestQuality
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recommended: return "Balanced"
        case .smaller: return "Smaller files"
        case .bestQuality: return "Best quality"
        }
    }
}

enum OutputChoice: String, CaseIterable, Identifiable, Codable, Sendable {
    case keepOriginal
    case jpeg
    case png
    case webp
    case heic
    case avif
    case tiff

    var id: String { rawValue }
    var title: String {
        switch self {
        case .keepOriginal: return "Original"
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .avif: return "AVIF"
        case .tiff: return "TIFF"
        }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// What to do with AI labels found in added files. Asked once, then
/// remembered; it can be changed in AI Provenance’s settings.
enum AILabelPolicy: String, CaseIterable, Identifiable {
    case ask
    case keep
    case remove

    var id: Self { self }

    var title: String {
        switch self {
        case .ask: return "Ask Each Time"
        case .keep: return "Keep"
        case .remove: return "Remove"
        }
    }
}

enum SaveLocation: String, CaseIterable, Identifiable, Codable, Sendable {
    case nextToOriginal
    case folder
    var id: String { rawValue }
}

enum MetadataMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case keep
    case removeAll
    var id: String { rawValue }
    var title: String {
        switch self {
        case .keep: return "Keep"
        case .removeAll: return "Remove"
        }
    }
}

enum PDFCompressionMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case light
    case balanced
    case aggressive
    case maximum

    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Light"
        case .balanced: return "Balanced"
        case .aggressive: return "Small"
        case .maximum: return "Smallest"
        }
    }

}


/// How images are resized. The "Max" modes and the long and short edges
/// only ever make an image smaller; Width and Height set that side exactly,
/// enlarging a smaller image; Percentage scales by up to 100%.
enum ResizeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case fitWithin
    case maxWidth
    case maxHeight
    case maxLongEdge
    case maxShortEdge
    case width
    case height
    case percentage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .fitWithin: return "Fit within"
        case .maxWidth: return "Max width"
        case .maxHeight: return "Max height"
        case .maxLongEdge: return "Max long edge"
        case .maxShortEdge: return "Max short edge"
        case .width: return "Width"
        case .height: return "Height"
        case .percentage: return "Percentage"
        }
    }
}

enum QualityPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case high
    case medium
    case low
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

enum PDFDuplicateMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case exact
    case reviewSimilar
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .exact: return "Exact"
        case .reviewSimilar: return "Review similar"
        }
    }
}

/// Frame rates for animations: Automatic and Original, then the common
/// rates from 4 to 120 fps, NTSC's fractional ones included.
enum AnimationFrameRate: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case original
    case fps4
    case fps5
    case fps8
    case fps10
    case fps12
    case fps15
    case fps20
    case fps23_976
    case fps24
    case fps25
    case fps29_97
    case fps30
    case fps48
    case fps50
    case fps59_94
    case fps60
    case fps72
    case fps75
    case fps90
    case fps100
    case fps120
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .original: return "Original"
        case .fps23_976: return "23.976 fps"
        case .fps29_97: return "29.97 fps"
        case .fps59_94: return "59.94 fps"
        default: return "\(rawValue.dropFirst(3)) fps"
        }
    }
    /// The rate as FFmpeg's `fps` filter takes it; nil keeps the file's own.
    var ffmpegValue: String? {
        switch self {
        case .automatic, .original: return nil
        case .fps23_976: return "24000/1001"
        case .fps29_97: return "30000/1001"
        case .fps59_94: return "60000/1001"
        default: return String(rawValue.dropFirst(3))
        }
    }
}

enum AnimationLoopMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case preserve
    case forever
    case once
    var id: String { rawValue }
    var title: String {
        switch self {
        case .preserve: return "Preserve"
        case .forever: return "Forever"
        case .once: return "Once"
        }
    }
}

enum AnimationResize: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case px1920
    case px1280
    case px720
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .px1920: return "1920 px"
        case .px1280: return "1280 px"
        case .px720: return "720 px"
        }
    }
    var maxEdge: Int? {
        switch self {
        case .original: return nil
        case .px1920: return 1920
        case .px1280: return 1280
        case .px720: return 720
        }
    }
}

enum AnimationCompression: String, CaseIterable, Identifiable, Codable, Sendable {
    case bestQuality
    case balanced
    case smaller
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bestQuality: return "Best quality"
        case .balanced: return "Balanced"
        case .smaller: return "Smaller"
        }
    }
}

/// What animations become: an animated image, or a video without sound.
enum AnimationOutput: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case webp
    case gif
    case apng
    case mp4
    case hevc
    case webm
    case av1
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .webp: return "WebP"
        case .gif: return "GIF"
        case .apng: return "APNG"
        case .mp4: return "MP4 (H.264)"
        case .hevc: return "HEVC (H.265)"
        case .webm: return "WebM (VP9)"
        case .av1: return "AV1"
        }
    }
    /// Videos have no loop setting of their own and, except WebM, no
    /// transparency: it becomes white.
    var isVideo: Bool { [.mp4, .hevc, .webm, .av1].contains(self) }
}

enum PhotographyRAWOutput: String, CaseIterable, Identifiable, Codable, Sendable {
    case jpeg
    case webp
    case avif
    case heic
    case tiff
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

enum LegacyPreferredOutput: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case png
    case jpeg
    case webp
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        }
    }
}

struct SettingsSnapshot: Sendable {
    var mode: CompressionMode
    var output: OutputChoice
    var keepOriginals: Bool
    var saveLocation: SaveLocation
    var outputFolderPath: String?
    var prefix: String
    var suffix: String
    var metadataMode: MetadataMode
    var pdfCompressionMode: PDFCompressionMode
    var pdfDuplicateMode: PDFDuplicateMode
    var removeExactPDFDuplicates: Bool
    var resizeMode: ResizeMode
    var resizeSize: Int
    var resizePercentage: Int
    var allowLossyOptimization: Bool
    var optimizeColorForSharing: Bool
    var preserveColorProfile: Bool
    var preserveModificationDate: Bool
    var jpegQuality: QualityPreset
    var jpegProgressive: Bool
    var webpQuality: QualityPreset
    var webpLossy: Bool
    var pngLossyOptimization: Bool
    var animationFrameRate: AnimationFrameRate
    var animationLoopMode: AnimationLoopMode
    var animationResize: AnimationResize
    var animationCompression: AnimationCompression
    var animationOutput: AnimationOutput
    var photographyRAWOutput: PhotographyRAWOutput
    var photographyPreserve16Bit: Bool
    var legacyPreferredOutput: LegacyPreferredOutput
    var useHighQualityJPEG: Bool
    var useAIProvenance: Bool
}

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults = UserDefaults.standard
    static let minimumResizeSize = 64
    static let maximumResizeSize = 32_768
    static let resizePercentageRange = 1...100

    var compressionMode: CompressionMode { didSet { defaults.set(compressionMode.rawValue, forKey: "compressionMode") } }
    var output: OutputChoice { didSet { defaults.set(output.rawValue, forKey: "output") } }
    var keepOriginals: Bool { didSet { defaults.set(keepOriginals, forKey: "keepOriginals") } }
    var saveLocation: SaveLocation { didSet { defaults.set(saveLocation.rawValue, forKey: "saveLocation") } }
    var outputFolderPath: String? { didSet { defaults.set(outputFolderPath, forKey: "outputFolderPath") } }
    var prefix: String { didSet { defaults.set(prefix, forKey: "prefix") } }
    var suffix: String { didSet { defaults.set(suffix, forKey: "suffix") } }
    var metadataMode: MetadataMode { didSet { defaults.set(metadataMode.rawValue, forKey: "metadataMode") } }
    var pdfCompressionMode: PDFCompressionMode { didSet { defaults.set(pdfCompressionMode.rawValue, forKey: "pdfCompressionMode") } }
    var pdfDuplicateMode: PDFDuplicateMode { didSet { defaults.set(pdfDuplicateMode.rawValue, forKey: "pdfDuplicateMode") } }
    var removeExactPDFDuplicates: Bool { didSet { defaults.set(removeExactPDFDuplicates, forKey: "removeExactPDFDuplicates") } }
    var resizeMode: ResizeMode { didSet { defaults.set(resizeMode.rawValue, forKey: "resizeMode") } }
    var resizeSize: Int {
        didSet {
            let sanitized = min(Self.maximumResizeSize, max(Self.minimumResizeSize, resizeSize))
            if resizeSize != sanitized {
                resizeSize = sanitized
            } else {
                defaults.set(resizeSize, forKey: "resizeSize")
            }
        }
    }
    var resizePercentage: Int {
        didSet {
            let sanitized = Self.resizePercentageRange.clamped(resizePercentage)
            if resizePercentage != sanitized {
                resizePercentage = sanitized
            } else {
                defaults.set(resizePercentage, forKey: "resizePercentage")
            }
        }
    }
    var allowLossyOptimization: Bool { didSet { defaults.set(allowLossyOptimization, forKey: "allowLossyOptimization") } }
    var optimizeColorForSharing: Bool { didSet { defaults.set(optimizeColorForSharing, forKey: "optimizeColorForSharing") } }
    var preserveColorProfile: Bool { didSet { defaults.set(preserveColorProfile, forKey: "preserveColorProfile") } }
    var preserveModificationDate: Bool { didSet { defaults.set(preserveModificationDate, forKey: "preserveModificationDate") } }
    var jpegQuality: QualityPreset { didSet { defaults.set(jpegQuality.rawValue, forKey: "jpegQuality") } }
    var jpegProgressive: Bool { didSet { defaults.set(jpegProgressive, forKey: "jpegProgressive") } }
    var webpQuality: QualityPreset { didSet { defaults.set(webpQuality.rawValue, forKey: "webpQuality") } }
    var webpLossy: Bool { didSet { defaults.set(webpLossy, forKey: "webpLossy") } }
    var pngLossyOptimization: Bool { didSet { defaults.set(pngLossyOptimization, forKey: "pngLossyOptimization") } }
    var animationFrameRate: AnimationFrameRate { didSet { defaults.set(animationFrameRate.rawValue, forKey: "animationFrameRate") } }
    var animationLoopMode: AnimationLoopMode { didSet { defaults.set(animationLoopMode.rawValue, forKey: "animationLoopMode") } }
    var animationResize: AnimationResize { didSet { defaults.set(animationResize.rawValue, forKey: "animationResize") } }
    var animationCompression: AnimationCompression { didSet { defaults.set(animationCompression.rawValue, forKey: "animationCompression") } }
    var animationOutput: AnimationOutput { didSet { defaults.set(animationOutput.rawValue, forKey: "animationOutput") } }
    var photographyRAWOutput: PhotographyRAWOutput { didSet { defaults.set(photographyRAWOutput.rawValue, forKey: "photographyRAWOutput") } }
    var photographyPreserve16Bit: Bool { didSet { defaults.set(photographyPreserve16Bit, forKey: "photographyPreserve16Bit") } }
    var legacyPreferredOutput: LegacyPreferredOutput { didSet { defaults.set(legacyPreferredOutput.rawValue, forKey: "legacyPreferredOutput") } }
    var useHighQualityJPEG: Bool { didSet { defaults.set(useHighQualityJPEG, forKey: "useHighQualityJPEG") } }
    var useAIProvenance: Bool { didSet { defaults.set(useAIProvenance, forKey: "useAIProvenance") } }
    var aiLabelPolicy: AILabelPolicy { didSet { defaults.set(aiLabelPolicy.rawValue, forKey: "aiLabelPolicy") } }
    /// Quit once a batch is saved in full, as a drop on the Dock icon expects.
    var quitWhenDone: Bool { didSet { defaults.set(quitWhenDone, forKey: "quitWhenDone") } }
    /// Folders offered in Where to?, in the order they were added.
    var favoriteFolders: [String] { didSet { defaults.set(favoriteFolders, forKey: "favoriteFolders") } }
    var selection: SidebarItem = .workspace


    /// Plugins kept at the top of the rail, in the order they were pinned.
    var pinnedPlugins: [ExtensionID] {
        didSet { defaults.set(pinnedPlugins.map(\.rawValue), forKey: "pinnedPlugins") }
    }

    func togglePin(_ id: ExtensionID) {
        if let index = pinnedPlugins.firstIndex(of: id) {
            pinnedPlugins.remove(at: index)
        } else {
            pinnedPlugins.append(id)
        }
    }

    /// The panel on the right of Home and each plugin: My Settings, or the
    /// plugin itself and its settings. One choice for every workspace.
    var showsInspector: Bool { didSet { defaults.set(showsInspector, forKey: "showsInspector") } }

    /// The plugin store, a sheet over the window.
    var showsPluginStore = false

    /// A plugin installed from the store, opened once it's ready.
    var pluginToOpen: ExtensionID?

    /// Light, dark or following the system. Applied to the whole app, so
    /// alerts and panels follow it too.
    var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance")
            appearance.apply()
        }
    }

    init() {
        let d = UserDefaults.standard
        appearance = AppAppearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        pinnedPlugins = (d.stringArray(forKey: "pinnedPlugins") ?? []).compactMap(ExtensionID.init(rawValue:))
        compressionMode = CompressionMode(rawValue: d.string(forKey: "compressionMode") ?? "") ?? .recommended
        output = OutputChoice(rawValue: d.string(forKey: "output") ?? "") ?? .keepOriginal
        keepOriginals = d.object(forKey: "keepOriginals") as? Bool ?? true
        saveLocation = SaveLocation(rawValue: d.string(forKey: "saveLocation") ?? "") ?? .nextToOriginal
        outputFolderPath = d.string(forKey: "outputFolderPath")
        prefix = d.string(forKey: "prefix") ?? ""
        // "_compressed" was the old default; only a different, deliberate suffix is kept.
        suffix = d.string(forKey: "suffix").flatMap { $0 == "_compressed" ? nil : $0 } ?? "_prepared"
        if let stored = d.string(forKey: "metadataMode"), let parsed = MetadataMode(rawValue: stored) {
            metadataMode = parsed
        } else {
            metadataMode = (d.object(forKey: "stripMetadata") as? Bool ?? false) ? .removeAll : .keep
        }
        pdfCompressionMode = PDFCompressionMode(rawValue: d.string(forKey: "pdfCompressionMode") ?? "") ?? .balanced
        pdfDuplicateMode = PDFDuplicateMode(rawValue: d.string(forKey: "pdfDuplicateMode") ?? "") ?? .exact
        removeExactPDFDuplicates = d.object(forKey: "removeExactPDFDuplicates") as? Bool ?? true
        resizeMode = ResizeMode(rawValue: d.string(forKey: "resizeMode") ?? "") ?? .original
        resizeSize = min(Self.maximumResizeSize, max(Self.minimumResizeSize, d.integer(forKey: "resizeSize") == 0 ? 2500 : d.integer(forKey: "resizeSize")))
        resizePercentage = Self.resizePercentageRange.clamped(d.object(forKey: "resizePercentage") as? Int ?? 50)
        allowLossyOptimization = d.object(forKey: "allowLossyOptimization") as? Bool ?? true
        optimizeColorForSharing = d.object(forKey: "optimizeColorForSharing") as? Bool ?? false
        preserveColorProfile = d.object(forKey: "preserveColorProfile") as? Bool ?? true
        preserveModificationDate = d.object(forKey: "preserveModificationDate") as? Bool ?? false
        jpegQuality = QualityPreset(rawValue: d.string(forKey: "jpegQuality") ?? "") ?? .automatic
        jpegProgressive = d.object(forKey: "jpegProgressive") as? Bool ?? true
        webpQuality = QualityPreset(rawValue: d.string(forKey: "webpQuality") ?? "") ?? .automatic
        webpLossy = d.object(forKey: "webpLossy") as? Bool ?? true
        pngLossyOptimization = d.object(forKey: "pngLossyOptimization") as? Bool ?? true
        animationFrameRate = AnimationFrameRate(rawValue: d.string(forKey: "animationFrameRate") ?? "") ?? .automatic
        animationLoopMode = AnimationLoopMode(rawValue: d.string(forKey: "animationLoopMode") ?? "") ?? .preserve
        animationResize = AnimationResize(rawValue: d.string(forKey: "animationResize") ?? "") ?? .original
        animationCompression = AnimationCompression(rawValue: d.string(forKey: "animationCompression") ?? "") ?? .balanced
        animationOutput = AnimationOutput(rawValue: d.string(forKey: "animationOutput") ?? "") ?? .original
        photographyRAWOutput = PhotographyRAWOutput(rawValue: d.string(forKey: "photographyRAWOutput") ?? "") ?? .jpeg
        photographyPreserve16Bit = d.object(forKey: "photographyPreserve16Bit") as? Bool ?? true
        legacyPreferredOutput = LegacyPreferredOutput(rawValue: d.string(forKey: "legacyPreferredOutput") ?? "") ?? .png
        useHighQualityJPEG = d.object(forKey: "useHighQualityJPEG") as? Bool ?? true
        useAIProvenance = d.object(forKey: "useAIProvenance") as? Bool ?? true
        aiLabelPolicy = AILabelPolicy(rawValue: d.string(forKey: "aiLabelPolicy") ?? "") ?? .ask
        favoriteFolders = d.stringArray(forKey: "favoriteFolders") ?? []
        quitWhenDone = d.object(forKey: "quitWhenDone") as? Bool ?? false
        showsInspector = d.object(forKey: "showsInspector") as? Bool ?? true
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            mode: compressionMode,
            output: output,
            keepOriginals: keepOriginals,
            saveLocation: saveLocation,
            outputFolderPath: outputFolderPath,
            prefix: prefix,
            suffix: suffix.isEmpty ? "_prepared" : suffix,
            metadataMode: metadataMode,
            pdfCompressionMode: pdfCompressionMode,
            pdfDuplicateMode: pdfDuplicateMode,
            removeExactPDFDuplicates: removeExactPDFDuplicates,
            resizeMode: resizeMode,
            resizeSize: min(Self.maximumResizeSize, max(Self.minimumResizeSize, resizeSize)),
            resizePercentage: Self.resizePercentageRange.clamped(resizePercentage),
            allowLossyOptimization: allowLossyOptimization,
            optimizeColorForSharing: optimizeColorForSharing,
            preserveColorProfile: preserveColorProfile,
            preserveModificationDate: preserveModificationDate,
            jpegQuality: jpegQuality,
            jpegProgressive: jpegProgressive,
            webpQuality: webpQuality,
            webpLossy: webpLossy,
            pngLossyOptimization: pngLossyOptimization,
            animationFrameRate: animationFrameRate,
            animationLoopMode: animationLoopMode,
            animationResize: animationResize,
            animationCompression: animationCompression,
            animationOutput: animationOutput,
            photographyRAWOutput: photographyRAWOutput,
            photographyPreserve16Bit: photographyPreserve16Bit,
            legacyPreferredOutput: legacyPreferredOutput,
            useHighQualityJPEG: useHighQualityJPEG,
            useAIProvenance: useAIProvenance
        )
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.message = "Choose where Stou saves prepared files."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            outputFolderPath = panel.url?.path
            saveLocation = .folder
        }
    }
}

private extension ClosedRange where Bound == Int {
    func clamped(_ value: Int) -> Int { Swift.min(upperBound, Swift.max(lowerBound, value)) }
}
