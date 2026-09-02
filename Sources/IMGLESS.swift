import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

@main
struct IMGLESSApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var stats: StatisticsStore
    @StateObject private var extensions: ExtensionManager
    @StateObject private var model: CompressionModel

    init() {
        let settings = AppSettings()
        let stats = StatisticsStore()
        let extensions = ExtensionManager()
        _settings = StateObject(wrappedValue: settings)
        _stats = StateObject(wrappedValue: stats)
        _extensions = StateObject(wrappedValue: extensions)
        _model = StateObject(wrappedValue: CompressionModel(settings: settings, stats: stats))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, extensionManager: extensions, stats: stats)
                .frame(minWidth: 560, minHeight: 560)
                .background(WindowConfigurator())
                .onOpenURL { url in model.add(urls: [url]) }
        }
        .defaultSize(width: 620, height: 620)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Images…") { model.pickFiles() }
                    .keyboardShortcut("o")
                    .disabled(model.isProcessing || model.screen != .main)
                Button("Settings…") {
                    model.screen = model.screen == .settings ? .main : .settings
                }
                    .keyboardShortcut(",")
                    .disabled(model.isProcessing || model.isPreflightingPDF)
                Button("Clear") { model.clearAll() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                    .disabled(model.isProcessing || model.items.isEmpty)
            }
        }
    }
}

// Standard system controls intentionally keep the user's macOS accent color.
// On macOS 26 they automatically adopt the current Liquid Glass appearance.
// MARK: - Settings

enum AppScreen: Equatable {
    case main
    case settings
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
        case .aggressive: return "Aggressive"
        case .maximum: return "Maximum"
        }
    }

    var detail: String {
        switch self {
        case .light:
            return "Structural optimization only. Keeps text and vectors intact."
        case .balanced:
            return "Optimizes structure and large eligible images. Keeps text and vectors."
        case .aggressive:
            return "Optimizes every eligible image while preserving the PDF structure."
        case .maximum:
            return "Smallest files. Pages are rasterized and selectable text is not preserved."
        }
    }
}


enum ResizeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case maxLongEdge
    case maxWidth
    case maxHeight
    case fitWithin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .maxLongEdge: return "Max long edge"
        case .maxWidth: return "Max width"
        case .maxHeight: return "Max height"
        case .fitWithin: return "Fit within"
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

enum AnimationFrameRate: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case original
    case fps30
    case fps24
    case fps15
    case fps10
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .original: return "Original"
        case .fps30: return "30 fps"
        case .fps24: return "24 fps"
        case .fps15: return "15 fps"
        case .fps10: return "10 fps"
        }
    }
    var numericValue: Int? {
        switch self {
        case .fps30: return 30
        case .fps24: return 24
        case .fps15: return 15
        case .fps10: return 10
        default: return nil
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

enum AnimationOutput: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case webp
    case gif
    case apng
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .webp: return "WebP"
        case .gif: return "GIF"
        case .apng: return "APNG"
        }
    }
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
    let mode: CompressionMode
    let output: OutputChoice
    let keepOriginals: Bool
    let saveLocation: SaveLocation
    let outputFolderPath: String?
    let prefix: String
    let suffix: String
    let metadataMode: MetadataMode
    let pdfCompressionMode: PDFCompressionMode
    let pdfDuplicateMode: PDFDuplicateMode
    let removeExactPDFDuplicates: Bool
    let resizeMode: ResizeMode
    let resizeSize: Int
    let allowLossyOptimization: Bool
    let optimizeColorForSharing: Bool
    let preserveColorProfile: Bool
    let preserveModificationDate: Bool
    let jpegQuality: QualityPreset
    let jpegProgressive: Bool
    let webpQuality: QualityPreset
    let webpLossy: Bool
    let pngLossyOptimization: Bool
    let animationFrameRate: AnimationFrameRate
    let animationLoopMode: AnimationLoopMode
    let animationResize: AnimationResize
    let animationCompression: AnimationCompression
    let animationOutput: AnimationOutput
    let photographyRAWOutput: PhotographyRAWOutput
    let photographyPreserve16Bit: Bool
    let legacyPreferredOutput: LegacyPreferredOutput
    let useHighQualityJPEG: Bool
    let useAIProvenance: Bool
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var compressionMode: CompressionMode { didSet { defaults.set(compressionMode.rawValue, forKey: "compressionMode") } }
    @Published var output: OutputChoice { didSet { defaults.set(output.rawValue, forKey: "output") } }
    @Published var keepOriginals: Bool { didSet { defaults.set(keepOriginals, forKey: "keepOriginals") } }
    @Published var saveLocation: SaveLocation { didSet { defaults.set(saveLocation.rawValue, forKey: "saveLocation") } }
    @Published var outputFolderPath: String? { didSet { defaults.set(outputFolderPath, forKey: "outputFolderPath") } }
    @Published var prefix: String { didSet { defaults.set(prefix, forKey: "prefix") } }
    @Published var suffix: String { didSet { defaults.set(suffix, forKey: "suffix") } }
    @Published var metadataMode: MetadataMode { didSet { defaults.set(metadataMode.rawValue, forKey: "metadataMode") } }
    @Published var pdfCompressionMode: PDFCompressionMode { didSet { defaults.set(pdfCompressionMode.rawValue, forKey: "pdfCompressionMode") } }
    @Published var pdfDuplicateMode: PDFDuplicateMode { didSet { defaults.set(pdfDuplicateMode.rawValue, forKey: "pdfDuplicateMode") } }
    @Published var removeExactPDFDuplicates: Bool { didSet { defaults.set(removeExactPDFDuplicates, forKey: "removeExactPDFDuplicates") } }
    @Published var resizeMode: ResizeMode { didSet { defaults.set(resizeMode.rawValue, forKey: "resizeMode") } }
    @Published var resizeSize: Int { didSet { defaults.set(resizeSize, forKey: "resizeSize") } }
    @Published var allowLossyOptimization: Bool { didSet { defaults.set(allowLossyOptimization, forKey: "allowLossyOptimization") } }
    @Published var optimizeColorForSharing: Bool { didSet { defaults.set(optimizeColorForSharing, forKey: "optimizeColorForSharing") } }
    @Published var preserveColorProfile: Bool { didSet { defaults.set(preserveColorProfile, forKey: "preserveColorProfile") } }
    @Published var preserveModificationDate: Bool { didSet { defaults.set(preserveModificationDate, forKey: "preserveModificationDate") } }
    @Published var jpegQuality: QualityPreset { didSet { defaults.set(jpegQuality.rawValue, forKey: "jpegQuality") } }
    @Published var jpegProgressive: Bool { didSet { defaults.set(jpegProgressive, forKey: "jpegProgressive") } }
    @Published var webpQuality: QualityPreset { didSet { defaults.set(webpQuality.rawValue, forKey: "webpQuality") } }
    @Published var webpLossy: Bool { didSet { defaults.set(webpLossy, forKey: "webpLossy") } }
    @Published var pngLossyOptimization: Bool { didSet { defaults.set(pngLossyOptimization, forKey: "pngLossyOptimization") } }
    @Published var animationFrameRate: AnimationFrameRate { didSet { defaults.set(animationFrameRate.rawValue, forKey: "animationFrameRate") } }
    @Published var animationLoopMode: AnimationLoopMode { didSet { defaults.set(animationLoopMode.rawValue, forKey: "animationLoopMode") } }
    @Published var animationResize: AnimationResize { didSet { defaults.set(animationResize.rawValue, forKey: "animationResize") } }
    @Published var animationCompression: AnimationCompression { didSet { defaults.set(animationCompression.rawValue, forKey: "animationCompression") } }
    @Published var animationOutput: AnimationOutput { didSet { defaults.set(animationOutput.rawValue, forKey: "animationOutput") } }
    @Published var photographyRAWOutput: PhotographyRAWOutput { didSet { defaults.set(photographyRAWOutput.rawValue, forKey: "photographyRAWOutput") } }
    @Published var photographyPreserve16Bit: Bool { didSet { defaults.set(photographyPreserve16Bit, forKey: "photographyPreserve16Bit") } }
    @Published var legacyPreferredOutput: LegacyPreferredOutput { didSet { defaults.set(legacyPreferredOutput.rawValue, forKey: "legacyPreferredOutput") } }
    @Published var useHighQualityJPEG: Bool { didSet { defaults.set(useHighQualityJPEG, forKey: "useHighQualityJPEG") } }
    @Published var useAIProvenance: Bool { didSet { defaults.set(useAIProvenance, forKey: "useAIProvenance") } }

    init() {
        let d = UserDefaults.standard
        compressionMode = CompressionMode(rawValue: d.string(forKey: "compressionMode") ?? "") ?? .recommended
        output = OutputChoice(rawValue: d.string(forKey: "output") ?? "") ?? .keepOriginal
        keepOriginals = d.object(forKey: "keepOriginals") as? Bool ?? true
        saveLocation = SaveLocation(rawValue: d.string(forKey: "saveLocation") ?? "") ?? .nextToOriginal
        outputFolderPath = d.string(forKey: "outputFolderPath")
        prefix = d.string(forKey: "prefix") ?? ""
        suffix = d.string(forKey: "suffix") ?? "_compressed"
        if let stored = d.string(forKey: "metadataMode"), let parsed = MetadataMode(rawValue: stored) {
            metadataMode = parsed
        } else {
            metadataMode = (d.object(forKey: "stripMetadata") as? Bool ?? false) ? .removeAll : .keep
        }
        pdfCompressionMode = PDFCompressionMode(rawValue: d.string(forKey: "pdfCompressionMode") ?? "") ?? .balanced
        pdfDuplicateMode = PDFDuplicateMode(rawValue: d.string(forKey: "pdfDuplicateMode") ?? "") ?? .exact
        removeExactPDFDuplicates = d.object(forKey: "removeExactPDFDuplicates") as? Bool ?? true
        resizeMode = ResizeMode(rawValue: d.string(forKey: "resizeMode") ?? "") ?? .original
        resizeSize = max(64, d.integer(forKey: "resizeSize") == 0 ? 2500 : d.integer(forKey: "resizeSize"))
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
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            mode: compressionMode,
            output: output,
            keepOriginals: keepOriginals,
            saveLocation: saveLocation,
            outputFolderPath: outputFolderPath,
            prefix: prefix,
            suffix: suffix.isEmpty ? "_compressed" : suffix,
            metadataMode: metadataMode,
            pdfCompressionMode: pdfCompressionMode,
            pdfDuplicateMode: pdfDuplicateMode,
            removeExactPDFDuplicates: removeExactPDFDuplicates,
            resizeMode: resizeMode,
            resizeSize: max(64, resizeSize),
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
        panel.title = "Choose output folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            outputFolderPath = panel.url?.path
            saveLocation = .folder
        }
    }
}


// MARK: - Statistics

@MainActor
final class StatisticsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published private(set) var totalBytesSaved: Int64
    @Published private(set) var totalFilesOptimized: Int
    @Published private(set) var installedAt: Date

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "statisticsInstalledAt") == nil {
            d.set(Date(), forKey: "statisticsInstalledAt")
        }
        installedAt = d.object(forKey: "statisticsInstalledAt") as? Date ?? Date()
        totalBytesSaved = (d.object(forKey: "statisticsBytesSaved") as? NSNumber)?.int64Value ?? 0
        totalFilesOptimized = d.integer(forKey: "statisticsFilesOptimized")
    }

    func record(originalBytes: Int64, outputBytes: Int64) {
        let saved = max(0, originalBytes - outputBytes)
        guard saved > 0 else { return }
        totalBytesSaved += saved
        totalFilesOptimized += 1
        persist()
    }

    func reset() {
        totalBytesSaved = 0
        totalFilesOptimized = 0
        installedAt = Date()
        defaults.set(installedAt, forKey: "statisticsInstalledAt")
        persist()
    }

    private func persist() {
        defaults.set(NSNumber(value: totalBytesSaved), forKey: "statisticsBytesSaved")
        defaults.set(totalFilesOptimized, forKey: "statisticsFilesOptimized")
    }
}

// MARK: - Extensions / capabilities

enum ExtensionID: String, CaseIterable, Identifiable, Sendable {
    case highQualityJPEG = "high-quality-jpeg"
    case applePhotos = "apple-photos"
    case photography = "photography"
    case animation = "animation"
    case legacyFormats = "legacy-formats"
    case metadataCleaner = "metadata-cleaner"
    case aiProvenance = "ai-provenance"
    case pdfTools = "pdf-tools"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highQualityJPEG: return "High Quality JPEG"
        case .applePhotos: return "Apple Photos"
        case .photography: return "Photography"
        case .animation: return "Animation"
        case .legacyFormats: return "Legacy Formats"
        case .metadataCleaner: return "Metadata Cleaner"
        case .aiProvenance: return "AI Provenance"
        case .pdfTools: return "PDF Tools"
        }
    }

    var detail: String {
        switch self {
        case .highQualityJPEG: return "Google jpegli"
        case .applePhotos: return "HEIC, HEIF and AVIF"
        case .photography: return "TIFF, DNG and camera RAW"
        case .animation: return "GIF, Animated WebP and APNG"
        case .legacyFormats: return "BMP, TGA, PCX, PICT and classic raster formats"
        case .metadataCleaner: return "Remove all removable metadata"
        case .aiProvenance: return "Experimental · AI provenance cleanup"
        case .pdfTools: return "Compress PDFs and remove duplicate pages"
        }
    }

    var installable: Bool { true }
}

enum ExtensionInstallState: Equatable {
    case notInstalled
    case installing
    case installed(String)
    case removing
    case failed(String)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .installing, .removing: return true
        default: return false
        }
    }
}

enum ExtensionRegistry {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/IMGLESS/Extensions", isDirectory: true)

    static func root(for id: ExtensionID) -> URL {
        root.appendingPathComponent(id.rawValue, isDirectory: true)
    }

    static func manifest(for id: ExtensionID) -> URL {
        root(for: id).appendingPathComponent("manifest.json")
    }

    static func isInstalled(_ id: ExtensionID) -> Bool {
        if id == .highQualityJPEG {
            return FileManager.default.fileExists(atPath: cjpegli.path)
        }
        if id == .aiProvenance {
            return FileManager.default.fileExists(atPath: watermarksCleanScript.path) &&
                   FileManager.default.fileExists(atPath: watermarksInspectScript.path)
        }
        if id == .pdfTools {
            return FileManager.default.fileExists(atPath: manifest(for: id).path) &&
                   Toolchain.locate("qpdf") != nil && Toolchain.locate("pdfcpu") != nil
        }
        if id == .animation {
            return FileManager.default.fileExists(atPath: manifest(for: id).path) &&
                   Toolchain.locate("ffmpeg") != nil && Toolchain.locate("ffprobe") != nil
        }
        if id == .photography || id == .legacyFormats {
            return FileManager.default.fileExists(atPath: manifest(for: id).path) && Toolchain.locate("magick") != nil
        }
        return FileManager.default.fileExists(atPath: manifest(for: id).path)
    }

    static var cjpegli: URL {
        root(for: .highQualityJPEG).appendingPathComponent("build/tools/cjpegli")
    }

    static var watermarksCleanScript: URL {
        root(for: .aiProvenance).appendingPathComponent("service/scripts/clean_image.py")
    }

    static var watermarksInspectScript: URL {
        root(for: .aiProvenance).appendingPathComponent("service/scripts/inspect_image.py")
    }

    static func requiredExtension(for format: ImageFormat) -> ExtensionID? {
        switch format {
        case .jpeg, .png, .webp: return nil
        case .heic, .avif: return .applePhotos
        case .tiff, .raw: return .photography
        case .gif, .apng, .animatedWebP: return .animation
        case .bmp, .tga, .pcx, .pict, .ppm, .pgm, .pbm, .xbm, .xpm, .sgi, .sun: return .legacyFormats
        case .pdf: return .pdfTools
        case .unknown: return nil
        }
    }

    static func supports(_ format: ImageFormat) -> Bool {
        guard let required = requiredExtension(for: format) else {
            return format != .unknown
        }
        return isInstalled(required)
    }

    static func writeManifest(id: ExtensionID, version: String, capabilities: [String]) throws {
        let fm = FileManager.default
        let dir = root(for: id)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let json: [String: Any] = [
            "id": "com.imgless.\(id.rawValue)",
            "name": id.title,
            "version": version,
            "capabilities": capabilities
        ]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: manifest(for: id), options: .atomic)
    }
}

struct CapabilityResolver {
    static func canProcess(_ format: ImageFormat) -> Bool {
        ExtensionRegistry.supports(format)
    }

    static func missingExtension(for format: ImageFormat) -> ExtensionID? {
        guard let required = ExtensionRegistry.requiredExtension(for: format),
              !ExtensionRegistry.isInstalled(required) else { return nil }
        return required
    }

    static var highQualityJPEGAvailable: Bool {
        ExtensionRegistry.isInstalled(.highQualityJPEG)
    }

    static var metadataCleanerAvailable: Bool {
        ExtensionRegistry.isInstalled(.metadataCleaner) && Toolchain.locate("exiftool") != nil
    }

    static var aiProvenanceAvailable: Bool {
        ExtensionRegistry.isInstalled(.aiProvenance)
    }
}

@MainActor
final class ExtensionManager: ObservableObject {
    nonisolated static let watermarksRepositoryURL = "https://github.com/guillaumemeyer/watermarks-remover.git"
    nonisolated static let watermarksTag = "v0.5.0"
    nonisolated static let watermarksCommit = "dc0ff78f39bedfe0a1986eef54efb297645372ba"
    nonisolated static let jpegliRepositoryURL = "https://github.com/google/jpegli.git"
    nonisolated static let jpegliCommit = "031a0077f5799a6041004267fc12b956c1f52a20"

    @Published private(set) var states: [ExtensionID: ExtensionInstallState] = [:]

    init() { refreshAll() }

    func state(for id: ExtensionID) -> ExtensionInstallState {
        states[id] ?? (ExtensionRegistry.isInstalled(id) ? .installed(installedVersion(for: id)) : .notInstalled)
    }

    func refreshAll() {
        for id in ExtensionID.allCases {
            if ExtensionRegistry.isInstalled(id) {
                states[id] = .installed(installedVersion(for: id))
            } else {
                states[id] = .notInstalled
            }
        }
    }

    func install(_ id: ExtensionID) {
        guard id.installable, !state(for: id).isBusy else { return }
        states[id] = .installing
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.installSynchronously(id)
            }.value
            if result.0 {
                self.states[id] = .installed(self.installedVersion(for: id))
            } else {
                self.states[id] = .failed(result.1 ?? "Installation failed.")
            }
        }
    }

    func remove(_ id: ExtensionID) {
        guard id.installable, !state(for: id).isBusy else { return }
        states[id] = .removing
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    let root = ExtensionRegistry.root(for: id)
                    if FileManager.default.fileExists(atPath: root.path) {
                        try FileManager.default.removeItem(at: root)
                    }
                    return (true, nil as String?)
                } catch {
                    return (false, error.localizedDescription)
                }
            }.value
            self.states[id] = result.0 ? .notInstalled : .failed(result.1 ?? "Could not remove extension.")
        }
    }

    func action(_ id: ExtensionID) {
        if state(for: id).isInstalled { remove(id) } else { install(id) }
    }

    nonisolated static func supportedPython() -> URL? {
        for name in ["python3.14", "python3.13", "python3.12", "python3.11", "python3.10", "python3"] {
            guard let python = Toolchain.locate(name) else { continue }
            if let version = try? ProcessRunner.run(python, ["-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"]),
               let pair = parseVersion(version), pair.0 > 3 || (pair.0 == 3 && pair.1 >= 10) {
                return python
            }
        }
        return nil
    }

    nonisolated private static func parseVersion(_ raw: String) -> (Int, Int)? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard parts.count >= 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }
        return (major, minor)
    }

    private func installedVersion(for id: ExtensionID) -> String {
        if let data = try? Data(contentsOf: ExtensionRegistry.manifest(for: id)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return version
        }
        switch id {
        case .aiProvenance: return Self.watermarksTag
        case .highQualityJPEG: return "jpegli"
        default: return "Installed"
        }
    }

    nonisolated private static func brewInstall(_ packages: [String]) throws {
        guard let brew = Toolchain.locate("brew") else {
            throw CompressionError.message("Homebrew is required to install this extension.")
        }
        for package in packages {
            _ = try ProcessRunner.run(brew, ["install", package])
        }
    }

    nonisolated private static func installSynchronously(_ id: ExtensionID) -> (Bool, String?) {
        do {
            try FileManager.default.createDirectory(at: ExtensionRegistry.root, withIntermediateDirectories: true)

            switch id {
            case .highQualityJPEG:
                try installJpegli()
            case .applePhotos:
                try brewInstall(["imagemagick", "libheif"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: ["decode.heic", "decode.heif", "decode.avif", "encode.heic", "encode.avif"]
                )
            case .photography:
                try brewInstall(["imagemagick", "libraw", "libtiff", "libheif"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: [
                        "decode.tiff", "encode.tiff", "decode.dng", "decode.camera-raw",
                        "export.raw.jpeg", "export.raw.webp", "export.raw.avif", "export.raw.heic"
                    ]
                )
            case .animation:
                try brewInstall(["ffmpeg", "imagemagick"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: [
                        "decode.gif", "decode.apng", "decode.webp.animation",
                        "encode.gif", "encode.apng", "encode.webp.animation"
                    ]
                )
            case .legacyFormats:
                try brewInstall(["imagemagick"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: [
                        "decode.bmp", "decode.tga", "decode.pcx", "decode.pict",
                        "decode.pnm", "decode.xbm", "decode.xpm", "decode.sgi", "decode.sun"
                    ]
                )
            case .metadataCleaner:
                // ImageMagick is included to bake EXIF orientation into pixels before stripping tags.
                try brewInstall(["exiftool", "imagemagick"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: ["inspect.metadata", "clean.metadata", "verify.metadata"]
                )
            case .aiProvenance:
                try installWatermarks()
            case .pdfTools:
                try brewInstall(["qpdf", "pdfcpu"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "2.1",
                    capabilities: [
                        "inspect.pdf",
                        "detect.pdf.duplicates.exact",
                        "detect.pdf.duplicates.similar",
                        "remove.pdf.duplicates",
                        "compress.pdf.structure",
                        "compress.pdf.maximum",
                        "verify.pdf"
                    ]
                )
            }
            return (true, nil)
        } catch let error as CompressionError {
            return (false, error.description)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    nonisolated private static func installJpegli() throws {
        let fm = FileManager.default
        let root = ExtensionRegistry.root(for: .highQualityJPEG)
        let stage = ExtensionRegistry.root.appendingPathComponent(".jpegli-stage-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: stage) }

        try brewInstall(["cmake", "ninja", "pkgconf", "giflib", "jpeg-turbo", "libpng", "zlib"])
        guard let git = Toolchain.locate("git") else {
            throw CompressionError.message("Git is required to install High Quality JPEG.")
        }

        _ = try ProcessRunner.run(git, ["clone", "--recursive", jpegliRepositoryURL, stage.path])
        _ = try ProcessRunner.run(git, ["-C", stage.path, "checkout", "--detach", jpegliCommit])
        _ = try ProcessRunner.run(git, ["-C", stage.path, "submodule", "update", "--init", "--recursive"])

        let env = Toolchain.locate("env") ?? URL(fileURLWithPath: "/usr/bin/env")
        let result = try ProcessRunner.runWithStatus(env, [
            "SKIP_TEST=1",
            "/bin/bash", "-lc",
            "cd \(shellQuote(stage.path)) && ./ci.sh release -DBUILD_TESTING=OFF -DJPEGLI_ENABLE_JPEGLI_LIBJPEG=OFF -DJPEGLI_ENABLE_OPENEXR=OFF -DJPEGLI_ENABLE_DEVTOOLS=OFF"
        ])
        guard result.status == 0,
              fm.fileExists(atPath: stage.appendingPathComponent("build/tools/cjpegli").path) else {
            throw CompressionError.message("Google jpegli could not be built on this Mac.")
        }

        if fm.fileExists(atPath: root.path) { try fm.removeItem(at: root) }
        try fm.moveItem(at: stage, to: root)
        try ExtensionRegistry.writeManifest(
            id: .highQualityJPEG, version: String(jpegliCommit.prefix(8)),
            capabilities: ["encode.jpeg.high-quality"]
        )
    }

    nonisolated private static func installWatermarks() throws {
        let fm = FileManager.default
        let root = ExtensionRegistry.root(for: .aiProvenance)
        let stage = ExtensionRegistry.root.appendingPathComponent(".watermarks-stage-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: stage) }

        guard let git = Toolchain.locate("git") else {
            throw CompressionError.message("Git is required to install AI Provenance.")
        }

        var python = supportedPython()
        if python == nil {
            try brewInstall(["python"])
            python = supportedPython()
        }
        guard let python else {
            throw CompressionError.message("Python 3.10 or newer is required for AI Provenance.")
        }

        _ = try ProcessRunner.run(git, [
            "clone", "--depth", "1", "--branch", watermarksTag, "--single-branch",
            watermarksRepositoryURL, stage.path
        ])
        let sha = try ProcessRunner.run(git, ["-C", stage.path, "rev-parse", "HEAD"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard sha == watermarksCommit else {
            throw CompressionError.message("AI Provenance verification failed: unexpected Git revision.")
        }
        let probe = stage.appendingPathComponent("service/scripts/clean_image.py")
        guard fm.fileExists(atPath: probe.path) else {
            throw CompressionError.message("AI Provenance verification failed.")
        }
        _ = try ProcessRunner.run(python, [probe.path, "--help"])

        if fm.fileExists(atPath: root.path) { try fm.removeItem(at: root) }
        try fm.moveItem(at: stage, to: root)
        try ExtensionRegistry.writeManifest(
            id: .aiProvenance, version: watermarksTag,
            capabilities: ["inspect.ai-provenance", "clean.ai-provenance", "verify.ai-provenance"]
        )
    }

    nonisolated private static func shellQuote(_ raw: String) -> String {
        "'" + raw.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum WatermarksExtensionRunner {
    static var isInstalled: Bool { CapabilityResolver.aiProvenanceAvailable }

    static func clean(url: URL) throws {
        guard isInstalled else { return }
        guard let python = ExtensionManager.supportedPython() else {
            throw CompressionError.message("AI Provenance needs Python 3.10 or newer.")
        }

        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        let cleaned = url.deletingLastPathComponent()
            .appendingPathComponent(".imgless-provenance-\(UUID().uuidString).\(ext)")
        defer { try? FileManager.default.removeItem(at: cleaned) }

        let result = try ProcessRunner.runWithStatus(python, [
            ExtensionRegistry.watermarksCleanScript.path,
            url.path,
            "-o", cleaned.path,
            "--keep-non-ai-metadata",
            "--json"
        ])
        guard result.status == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CompressionError.message(message.isEmpty ? "AI Provenance cleaning did not verify successfully." : message)
        }
        guard FileManager.default.fileExists(atPath: cleaned.path) else {
            throw CompressionError.message("AI Provenance did not produce an output file.")
        }

        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: cleaned, to: url)
    }

    static func verify(url: URL) throws {
        guard isInstalled else { return }
        guard let python = ExtensionManager.supportedPython() else {
            throw CompressionError.message("AI Provenance needs Python 3.10 or newer.")
        }
        let result = try ProcessRunner.runWithStatus(python, [
            ExtensionRegistry.watermarksInspectScript.path,
            url.path,
            "--json"
        ])
        guard let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CompressionError.message("AI Provenance verification returned an unreadable report.")
        }
        let hasC2PA = json["has_c2pa"] as? Bool ?? false
        let hasAI = json["has_ai_metadata"] as? Bool ?? false
        guard !hasC2PA && !hasAI && result.status == 0 else {
            throw CompressionError.message("AI Provenance verification found residual provenance metadata.")
        }
    }
}

// MARK: - Domain

enum ImageFormat: String, Sendable {
    case jpeg = "JPEG"
    case png = "PNG"
    case webp = "WebP"
    case heic = "HEIC"
    case avif = "AVIF"
    case tiff = "TIFF"
    case raw = "RAW"
    case bmp = "BMP"
    case tga = "TGA"
    case pcx = "PCX"
    case pict = "PICT"
    case ppm = "PPM"
    case pgm = "PGM"
    case pbm = "PBM"
    case xbm = "XBM"
    case xpm = "XPM"
    case sgi = "SGI"
    case sun = "SUN"
    case gif = "GIF"
    case apng = "APNG"
    case animatedWebP = "Animated WebP"
    case pdf = "PDF"
    case unknown = "Unknown"

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .webp, .animatedWebP: return "webp"
        case .heic: return "heic"
        case .avif: return "avif"
        case .tiff: return "tiff"
        case .raw: return "dng"
        case .bmp: return "bmp"
        case .tga: return "tga"
        case .pcx: return "pcx"
        case .pict: return "pict"
        case .ppm: return "ppm"
        case .pgm: return "pgm"
        case .pbm: return "pbm"
        case .xbm: return "xbm"
        case .xpm: return "xpm"
        case .sgi: return "sgi"
        case .sun: return "ras"
        case .gif: return "gif"
        case .apng: return "apng"
        case .pdf: return "pdf"
        case .unknown: return "dat"
        }
    }

    var isAnimation: Bool {
        switch self {
        case .gif, .apng, .animatedWebP: return true
        default: return false
        }
    }

    var isLegacy: Bool {
        switch self {
        case .bmp, .tga, .pcx, .pict, .ppm, .pgm, .pbm, .xbm, .xpm, .sgi, .sun: return true
        default: return false
        }
    }

    static func fromExtension(_ ext: String) -> ImageFormat {
        switch ext.lowercased() {
        case "jpg", "jpeg", "jpe", "jfif": return .jpeg
        case "png": return .png
        case "apng": return .apng
        case "webp": return .webp
        case "heic", "heif": return .heic
        case "avif": return .avif
        case "tif", "tiff", "btf", "bigtiff": return .tiff
        case "dng", "cr2", "cr3", "crw", "nef", "nrw", "arw", "srf", "sr2", "raf", "orf", "rw2", "pef", "3fr", "fff", "iiq", "mos", "mrw", "x3f", "rwl": return .raw
        case "bmp", "dib": return .bmp
        case "tga", "icb", "vda", "vst": return .tga
        case "pcx": return .pcx
        case "pict", "pct", "pic": return .pict
        case "ppm", "pnm": return .ppm
        case "pgm": return .pgm
        case "pbm": return .pbm
        case "xbm": return .xbm
        case "xpm": return .xpm
        case "sgi", "rgb", "rgba", "bw": return .sgi
        case "ras", "sun": return .sun
        case "gif": return .gif
        case "pdf": return .pdf
        default: return .unknown
        }
    }
}
enum CompressionState: Equatable {
    case queued
    case analyzing
    case squeezing
    case done
    case dry
    case failed(String)
    case cancelled
}

struct CompressionItem: Identifiable {
    let id = UUID()
    let url: URL
    let format: ImageFormat
    let originalBytes: Int64
    var outputURL: URL?
    var outputBytes: Int64?
    var outputFormat: ImageFormat?
    var estimatedBytes: Int64?
    var pdfExactDuplicatePages: [Int] = []
    var pdfSimilarPairs: [PDFSimilarPair] = []
    var pdfSelectedSimilarDuplicates: Set<Int> = []
    var state: CompressionState = .queued

    var differencePercent: Int {
        guard originalBytes > 0, let outputBytes else { return 0 }
        return Int(((Double(originalBytes - outputBytes) / Double(originalBytes)) * 100).rounded())
    }
}

struct InspectionReport: Sendable {
    let format: ImageFormat
    let width: Int
    let height: Int
    let frameCount: Int
    let orientation: Int?
    let removableMetadataCount: Int
    let hasProvenanceMarkers: Bool
}

struct PDFSimilarPair: Hashable, Sendable, Identifiable {
    let firstPage: Int
    let secondPage: Int
    let similarity: Double
    var id: String { "\(firstPage)-\(secondPage)" }
}

struct PDFPreflightReport: Sendable {
    let pageCount: Int
    let estimatedBytes: Int64
    let encrypted: Bool
    let signed: Bool
    let alreadyOptimal: Bool
    let exactDuplicatePages: [Int]
    let similarPairs: [PDFSimilarPair]
}

struct CompressionResult: Sendable {
    enum Outcome: Sendable {
        case done(output: URL, bytes: Int64, format: ImageFormat)
        case dry
        case failed(String)
        case cancelled
    }
    let outcome: Outcome
}

// MARK: - Adaptive scheduler

struct ProcessingJob: Sendable {
    let id: UUID
    let url: URL
    let format: ImageFormat
    let originalBytes: Int64
    let pdfPagesToRemove: [Int]
}

struct ScheduledCompressionResult: Sendable {
    let job: ProcessingJob
    let result: CompressionResult
}

struct PDFPreflightWorkItem: Sendable {
    let id: UUID
    let url: URL
    let originalBytes: Int64
}

struct BatchProgress: Equatable, Sendable {
    var total: Int = 0
    var waiting: Int = 0
    var active: Int = 0
    var optimized: Int = 0
    var unchanged: Int = 0
    var failed: Int = 0
    var cancelled: Int = 0
    var completed: Int = 0
    var bytesIn: Int64 = 0
    var bytesOut: Int64 = 0
    var bytesSaved: Int64 = 0

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    var percent: Int { Int((fraction * 100).rounded()) }
}

final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock(); value = true; lock.unlock()
    }

    func check() throws {
        if isCancelled { throw CompressionError.message("Cancelled") }
    }
}

enum AdaptiveScheduler {
    static var activeCores: Int {
        max(1, ProcessInfo.processInfo.activeProcessorCount)
    }

    static var physicalMemory: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    static func maxConcurrentJobs(for jobs: [ProcessingJob], settings: SettingsSnapshot) -> Int {
        guard !jobs.isEmpty else { return 1 }

        let cores = activeCores
        let memoryGB = max(1.0, Double(physicalMemory) / 1_073_741_824.0)

        // Pixel-domain / provenance extensions may invoke heavyweight helpers.
        // Keep them serialized so the system remains responsive and memory pressure stays low.
        if settings.useAIProvenance && CapabilityResolver.aiProvenanceAvailable {
            return 1
        }

        let hasHeavyFormats = jobs.contains { [.heic, .avif, .tiff, .raw, .gif, .apng, .animatedWebP, .pdf].contains($0.format) }
        if hasHeavyFormats {
            let cpuCap = max(1, cores / 4)
            let memoryCap = max(1, Int(memoryGB / 3.0))
            return min(jobs.count, min(3, min(cpuCap, memoryCap)))
        }

        // Core codecs can run several files in parallel. Some encoders also use
        // internal threads, so half the logical cores avoids oversubscription while
        // still scaling strongly on Max/Ultra-class chips.
        let cpuCap = max(1, cores / 2)
        let memoryCap = max(1, Int(memoryGB / 0.75))
        return min(jobs.count, min(12, min(cpuCap, memoryCap)))
    }
}

// MARK: - Model

@MainActor
final class CompressionModel: ObservableObject {
    @Published var items: [CompressionItem] = []
    @Published var isDropTargeted = false
    @Published var isProcessing = false
    @Published var isCancelling = false
    @Published var alertMessage: String?
    @Published var showReplaceConfirmation = false
    @Published var screen: AppScreen = .main
    @Published var resultDrawerVisible = false
    @Published var isPreflightingPDF = false
    @Published var pdfEstimateVisible = false
    @Published var pdfReviewItemID: UUID?
    @Published private(set) var batchProgress = BatchProgress()

    let settings: AppSettings
    let stats: StatisticsStore

    private var processingTask: Task<Void, Never>?
    private var pdfPreflightTask: Task<Void, Never>?
    private var cancellationToken: CancellationToken?

    init(settings: AppSettings, stats: StatisticsStore) {
        self.settings = settings
        self.stats = stats
    }

    var queuedCount: Int { items.filter { $0.state == .queued }.count }
    var optimizedCount: Int { batchProgress.optimized }
    var unchangedCount: Int { batchProgress.unchanged }
    var failedCount: Int { batchProgress.failed }
    var completedCount: Int { batchProgress.completed }

    var totalSavedBytes: Int64 { batchProgress.bytesSaved }
    var hasPendingPDFEstimate: Bool { items.contains { $0.format == .pdf && $0.estimatedBytes != nil && ($0.state == .queued || $0.state == .analyzing) } }
    var estimatedPDFCount: Int { items.filter { $0.format == .pdf && $0.estimatedBytes != nil }.count }
    var totalEstimatedPDFBytes: Int64 { items.compactMap { $0.format == .pdf ? $0.estimatedBytes : nil }.reduce(0, +) }
    var totalOriginalPDFBytes: Int64 { items.filter { $0.format == .pdf && $0.estimatedBytes != nil }.map(\.originalBytes).reduce(0, +) }
    var pdfExactDuplicateCount: Int { items.filter { $0.format == .pdf }.reduce(0) { $0 + $1.pdfExactDuplicatePages.count } }
    var pdfSimilarPairCount: Int { items.filter { $0.format == .pdf }.reduce(0) { $0 + $1.pdfSimilarPairs.count } }
    var hasPDFSimilarPairs: Bool { pdfSimilarPairCount > 0 }

    var pdfPreflightTotalCount: Int {
        items.filter { $0.format == .pdf }.count
    }

    var pdfPreflightCompletedCount: Int {
        items.filter { item in
            guard item.format == .pdf else { return false }
            if case .analyzing = item.state { return false }
            return true
        }.count
    }

    var pdfPreflightFraction: Double {
        guard pdfPreflightTotalCount > 0 else { return 0 }
        return min(1, max(0, Double(pdfPreflightCompletedCount) / Double(pdfPreflightTotalCount)))
    }

    var pdfPreflightPercent: Int {
        Int((pdfPreflightFraction * 100).rounded())
    }

    var totalSavingsPercent: Int {
        guard batchProgress.bytesIn > 0 else { return 0 }
        return Int((Double(batchProgress.bytesSaved) / Double(batchProgress.bytesIn) * 100).rounded())
    }

    var resultSummary: String {
        var parts: [String] = []
        if optimizedCount > 0 { parts.append("\(optimizedCount) optimized") }
        if unchangedCount > 0 { parts.append("\(unchangedCount) already optimal") }
        if failedCount > 0 { parts.append("\(failedCount) failed") }
        if batchProgress.cancelled > 0 { parts.append("\(batchProgress.cancelled) cancelled") }
        return parts.isEmpty ? "No files changed" : parts.joined(separator: " · ")
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.title = CapabilityResolver.canProcess(.pdf) ? "Choose files" : "Choose images"
        panel.prompt = "Add"
        panel.message = "JPEG, PNG and WebP are built in. PDF Tools and other formats can be added from Extensions."
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.resolvesAliases = true
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func add(urls: [URL]) {
        guard screen == .main else { return }

        if resultDrawerVisible && !isProcessing {
            items.removeAll()
            resultDrawerVisible = false
            recalculateBatchProgress()
        }

        let expanded = expandDirectories(urls)
        var existing = Set(items.map { $0.url.standardizedFileURL.path })
        var additions: [CompressionItem] = []
        var missingExtensions: [ExtensionID] = []

        for url in expanded {
            let normalized = url.standardizedFileURL
            guard !existing.contains(normalized.path) else { continue }
            guard let format = FileSniffer.detect(url: normalized), format != .unknown else { continue }

            if !CapabilityResolver.canProcess(format) {
                if let required = CapabilityResolver.missingExtension(for: format), !missingExtensions.contains(required) {
                    missingExtensions.append(required)
                }
                continue
            }

            let bytes = FileSniffer.fileSize(url: normalized)
            guard bytes > 0 else { continue }
            additions.append(CompressionItem(url: normalized, format: format, originalBytes: bytes))
            existing.insert(normalized.path)
        }

        items.append(contentsOf: additions)
        recalculateBatchProgress()

        if let missing = missingExtensions.first {
            alertMessage = "\(missing.title) is needed for this file. Install it in Settings → Extensions."
        } else if additions.isEmpty && items.isEmpty {
            alertMessage = "IMGLESS could not find a supported file in that selection."
        }

        if !additions.isEmpty {
            if additions.contains(where: { $0.format == .pdf }) {
                startPDFPreflight()
            } else {
                requestStart()
            }
        }
    }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        guard screen == .main else { return false }
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let nsurl = item as? NSURL { url = nsurl as URL }
                else if let directURL = item as? URL { url = directURL }
                guard let url else { return }
                Task { @MainActor in self?.add(urls: [url]) }
            }
        }
        return accepted
    }

    func requestStart() {
        guard !isProcessing, queuedCount > 0 else { return }
        resultDrawerVisible = false
        pdfEstimateVisible = false
        if settings.keepOriginals == false {
            showReplaceConfirmation = true
        } else {
            startProcessing()
        }
    }

    func startProcessing() {
        guard !isProcessing, queuedCount > 0 else { return }
        let missing = Compressor.missingRequiredTools()
        if !missing.isEmpty {
            alertMessage = "Core compression tools are missing: \(missing.joined(separator: ", ")). Run Install.command again."
            return
        }
        if settings.keepOriginals && settings.saveLocation == .folder && settings.outputFolderPath == nil {
            settings.chooseOutputFolder()
            guard settings.outputFolderPath != nil else { return }
        }

        let token = CancellationToken()
        cancellationToken = token
        isCancelling = false
        isProcessing = true
        resultDrawerVisible = false
        recalculateBatchProgress()
        let snapshot = settings.snapshot()
        processingTask = Task { [weak self] in
            guard let self else { return }
            await self.processQueue(snapshot: snapshot, token: token)
        }
    }

    func cancelBatch() {
        guard isProcessing, !isCancelling else { return }
        isCancelling = true
        cancellationToken?.cancel()
        processingTask?.cancel()
    }

    private func processQueue(snapshot: SettingsSnapshot, token: CancellationToken) async {
        while !token.isCancelled {
            let jobs: [ProcessingJob] = items.compactMap { item in
                guard item.state == .queued else { return nil }
                let exact = snapshot.removeExactPDFDuplicates ? item.pdfExactDuplicatePages : []
                let selected = Array(item.pdfSelectedSimilarDuplicates)
                return ProcessingJob(
                    id: item.id,
                    url: item.url,
                    format: item.format,
                    originalBytes: item.originalBytes,
                    pdfPagesToRemove: Array(Set(exact + selected)).sorted()
                )
            }
            guard !jobs.isEmpty else { break }

            let parallelism = AdaptiveScheduler.maxConcurrentJobs(for: jobs, settings: snapshot)
            var nextJob = 0

            await withTaskGroup(of: ScheduledCompressionResult.self) { group in
                let initial = min(parallelism, jobs.count)
                for _ in 0..<initial where !token.isCancelled {
                    let job = jobs[nextJob]
                    nextJob += 1
                    markSqueezing(job.id)
                    group.addTask(priority: .userInitiated) {
                        if token.isCancelled || Task.isCancelled {
                            return ScheduledCompressionResult(job: job, result: .init(outcome: .cancelled))
                        }
                        return ScheduledCompressionResult(
                            job: job,
                            result: Compressor.compress(
                                url: job.url,
                                format: job.format,
                                originalBytes: job.originalBytes,
                                settings: snapshot,
                                cancellation: token,
                                pdfPagesToRemove: job.pdfPagesToRemove
                            )
                        )
                    }
                }

                while let completed = await group.next() {
                    apply(completed)
                    if token.isCancelled || Task.isCancelled {
                        group.cancelAll()
                        continue
                    }
                    if nextJob < jobs.count {
                        let job = jobs[nextJob]
                        nextJob += 1
                        markSqueezing(job.id)
                        group.addTask(priority: .userInitiated) {
                            if token.isCancelled || Task.isCancelled {
                                return ScheduledCompressionResult(job: job, result: .init(outcome: .cancelled))
                            }
                            return ScheduledCompressionResult(
                                job: job,
                                result: Compressor.compress(
                                    url: job.url,
                                    format: job.format,
                                    originalBytes: job.originalBytes,
                                    settings: snapshot,
                                    cancellation: token,
                                    pdfPagesToRemove: job.pdfPagesToRemove
                                )
                            )
                        }
                    }
                }
            }
        }

        if token.isCancelled {
            for index in items.indices where items[index].state == .queued {
                items[index].state = .cancelled
            }
        }

        isProcessing = false
        isCancelling = false
        cancellationToken = nil
        processingTask = nil
        recalculateBatchProgress()
        resultDrawerVisible = batchProgress.completed > 0 || batchProgress.cancelled > 0
    }

    private func markSqueezing(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .squeezing
        recalculateBatchProgress()
    }

    private func apply(_ completed: ScheduledCompressionResult) {
        guard let index = items.firstIndex(where: { $0.id == completed.job.id }) else { return }
        switch completed.result.outcome {
        case .done(let output, let bytes, let outputFormat):
            items[index].outputURL = output
            items[index].outputBytes = bytes
            items[index].outputFormat = outputFormat
            items[index].state = .done
            stats.record(originalBytes: completed.job.originalBytes, outputBytes: bytes)
        case .dry:
            items[index].state = .dry
        case .failed(let message):
            items[index].state = .failed(message)
        case .cancelled:
            items[index].state = .cancelled
        }
        recalculateBatchProgress()
    }

    private func recalculateBatchProgress() {
        var progress = BatchProgress(total: items.count)
        for item in items {
            switch item.state {
            case .queued, .analyzing:
                progress.waiting += 1
            case .squeezing:
                progress.active += 1
            case .done:
                progress.completed += 1
                progress.bytesIn += item.originalBytes
                let output = item.outputBytes ?? item.originalBytes
                progress.bytesOut += output
                let saved = max(0, item.originalBytes - output)
                progress.bytesSaved += saved
                if saved > 0 { progress.optimized += 1 }
                else { progress.unchanged += 1 }
            case .dry:
                progress.completed += 1
                progress.unchanged += 1
                progress.bytesIn += item.originalBytes
                progress.bytesOut += item.originalBytes
            case .failed:
                progress.completed += 1
                progress.failed += 1
            case .cancelled:
                progress.cancelled += 1
            }
        }
        batchProgress = progress
    }



    func startPDFPreflight() {
        // Capture every value needed by background workers while we are still
        // on MainActor. The task group never reads CompressionModel.items.
        let workItems: [PDFPreflightWorkItem] = items.compactMap { item in
            guard item.format == .pdf,
                  item.estimatedBytes == nil,
                  item.state == .queued else { return nil }
            return PDFPreflightWorkItem(
                id: item.id,
                url: item.url,
                originalBytes: item.originalBytes
            )
        }

        guard !workItems.isEmpty else {
            pdfEstimateVisible = items.contains { $0.format == .pdf && $0.estimatedBytes != nil }
            return
        }

        let snapshot = settings.snapshot()

        pdfPreflightTask?.cancel()
        isPreflightingPDF = true
        pdfEstimateVisible = false
        resultDrawerVisible = false

        for work in workItems {
            if let index = items.firstIndex(where: { $0.id == work.id }) {
                items[index].state = .analyzing
            }
        }
        recalculateBatchProgress()

        pdfPreflightTask = Task { [weak self, workItems, snapshot] in
            guard let self else { return }
            let parallelism = min(2, max(1, workItems.count))
            var nextIndex = 0

            await withTaskGroup(of: (UUID, Result<PDFPreflightReport, CompressionError>).self) { group in
                func addJob(_ work: PDFPreflightWorkItem) {
                    group.addTask(priority: .userInitiated) {
                        if Task.isCancelled {
                            return (work.id, .failure(.message("Cancelled")))
                        }
                        do {
                            let report = try PDFTools.preflight(
                                input: work.url,
                                originalBytes: work.originalBytes,
                                mode: snapshot.pdfCompressionMode,
                                duplicateMode: snapshot.pdfDuplicateMode,
                                removeExactDuplicates: snapshot.removeExactPDFDuplicates
                            )
                            return (work.id, .success(report))
                        } catch let error as CompressionError {
                            return (work.id, .failure(error))
                        } catch {
                            return (work.id, .failure(.message(error.localizedDescription)))
                        }
                    }
                }

                for _ in 0..<parallelism where nextIndex < workItems.count {
                    addJob(workItems[nextIndex])
                    nextIndex += 1
                }

                while let (id, result) = await group.next() {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }

                    guard let index = self.items.firstIndex(where: { $0.id == id }) else { continue }
                    switch result {
                    case .success(let report):
                        if report.encrypted {
                            self.items[index].state = .failed("Encrypted PDF")
                        } else if report.signed {
                            self.items[index].state = .failed("Digitally signed PDF")
                        } else if report.alreadyOptimal {
                            self.items[index].state = .dry
                        } else {
                            self.items[index].estimatedBytes = report.estimatedBytes
                            self.items[index].pdfExactDuplicatePages = report.exactDuplicatePages
                            self.items[index].pdfSimilarPairs = report.similarPairs
                            self.items[index].state = .queued
                        }
                    case .failure(let error):
                        if error.description != "Cancelled" {
                            self.items[index].state = .failed(error.description)
                        }
                    }
                    self.recalculateBatchProgress()

                    if nextIndex < workItems.count && !Task.isCancelled {
                        addJob(workItems[nextIndex])
                        nextIndex += 1
                    }
                }
            }

            guard !Task.isCancelled else { return }
            self.isPreflightingPDF = false
            self.pdfPreflightTask = nil
            self.pdfEstimateVisible = self.hasPendingPDFEstimate
            if !self.pdfEstimateVisible {
                self.resultDrawerVisible = self.batchProgress.completed > 0
            }
        }
    }

    func skipPDFEstimate() {
        guard isPreflightingPDF else { return }

        pdfPreflightTask?.cancel()
        pdfPreflightTask = nil
        isPreflightingPDF = false
        pdfEstimateVisible = false

        for index in items.indices {
            if case .analyzing = items[index].state {
                items[index].state = .queued
                items[index].estimatedBytes = nil
                items[index].pdfExactDuplicatePages = []
                items[index].pdfSimilarPairs = []
                items[index].pdfSelectedSimilarDuplicates = []
            }
        }
        recalculateBatchProgress()
        requestStart()
    }

    func beginPDFSimilarReview() {
        pdfReviewItemID = items.first(where: { !$0.pdfSimilarPairs.isEmpty })?.id
    }

    func finishPDFSimilarReview() {
        pdfReviewItemID = nil
    }

    func isSimilarPageSelected(itemID: UUID, pageIndex: Int) -> Bool {
        items.first(where: { $0.id == itemID })?.pdfSelectedSimilarDuplicates.contains(pageIndex) ?? false
    }

    func setSimilarPageSelected(itemID: UUID, pageIndex: Int, selected: Bool) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if selected {
            items[index].pdfSelectedSimilarDuplicates.insert(pageIndex)
        } else {
            items[index].pdfSelectedSimilarDuplicates.remove(pageIndex)
        }
    }

    func startEstimatedBatch() {
        pdfReviewItemID = nil
        requestStart()
    }
    func dismissResult() {
        clearAll()
    }

    func clearAll() {
        guard !isProcessing else { return }
        pdfPreflightTask?.cancel()
        pdfPreflightTask = nil
        items.removeAll()
        resultDrawerVisible = false
        pdfEstimateVisible = false
        pdfReviewItemID = nil
        isPreflightingPDF = false
        screen = .main
        recalculateBatchProgress()
    }

    func revealResults() {
        let urls = items.compactMap { item -> URL? in
            switch item.state {
            case .done: return item.outputURL
            case .dry: return item.url
            default: return nil
            }
        }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func expandDirectories(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        for url in urls {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let child as URL in enumerator {
                        if (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                            result.append(child)
                        }
                    }
                }
            } else {
                result.append(url)
            }
        }
        return result
    }
}

// MARK: - File detection

enum FileSniffer {
    static func detect(url: URL) -> ImageFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let bytes: Data
        do { bytes = try handle.read(upToCount: 65_536) ?? Data() }
        catch { return nil }
        guard bytes.count >= 4 else { return ImageFormat.fromExtension(url.pathExtension) }
        let b = [UInt8](bytes)

        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return .jpeg }
        if b.count >= 8, Array(b[0..<8]) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
            if bytes.range(of: Data("acTL".utf8)) != nil { return .apng }
            return .png
        }
        if b.count >= 12,
           String(bytes: b[0..<4], encoding: .ascii) == "RIFF",
           String(bytes: b[8..<12], encoding: .ascii) == "WEBP" {
            if bytes.range(of: Data("ANIM".utf8)) != nil || bytes.range(of: Data("ANMF".utf8)) != nil {
                return .animatedWebP
            }
            return .webp
        }
        if b.count >= 5, String(bytes: b[0..<5], encoding: .ascii) == "%PDF-" { return .pdf }
        if b.count >= 6 {
            let sig = String(bytes: b[0..<6], encoding: .ascii) ?? ""
            if sig == "GIF87a" || sig == "GIF89a" { return .gif }
        }
        if b.count >= 2, b[0] == 0x42, b[1] == 0x4D { return .bmp }
        if b.count >= 4 {
            let first4 = Array(b[0..<4])
            if first4 == [0x49, 0x49, 0x2A, 0x00] || first4 == [0x4D, 0x4D, 0x00, 0x2A] ||
               first4 == [0x49, 0x49, 0x2B, 0x00] || first4 == [0x4D, 0x4D, 0x00, 0x2B] {
                let ext = url.pathExtension.lowercased()
                if ["dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "pef"].contains(ext) { return .raw }
                return .tiff
            }
        }
        if b.count >= 16, String(bytes: b[4..<8], encoding: .ascii) == "ftyp" {
            let brandData = Data(b[8..<min(b.count, 80)])
            let brands = String(data: brandData, encoding: .ascii) ?? ""
            if brands.contains("avif") || brands.contains("avis") { return .avif }
            let heifBrands = ["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1", "heif"]
            if heifBrands.contains(where: { brands.contains($0) }) { return .heic }
        }
        let byExtension = ImageFormat.fromExtension(url.pathExtension)
        return byExtension == .unknown ? .unknown : byExtension
    }

    static func fileSize(url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
}
// MARK: - PDF Tools

enum PDFTools {
    static func preflight(
        input: URL,
        originalBytes: Int64,
        mode: PDFCompressionMode,
        duplicateMode: PDFDuplicateMode,
        removeExactDuplicates: Bool
    ) throws -> PDFPreflightReport {
        guard let document = PDFDocument(url: input) else {
            throw CompressionError.message("IMGLESS could not open this PDF.")
        }
        let encrypted = document.isEncrypted && !document.unlock(withPassword: "")
        let signed = containsSignatureMarker(url: input)
        let pageCount = max(1, document.pageCount)
        guard !encrypted, !signed else {
            return PDFPreflightReport(
                pageCount: pageCount,
                estimatedBytes: originalBytes,
                encrypted: encrypted,
                signed: signed,
                alreadyOptimal: false,
                exactDuplicatePages: [],
                similarPairs: []
            )
        }

        let duplicateReport = try detectDuplicates(document: document, mode: duplicateMode)
        let exactPagesToRemove = removeExactDuplicates ? duplicateReport.exactPages : []
        let source = try sourceRemovingPages(input: input, pagesToRemove: exactPagesToRemove)
        defer {
            if source != input { try? FileManager.default.removeItem(at: source) }
        }

        let estimate: Int64
        switch mode {
        case .light, .balanced, .aggressive:
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-pdf-preflight-\(UUID().uuidString).pdf")
            defer { try? FileManager.default.removeItem(at: temp) }
            try compressStructurePreserving(input: source, output: temp, mode: mode, cancellation: nil)
            let bytes = FileSniffer.fileSize(url: temp)
            estimate = bytes > 0 ? bytes : originalBytes
        case .maximum:
            guard let dedupedDocument = PDFDocument(url: source) else {
                throw CompressionError.message("IMGLESS could not analyze the deduplicated PDF.")
            }
            estimate = try estimateMaximumRaster(document: dedupedDocument, originalBytes: originalBytes)
        }

        return PDFPreflightReport(
            pageCount: pageCount,
            estimatedBytes: estimate,
            encrypted: false,
            signed: false,
            alreadyOptimal: false,
            exactDuplicatePages: duplicateReport.exactPages,
            similarPairs: duplicateReport.similarPairs
        )
    }

    static func compress(
        input: URL,
        output: URL,
        mode: PDFCompressionMode,
        pagesToRemove: [Int],
        cancellation: CancellationToken?
    ) throws {
        guard let document = PDFDocument(url: input) else {
            throw CompressionError.message("IMGLESS could not open this PDF.")
        }
        if document.isEncrypted && !document.unlock(withPassword: "") {
            throw CompressionError.message("Encrypted PDF")
        }
        if containsSignatureMarker(url: input) {
            throw CompressionError.message("Digitally signed PDF")
        }

        let source = try sourceRemovingPages(input: input, pagesToRemove: pagesToRemove)
        defer {
            if source != input { try? FileManager.default.removeItem(at: source) }
        }

        switch mode {
        case .light, .balanced, .aggressive:
            try compressStructurePreserving(input: source, output: output, mode: mode, cancellation: cancellation)
        case .maximum:
            guard let preparedDocument = PDFDocument(url: source) else {
                throw CompressionError.message("IMGLESS could not prepare this PDF.")
            }
            try compressMaximumRaster(document: preparedDocument, output: output, cancellation: cancellation)
        }
    }

    private struct DuplicateReport {
        let exactPages: [Int]
        let similarPairs: [PDFSimilarPair]
    }

    private static func detectDuplicates(document: PDFDocument, mode: PDFDuplicateMode) throws -> DuplicateReport {
        guard mode != .off, document.pageCount > 1 else {
            return DuplicateReport(exactPages: [], similarPairs: [])
        }

        var exactPages: [Int] = []
        var fingerprints: [UInt64: Int] = [:]
        var perceptual: [UInt64] = []
        perceptual.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CompressionError.message("Cancelled") }
            guard let page = document.page(at: index) else {
                perceptual.append(0)
                continue
            }
            let exact = try exactFingerprint(page)
            if fingerprints[exact] != nil {
                exactPages.append(index)
            } else {
                fingerprints[exact] = index
            }
            if mode == .reviewSimilar {
                perceptual.append(try perceptualHash(page))
            } else {
                perceptual.append(0)
            }
        }

        guard mode == .reviewSimilar else {
            return DuplicateReport(exactPages: exactPages, similarPairs: [])
        }

        let exactSet = Set(exactPages)
        var similarPairs: [PDFSimilarPair] = []
        for i in 0..<document.pageCount {
            if Task.isCancelled { throw CompressionError.message("Cancelled") }
            for j in (i + 1)..<document.pageCount {
                if Task.isCancelled { throw CompressionError.message("Cancelled") }
                if exactSet.contains(j) { continue }
                let similarity = hashSimilarity(perceptual[i], perceptual[j])
                if similarity >= 0.94 && similarity < 1.0 {
                    similarPairs.append(PDFSimilarPair(firstPage: i, secondPage: j, similarity: similarity))
                    if similarPairs.count >= 80 { return DuplicateReport(exactPages: exactPages, similarPairs: similarPairs) }
                }
            }
        }
        return DuplicateReport(exactPages: exactPages, similarPairs: similarPairs)
    }

    private static func exactFingerprint(_ page: PDFPage) throws -> UInt64 {
        let bounds = page.bounds(for: .mediaBox)
        let width = 128
        let height = max(1, Int((CGFloat(width) * bounds.height / max(bounds.width, 1)).rounded()))
        let bytes = try renderedGrayBytes(page, width: width, height: min(256, height))
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        if let text = page.string {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
        }
        hash ^= UInt64(Int(bounds.width.rounded())) &* 31
        hash ^= UInt64(Int(bounds.height.rounded())) &* 131
        return hash
    }

    private static func perceptualHash(_ page: PDFPage) throws -> UInt64 {
        let bytes = try renderedGrayBytes(page, width: 8, height: 8)
        guard !bytes.isEmpty else { return 0 }
        let average = bytes.reduce(0) { $0 + Int($1) } / bytes.count
        var hash: UInt64 = 0
        for (index, byte) in bytes.prefix(64).enumerated() where Int(byte) >= average {
            hash |= UInt64(1) << UInt64(index)
        }
        return hash
    }

    private static func hashSimilarity(_ a: UInt64, _ b: UInt64) -> Double {
        let distance = (a ^ b).nonzeroBitCount
        return 1.0 - Double(distance) / 64.0
    }

    private static func renderedGrayBytes(_ page: PDFPage, width: Int, height: Int) throws -> [UInt8] {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 1,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceWhite,
            bytesPerRow: width,
            bitsPerPixel: 8
        ), let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
            throw CompressionError.message("IMGLESS could not render a PDF page for duplicate detection.")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(CGFloat(width) / max(bounds.width, 1), CGFloat(height) / max(bounds.height, 1))
        let drawWidth = bounds.width * scale
        let drawHeight = bounds.height * scale
        let x = (CGFloat(width) - drawWidth) / 2
        let y = (CGFloat(height) - drawHeight) / 2
        graphics.cgContext.translateBy(x: x, y: y)
        graphics.cgContext.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: graphics.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return [] }
        return Array(UnsafeBufferPointer(start: data, count: width * height))
    }

    private static func sourceRemovingPages(input: URL, pagesToRemove: [Int]) throws -> URL {
        let valid = Set(pagesToRemove.filter { $0 >= 0 })
        guard !valid.isEmpty else { return input }
        guard let document = PDFDocument(url: input) else {
            throw CompressionError.message("IMGLESS could not open this PDF for duplicate removal.")
        }
        let indexes = valid.filter { $0 < document.pageCount }.sorted(by: >)
        for index in indexes { document.removePage(at: index) }
        guard document.pageCount > 0 else {
            throw CompressionError.message("Duplicate removal would leave the PDF empty.")
        }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("IMGLESS-pdf-dedup-\(UUID().uuidString).pdf")
        guard document.write(to: temp) else {
            throw CompressionError.message("IMGLESS could not write the PDF after removing duplicate pages.")
        }
        return temp
    }

    private static func compressStructurePreserving(
        input: URL,
        output: URL,
        mode: PDFCompressionMode,
        cancellation: CancellationToken?
    ) throws {
        guard let qpdf = Toolchain.locate("qpdf") else {
            throw CompressionError.message("PDF Tools needs qpdf. Reinstall the extension.")
        }
        guard let pdfcpu = Toolchain.locate("pdfcpu") else {
            throw CompressionError.message("PDF Tools needs pdfcpu. Reinstall the extension.")
        }

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("IMGLESS-pdf-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let stageQPDF = workDir.appendingPathComponent("qpdf.pdf")
        let stagePDFCPU = workDir.appendingPathComponent("pdfcpu.pdf")
        try cancellation?.check()

        var qpdfArgs = [
            "--object-streams=generate",
            "--compress-streams=y",
            "--decode-level=generalized",
            "--recompress-flate",
            "--compression-level=9"
        ]

        switch mode {
        case .light:
            break
        case .balanced:
            qpdfArgs += [
                "--optimize-images",
                "--oi-min-width=900",
                "--oi-min-height=900",
                "--oi-min-area=700000"
            ]
        case .aggressive:
            qpdfArgs += [
                "--optimize-images",
                "--oi-min-width=0",
                "--oi-min-height=0",
                "--oi-min-area=0"
            ]
        case .maximum:
            throw CompressionError.message("Maximum PDF compression uses the raster engine.")
        }
        qpdfArgs += [input.path, stageQPDF.path]

        let qpdfResult = try ProcessRunner.runWithStatus(qpdf, qpdfArgs)
        guard (qpdfResult.status == 0 || qpdfResult.status == 3), fm.fileExists(atPath: stageQPDF.path) else {
            let detail = qpdfResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CompressionError.message(detail.isEmpty ? "qpdf could not optimize this PDF." : detail)
        }

        try cancellation?.check()
        let cpuResult = try ProcessRunner.runWithStatus(pdfcpu, [
            "optimize", stageQPDF.path, stagePDFCPU.path,
            "-q", "-c", "disable"
        ])

        let qpdfBytes = FileSniffer.fileSize(url: stageQPDF)
        let pdfcpuBytes = FileSniffer.fileSize(url: stagePDFCPU)
        let best: URL
        if cpuResult.status == 0, pdfcpuBytes > 0, pdfcpuBytes < qpdfBytes {
            best = stagePDFCPU
        } else {
            best = stageQPDF
        }

        try cancellation?.check()
        if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
        try fm.copyItem(at: best, to: output)
    }

    private static func compressMaximumRaster(
        document: PDFDocument,
        output: URL,
        cancellation: CancellationToken?
    ) throws {
        guard let consumer = CGDataConsumer(url: output as CFURL) else {
            throw CompressionError.message("IMGLESS could not create the output PDF.")
        }
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
            throw CompressionError.message("IMGLESS could not create the output PDF context.")
        }

        let dpi: CGFloat = 72
        let jpegQuality: CGFloat = 0.34
        for pageIndex in 0..<document.pageCount {
            try cancellation?.check()
            guard let page = document.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .mediaBox).integral
            let image = try renderPage(page, dpi: dpi, jpegQuality: jpegQuality)
            var pageBox = CGRect(origin: .zero, size: bounds.size)
            let pageInfo = [kCGPDFContextMediaBox as String: Data(bytes: &pageBox, count: MemoryLayout<CGRect>.size)] as CFDictionary
            context.beginPDFPage(pageInfo)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageBox)
            context.draw(image, in: pageBox)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func estimateMaximumRaster(document: PDFDocument, originalBytes: Int64) throws -> Int64 {
        guard document.pageCount > 0 else { return originalBytes }
        let count = document.pageCount
        let sampleIndexes = Array(Set([0, count / 2, max(0, count - 1)])).sorted()
        var sampleBytes: Int64 = 0
        var sampled = 0
        for index in sampleIndexes {
            guard let page = document.page(at: index) else { continue }
            let data = try renderPageJPEGData(page, dpi: 72, jpegQuality: 0.34)
            sampleBytes += Int64(data.count)
            sampled += 1
        }
        guard sampled > 0 else { return originalBytes }
        let average = Double(sampleBytes) / Double(sampled)
        let estimate = Int64((average * Double(count) + Double(count) * 2_048 + 48_000).rounded())
        return max(64_000, estimate)
    }

    private static func renderPage(_ page: PDFPage, dpi: CGFloat, jpegQuality: CGFloat) throws -> CGImage {
        let data = try renderPageJPEGData(page, dpi: dpi, jpegQuality: jpegQuality)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CompressionError.message("IMGLESS could not compress a PDF page.")
        }
        return image
    }

    private static func renderPageJPEGData(_ page: PDFPage, dpi: CGFloat, jpegQuality: CGFloat) throws -> Data {
        let bounds = page.bounds(for: .mediaBox).integral
        let scale = dpi / 72.0
        let pixelWidth = max(1, Int(bounds.width * scale))
        let pixelHeight = max(1, Int(bounds.height * scale))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CompressionError.message("IMGLESS could not render a PDF page.")
        }

        NSGraphicsContext.saveGraphicsState()
        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw CompressionError.message("IMGLESS could not render a PDF page.")
        }
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: NSSize(width: pixelWidth, height: pixelHeight))).fill()
        let cg = graphics.cgContext
        cg.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: cg)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
            throw CompressionError.message("IMGLESS could not encode a PDF page.")
        }
        return data
    }

    static func verify(
        input: URL,
        output: URL,
        mode: PDFCompressionMode,
        pagesRemoved: [Int]
    ) throws {
        guard let before = PDFDocument(url: input), let after = PDFDocument(url: output) else {
            throw CompressionError.message("IMGLESS could not verify the compressed PDF.")
        }
        let removed = Set(pagesRemoved)
        let keptIndexes = (0..<before.pageCount).filter { !removed.contains($0) }
        guard keptIndexes.count == after.pageCount else {
            throw CompressionError.message("Verification failed: unexpected page count after duplicate removal.")
        }

        for (outputIndex, originalIndex) in keptIndexes.enumerated() {
            guard let a = before.page(at: originalIndex), let b = after.page(at: outputIndex) else { continue }
            let aBox = a.bounds(for: .mediaBox)
            let bBox = b.bounds(for: .mediaBox)
            guard abs(aBox.width - bBox.width) < 1.0, abs(aBox.height - bBox.height) < 1.0 else {
                throw CompressionError.message("Verification failed: page dimensions changed.")
            }
        }

        if mode != .maximum, !keptIndexes.isEmpty {
            let candidates = Array(Set([0, keptIndexes.count / 2, max(0, keptIndexes.count - 1)])).sorted()
            for outputIndex in candidates where outputIndex < keptIndexes.count {
                let originalIndex = keptIndexes[outputIndex]
                let originalText = before.page(at: originalIndex)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !originalText.isEmpty {
                    let outputText = after.page(at: outputIndex)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !outputText.isEmpty else {
                        throw CompressionError.message("Verification failed: selectable text was lost.")
                    }
                }
            }
        }

        if let pdfcpu = Toolchain.locate("pdfcpu") {
            let result = try ProcessRunner.runWithStatus(pdfcpu, ["validate", output.path, "-q", "-c", "disable"])
            guard result.status == 0 else {
                throw CompressionError.message("Verification failed: pdfcpu rejected the output PDF.")
            }
        }
    }

    static func containsSignatureMarker(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return false }
        let prefix = data.prefix(min(data.count, 1_500_000))
        guard let string = String(data: prefix, encoding: .ascii) else { return false }
        return string.contains("/ByteRange") || string.contains("/Sig")
    }
}
// MARK: - inspect → clean → verify

enum Inspector {
    static func inspect(url: URL, expectedFormat: ImageFormat? = nil) throws -> InspectionReport {
        guard let format = FileSniffer.detect(url: url), format != .unknown else {
            throw CompressionError.message("IMGLESS could not identify this image format.")
        }
        if let expectedFormat, expectedFormat != format {
            throw CompressionError.message("The output file format does not match the requested format.")
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw CompressionError.message("IMGLESS could not decode this image.")
        }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard width > 0, height > 0 else {
            throw CompressionError.message("IMGLESS could not read image dimensions.")
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue
        let metadataCount = CapabilityResolver.metadataCleanerAvailable
            ? (try removableMetadataCount(url: url))
            : 0

        return InspectionReport(
            format: format,
            width: width,
            height: height,
            frameCount: max(1, CGImageSourceGetCount(source)),
            orientation: orientation,
            removableMetadataCount: metadataCount,
            hasProvenanceMarkers: false
        )
    }

    static func verify(
        before: InspectionReport,
        output: URL,
        targetFormat: ImageFormat,
        metadataMode: MetadataMode
    ) throws -> InspectionReport {
        let after = try inspect(url: output, expectedFormat: targetFormat)
        guard after.width == before.width, after.height == before.height else {
            throw CompressionError.message("Verification failed: image dimensions changed unexpectedly.")
        }
        guard after.frameCount == before.frameCount else {
            throw CompressionError.message("Verification failed: one or more image frames were lost.")
        }

        if metadataMode == .removeAll && CapabilityResolver.metadataCleanerAvailable {
            guard after.removableMetadataCount == 0 else {
                throw CompressionError.message("Verification failed: removable metadata is still present.")
            }
        }
        return after
    }

    private static func removableMetadataCount(url: URL) throws -> Int {
        guard let exiftool = Toolchain.locate("exiftool") else { return 0 }
        let out = try ProcessRunner.run(exiftool, [
            "-j", "-a", "-G1", "-s",
            "-EXIF:all", "-XMP:all", "-IPTC:all", "-ICC_Profile:all",
            "-Photoshop:all", "-MakerNotes:all", "-JUMBF:all", "-XML:all",
            "-Comment", "-Description", "-Software", "-Artist", "-Author",
            "-Copyright", "-Title", "-Keywords", "-GPS*", "-Location*",
            "-QuickTime:CreateDate", "-QuickTime:ModifyDate",
            url.path
        ])
        guard let data = out.data(using: .utf8),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = objects.first else { return 0 }
        return first.keys.filter { $0 != "SourceFile" }.count
    }
}

// MARK: - Compression

enum Compressor {
    static func missingRequiredTools() -> [String] {
        ["jpeg-recompress", "pngquant", "oxipng", "cwebp", "dwebp"].filter { Toolchain.locate($0) == nil }
    }

    static func compress(
        url: URL,
        format: ImageFormat,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken? = nil,
        pdfPagesToRemove: [Int] = []
    ) -> CompressionResult {
        do {
            try cancellation?.check()
            if format == .pdf {
                return compressPDF(
                    url: url,
                    originalBytes: originalBytes,
                    settings: settings,
                    cancellation: cancellation,
                    pagesToRemove: pdfPagesToRemove
                )
            }
            if format.isAnimation {
                return compressAnimation(url: url, format: format, originalBytes: originalBytes, settings: settings, cancellation: cancellation)
            }
            if format == .raw || format == .tiff {
                return compressPhotography(url: url, format: format, originalBytes: originalBytes, settings: settings, cancellation: cancellation)
            }
            if format.isLegacy {
                return compressLegacy(url: url, format: format, originalBytes: originalBytes, settings: settings, cancellation: cancellation)
            }
            // 1. INSPECT
            guard CapabilityResolver.canProcess(format) else {
                if let required = CapabilityResolver.missingExtension(for: format) {
                    throw CompressionError.message("\(required.title) is required for this format.")
                }
                throw CompressionError.message("Unsupported image format.")
            }

            let originalBefore = try Inspector.inspect(url: url, expectedFormat: format)
            let prepared = try prepareStaticInput(
                input: url,
                format: format,
                report: originalBefore,
                settings: settings
            )
            defer { prepared.temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }
            let workingURL = prepared.url
            let workingFormat = prepared.format
            let before = prepared.report
            try cancellation?.check()
            let targetFormat = resolveTargetFormat(input: format, choice: settings.output)
            guard targetFormat != .unknown, CapabilityResolver.canProcess(targetFormat) else {
                throw CompressionError.message("The selected output format needs an extension that is not installed.")
            }

            if before.frameCount > 1 && targetFormat != format {
                throw CompressionError.message("Animated or multi-image files currently stay in their original format.")
            }
            if before.frameCount > 1 && format == .webp && Toolchain.locate("magick") == nil {
                throw CompressionError.message("Animated WebP requires the Animation extension.")
            }

            let fm = FileManager.default
            let outputDir: URL
            if settings.keepOriginals && settings.saveLocation == .folder, let path = settings.outputFolderPath {
                outputDir = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                outputDir = url.deletingLastPathComponent()
            }
            try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let temp = outputDir.appendingPathComponent(".imgless-\(UUID().uuidString).\(targetFormat.fileExtension)")
            defer { try? fm.removeItem(at: temp) }

            let effectiveMetadata: MetadataMode =
                settings.metadataMode == .removeAll && CapabilityResolver.metadataCleanerAvailable
                ? .removeAll
                : .keep

            // 2. CLEAN
            try cancellation?.check()
            try clean(
                input: workingURL,
                inputFormat: workingFormat,
                before: before,
                output: temp,
                targetFormat: targetFormat,
                settings: settings,
                metadataMode: effectiveMetadata
            )

            try cancellation?.check()
            if effectiveMetadata == .removeAll {
                try sanitizeMetadata(at: temp)
            }
            let useAIProvenance = settings.useAIProvenance && WatermarksExtensionRunner.isInstalled
            if useAIProvenance {
                try WatermarksExtensionRunner.clean(url: temp)
            }

            var tempBytes = FileSniffer.fileSize(url: temp)
            guard tempBytes > 0 else {
                throw CompressionError.message("The encoder produced an empty file.")
            }

            // 3. VERIFY
            try cancellation?.check()
            do {
                _ = try Inspector.verify(
                    before: before,
                    output: temp,
                    targetFormat: targetFormat,
                    metadataMode: effectiveMetadata
                )
                if useAIProvenance {
                    try WatermarksExtensionRunner.verify(url: temp)
                }
            } catch {
                if effectiveMetadata == .removeAll || useAIProvenance {
                    if effectiveMetadata == .removeAll {
                        try sanitizeMetadata(at: temp)
                    }
                    if useAIProvenance {
                        try WatermarksExtensionRunner.clean(url: temp)
                    }
                    _ = try Inspector.verify(
                        before: before,
                        output: temp,
                        targetFormat: targetFormat,
                        metadataMode: effectiveMetadata
                    )
                    if useAIProvenance {
                        try WatermarksExtensionRunner.verify(url: temp)
                    }
                } else {
                    throw error
                }
            }

            tempBytes = FileSniffer.fileSize(url: temp)
            let explicitConversion = settings.output != .keepOriginal || targetFormat != format || settings.resizeMode != .original || settings.optimizeColorForSharing
            if !explicitConversion && tempBytes >= originalBytes && effectiveMetadata == .keep && !useAIProvenance {
                return try unchangedResult(
                    input: url,
                    originalBytes: originalBytes,
                    format: format,
                    settings: settings,
                    outputDir: outputDir,
                    temp: temp
                )
            }

            let finalURL = try finalize(
                temp: temp,
                input: url,
                targetFormat: targetFormat,
                settings: settings,
                outputDir: outputDir
            )
            return .init(outcome: .done(
                output: finalURL,
                bytes: FileSniffer.fileSize(url: finalURL),
                format: targetFormat
            ))
        } catch let error as CompressionError {
            if cancellation?.isCancelled == true || error.description == "Cancelled" {
                return .init(outcome: .cancelled)
            }
            return .init(outcome: .failed(error.description))
        } catch {
            return .init(outcome: .failed(error.localizedDescription))
        }
    }

    private static func compressPDF(
        url: URL,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken?,
        pagesToRemove: [Int]
    ) -> CompressionResult {
        do {
            let outputDir: URL
            if settings.keepOriginals && settings.saveLocation == .folder, let path = settings.outputFolderPath {
                outputDir = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                outputDir = url.deletingLastPathComponent()
            }
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let temp = outputDir.appendingPathComponent(".imgless-\(UUID().uuidString).pdf")
            defer { try? FileManager.default.removeItem(at: temp) }
            try cancellation?.check()
            try PDFTools.compress(
                input: url,
                output: temp,
                mode: settings.pdfCompressionMode,
                pagesToRemove: pagesToRemove,
                cancellation: cancellation
            )
            try cancellation?.check()
            try PDFTools.verify(
                input: url,
                output: temp,
                mode: settings.pdfCompressionMode,
                pagesRemoved: pagesToRemove
            )
            let tempBytes = FileSniffer.fileSize(url: temp)
            if tempBytes <= 0 {
                throw CompressionError.message("The PDF encoder produced an empty file.")
            }
            if tempBytes >= originalBytes && pagesToRemove.isEmpty {
                return try unchangedResult(
                    input: url,
                    originalBytes: originalBytes,
                    format: .pdf,
                    settings: settings,
                    outputDir: outputDir,
                    temp: temp
                )
            }
            let finalURL = try finalize(temp: temp, input: url, targetFormat: .pdf, settings: settings, outputDir: outputDir)
            return .init(outcome: .done(output: finalURL, bytes: FileSniffer.fileSize(url: finalURL), format: .pdf))
        } catch let error as CompressionError {
            if cancellation?.isCancelled == true || error.description == "Cancelled" {
                return .init(outcome: .cancelled)
            }
            return .init(outcome: .failed(error.description))
        } catch {
            return .init(outcome: .failed(error.localizedDescription))
        }
    }

    private static func compressAnimation(
        url: URL,
        format: ImageFormat,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken?
    ) -> CompressionResult {
        do {
            guard ExtensionRegistry.isInstalled(.animation),
                  let ffmpeg = Toolchain.locate("ffmpeg"),
                  let ffprobe = Toolchain.locate("ffprobe") else {
                throw CompressionError.message("Animation extension is required for this file.")
            }
            try cancellation?.check()
            let target: ImageFormat
            switch settings.animationOutput {
            case .original: target = format
            case .webp: target = .animatedWebP
            case .gif: target = .gif
            case .apng: target = .apng
            }
            let outputDir = try outputDirectory(for: url, settings: settings)
            let temp = outputDir.appendingPathComponent(".imgless-animation-\(UUID().uuidString).\(target.fileExtension)")
            defer { try? FileManager.default.removeItem(at: temp) }

            var args = ["-y", "-hide_banner", "-loglevel", "error", "-i", url.path, "-an"]
            var filters: [String] = []
            if let fps = settings.animationFrameRate.numericValue { filters.append("fps=\(fps)") }
            if let edge = settings.animationResize.maxEdge {
                filters.append("scale=\(edge):\(edge):force_original_aspect_ratio=decrease")
            }
            if !filters.isEmpty { args += ["-vf", filters.joined(separator: ",")] }

            switch target {
            case .gif:
                switch settings.animationLoopMode {
                case .preserve: break
                case .forever: args += ["-loop", "0"]
                case .once: args += ["-loop", "1"]
                }
            case .animatedWebP:
                let quality: String
                switch settings.animationCompression {
                case .bestQuality: quality = "90"
                case .balanced: quality = "78"
                case .smaller: quality = "62"
                }
                args += ["-c:v", "libwebp", "-compression_level", "6", "-quality", quality]
                switch settings.animationLoopMode {
                case .preserve: break
                case .forever: args += ["-loop", "0"]
                case .once: args += ["-loop", "1"]
                }
            case .apng:
                args += ["-f", "apng"]
                switch settings.animationLoopMode {
                case .preserve: break
                case .forever: args += ["-plays", "0"]
                case .once: args += ["-plays", "1"]
                }
            default:
                throw CompressionError.message("Unsupported animation output format.")
            }
            args += [temp.path]
            let encoded = try ProcessRunner.runWithStatus(ffmpeg, args)
            guard encoded.status == 0, FileSniffer.fileSize(url: temp) > 0 else {
                let detail = encoded.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw CompressionError.message(detail.isEmpty ? "Animation encoding failed." : detail)
            }
            let probe = try ProcessRunner.runWithStatus(ffprobe, [
                "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,nb_frames", "-of", "default=nw=1", temp.path
            ])
            guard probe.status == 0 else { throw CompressionError.message("Animation verification failed.") }

            let tempBytes = FileSniffer.fileSize(url: temp)
            let explicit = settings.animationOutput != .original || settings.animationFrameRate.numericValue != nil || settings.animationResize.maxEdge != nil
            if !explicit && tempBytes >= originalBytes {
                return try unchangedResult(input: url, originalBytes: originalBytes, format: format, settings: settings, outputDir: outputDir, temp: temp)
            }
            let finalURL = try finalize(temp: temp, input: url, targetFormat: target, settings: settings, outputDir: outputDir)
            return .init(outcome: .done(output: finalURL, bytes: FileSniffer.fileSize(url: finalURL), format: target))
        } catch let error as CompressionError {
            if cancellation?.isCancelled == true || error.description == "Cancelled" { return .init(outcome: .cancelled) }
            return .init(outcome: .failed(error.description))
        } catch {
            return .init(outcome: .failed(error.localizedDescription))
        }
    }

    private static func compressPhotography(
        url: URL,
        format: ImageFormat,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken?
    ) -> CompressionResult {
        do {
            guard ExtensionRegistry.isInstalled(.photography), let magick = Toolchain.locate("magick") else {
                throw CompressionError.message("Photography extension is required for TIFF and RAW files.")
            }
            try cancellation?.check()
            let isRAW = format == .raw
            let target: ImageFormat
            if isRAW {
                switch settings.photographyRAWOutput {
                case .jpeg: target = .jpeg
                case .webp: target = .webp
                case .avif: target = .avif
                case .heic: target = .heic
                case .tiff: target = .tiff
                }
            } else {
                target = resolveTargetFormat(input: format, choice: settings.output)
            }

            let outputDir = try outputDirectory(for: url, settings: settings)
            let temp = outputDir.appendingPathComponent(".imgless-photo-\(UUID().uuidString).\(target.fileExtension)")
            defer { try? FileManager.default.removeItem(at: temp) }
            let ext = url.pathExtension.lowercased()
            let source = isRAW && !ext.isEmpty ? "\(ext):\(url.path)[0]" : url.path
            var args = [source, "-auto-orient"]
            appendMagickResizeArgs(&args, settings: settings)
            if settings.optimizeColorForSharing { args += ["-colorspace", "sRGB"] }
            if !settings.preserveColorProfile { args += ["+profile", "icc"] }

            switch target {
            case .jpeg:
                args += ["-background", "white", "-alpha", "remove", "-alpha", "off", "-quality", jpegQualityValue(settings, automaticHigh: 94, automaticBalanced: 88, automaticSmall: 78)]
            case .webp:
                if settings.webpLossy && settings.allowLossyOptimization {
                    args += ["-quality", webPQualityValue(settings), "-define", "webp:method=6"]
                } else {
                    args += ["-define", "webp:lossless=true", "-define", "webp:method=6"]
                }
            case .avif:
                args += ["-quality", quality(settings.mode, high: 88, balanced: 74, small: 60)]
            case .heic:
                args += ["-quality", quality(settings.mode, high: 92, balanced: 82, small: 70)]
            case .tiff:
                args += ["-compress", "Zip", "-depth", settings.photographyPreserve16Bit ? "16" : "8"]
            default:
                throw CompressionError.message("Photography cannot export to this format.")
            }
            args += [temp.path]
            let result = try ProcessRunner.runWithStatus(magick, args)
            guard result.status == 0, FileSniffer.fileSize(url: temp) > 0 else {
                let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw CompressionError.message(detail.isEmpty ? "Photography conversion failed." : detail)
            }
            let verify = try ProcessRunner.runWithStatus(magick, ["identify", temp.path])
            guard verify.status == 0 else { throw CompressionError.message("Photography verification failed.") }

            let tempBytes = FileSniffer.fileSize(url: temp)
            if !isRAW && target == format && settings.resizeMode == .original && !settings.optimizeColorForSharing && tempBytes >= originalBytes {
                return try unchangedResult(input: url, originalBytes: originalBytes, format: format, settings: settings, outputDir: outputDir, temp: temp)
            }
            let finalURL: URL
            if isRAW {
                finalURL = try finalizeDerivative(temp: temp, input: url, targetFormat: target, settings: settings, outputDir: outputDir)
            } else {
                finalURL = try finalize(temp: temp, input: url, targetFormat: target, settings: settings, outputDir: outputDir)
            }
            return .init(outcome: .done(output: finalURL, bytes: FileSniffer.fileSize(url: finalURL), format: target))
        } catch let error as CompressionError {
            if cancellation?.isCancelled == true || error.description == "Cancelled" { return .init(outcome: .cancelled) }
            return .init(outcome: .failed(error.description))
        } catch {
            return .init(outcome: .failed(error.localizedDescription))
        }
    }

    private static func compressLegacy(
        url: URL,
        format: ImageFormat,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken?
    ) -> CompressionResult {
        do {
            guard ExtensionRegistry.isInstalled(.legacyFormats), let magick = Toolchain.locate("magick") else {
                throw CompressionError.message("Legacy Formats extension is required for this file.")
            }
            let target: ImageFormat
            switch settings.legacyPreferredOutput {
            case .original: target = format
            case .png: target = .png
            case .jpeg: target = .jpeg
            case .webp: target = .webp
            }
            let outputDir = try outputDirectory(for: url, settings: settings)
            let temp = outputDir.appendingPathComponent(".imgless-legacy-\(UUID().uuidString).\(target.fileExtension)")
            defer { try? FileManager.default.removeItem(at: temp) }
            var args = [url.path, "-auto-orient"]
            appendMagickResizeArgs(&args, settings: settings)
            if settings.optimizeColorForSharing { args += ["-colorspace", "sRGB"] }
            if !settings.preserveColorProfile { args += ["+profile", "icc"] }
            switch target {
            case .jpeg:
                args += ["-background", "white", "-alpha", "remove", "-alpha", "off", "-quality", jpegQualityValue(settings, automaticHigh: 94, automaticBalanced: 88, automaticSmall: 78)]
            case .webp:
                args += ["-quality", webPQualityValue(settings), "-define", "webp:method=6"]
            case .png:
                args += ["-define", "png:compression-level=9"]
            default:
                break
            }
            args += [temp.path]
            let result = try ProcessRunner.runWithStatus(magick, args)
            guard result.status == 0, FileSniffer.fileSize(url: temp) > 0 else {
                let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw CompressionError.message(detail.isEmpty ? "Legacy format conversion failed." : detail)
            }
            let verify = try ProcessRunner.runWithStatus(magick, ["identify", temp.path])
            guard verify.status == 0 else { throw CompressionError.message("Legacy format verification failed.") }
            let tempBytes = FileSniffer.fileSize(url: temp)
            if settings.legacyPreferredOutput == .original && settings.resizeMode == .original && tempBytes >= originalBytes {
                return try unchangedResult(input: url, originalBytes: originalBytes, format: format, settings: settings, outputDir: outputDir, temp: temp)
            }
            let finalURL = try finalize(temp: temp, input: url, targetFormat: target, settings: settings, outputDir: outputDir)
            return .init(outcome: .done(output: finalURL, bytes: FileSniffer.fileSize(url: finalURL), format: target))
        } catch let error as CompressionError {
            if cancellation?.isCancelled == true || error.description == "Cancelled" { return .init(outcome: .cancelled) }
            return .init(outcome: .failed(error.description))
        } catch {
            return .init(outcome: .failed(error.localizedDescription))
        }
    }

    private static func outputDirectory(for input: URL, settings: SettingsSnapshot) throws -> URL {
        let outputDir: URL
        if settings.saveLocation == .folder, let path = settings.outputFolderPath {
            outputDir = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            outputDir = input.deletingLastPathComponent()
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        return outputDir
    }

    private static func appendMagickResizeArgs(_ args: inout [String], settings: SettingsSnapshot) {
        let size = max(64, settings.resizeSize)
        switch settings.resizeMode {
        case .original: break
        case .maxLongEdge, .fitWithin: args += ["-resize", "\(size)x\(size)>"]
        case .maxWidth: args += ["-resize", "\(size)x>"]
        case .maxHeight: args += ["-resize", "x\(size)>"]
        }
    }

    private static func finalizeDerivative(
        temp: URL,
        input: URL,
        targetFormat: ImageFormat,
        settings: SettingsSnapshot,
        outputDir: URL
    ) throws -> URL {
        let fm = FileManager.default
        let stem = input.deletingPathExtension().lastPathComponent
        let prefix = settings.prefix
        let suffix = settings.suffix.isEmpty ? "_converted" : settings.suffix
        var candidate = outputDir.appendingPathComponent("\(prefix)\(stem)\(suffix).\(targetFormat.fileExtension)")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = outputDir.appendingPathComponent("\(prefix)\(stem)\(suffix)_\(n).\(targetFormat.fileExtension)")
            n += 1
        }
        try fm.moveItem(at: temp, to: candidate)
        if settings.preserveModificationDate,
           let values = try? input.resourceValues(forKeys: [.contentModificationDateKey]),
           let date = values.contentModificationDate {
            try? fm.setAttributes([.modificationDate: date], ofItemAtPath: candidate.path)
        }
        return candidate
    }

    private static func unchangedResult(
        input: URL,
        originalBytes: Int64,
        format: ImageFormat,
        settings: SettingsSnapshot,
        outputDir: URL,
        temp: URL
    ) throws -> CompressionResult {
        // Never replace an original with a larger result. If the user asked to
        // keep originals, still create a predictable output file by copying the
        // source byte-for-byte. This makes batch workflows complete consistently.
        guard settings.keepOriginals else {
            return .init(outcome: .dry)
        }
        let fm = FileManager.default
        try? fm.removeItem(at: temp)
        try fm.copyItem(at: input, to: temp)
        let finalURL = try finalize(
            temp: temp,
            input: input,
            targetFormat: format,
            settings: settings,
            outputDir: outputDir
        )
        return .init(outcome: .done(
            output: finalURL,
            bytes: originalBytes,
            format: format
        ))
    }

    private struct PreparedStaticInput {
        let url: URL
        let format: ImageFormat
        let report: InspectionReport
        let temporaryFiles: [URL]
    }

    private static func prepareStaticInput(
        input: URL,
        format: ImageFormat,
        report: InspectionReport,
        settings: SettingsSnapshot
    ) throws -> PreparedStaticInput {
        let target = resizedDimensions(width: report.width, height: report.height, mode: settings.resizeMode, size: settings.resizeSize)
        let needsResize = target.width != report.width || target.height != report.height
        let needsColor = settings.optimizeColorForSharing
        guard needsResize || needsColor else {
            return PreparedStaticInput(url: input, format: format, report: report, temporaryFiles: [])
        }

        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("IMGLESS-prepared-\(UUID().uuidString).png")
        var temps: [URL] = [temp]

        if format == .jpeg || format == .png {
            var args: [String] = ["-s", "format", "png"]
            if needsResize { args += ["-z", String(target.height), String(target.width)] }
            if needsColor {
                let profiles = [
                    "/System/Library/ColorSync/Profiles/sRGB Profile.icc",
                    "/System/Library/ColorSync/Profiles/sRGB.icc"
                ]
                if let profile = profiles.first(where: { fm.fileExists(atPath: $0) }) {
                    args += ["--matchTo", profile]
                }
            }
            args += [input.path, "--out", temp.path]
            try ProcessRunner.runVoid(URL(fileURLWithPath: "/usr/bin/sips"), args)
        } else if format == .webp {
            guard let dwebp = Toolchain.locate("dwebp") else {
                throw CompressionError.message("dwebp is missing.")
            }
            let decoded = fm.temporaryDirectory.appendingPathComponent("IMGLESS-prepared-webp-\(UUID().uuidString).png")
            temps.append(decoded)
            try ProcessRunner.runVoid(dwebp, [input.path, "-o", decoded.path])
            var args: [String] = ["-s", "format", "png"]
            if needsResize { args += ["-z", String(target.height), String(target.width)] }
            if needsColor {
                let profile = "/System/Library/ColorSync/Profiles/sRGB Profile.icc"
                if fm.fileExists(atPath: profile) { args += ["--matchTo", profile] }
            }
            args += [decoded.path, "--out", temp.path]
            try ProcessRunner.runVoid(URL(fileURLWithPath: "/usr/bin/sips"), args)
        } else {
            guard let magick = Toolchain.locate("magick") else {
                throw CompressionError.message("This resize needs the format extension to be installed.")
            }
            var args = [input.path, "-auto-orient"]
            if needsResize { args += ["-resize", "\(target.width)x\(target.height)!"] }
            if needsColor { args += ["-colorspace", "sRGB"] }
            if !settings.preserveColorProfile { args += ["+profile", "icc"] }
            args += ["png:\(temp.path)"]
            try ProcessRunner.runVoid(magick, args)
        }

        let preparedReport = try Inspector.inspect(url: temp, expectedFormat: .png)
        return PreparedStaticInput(url: temp, format: .png, report: preparedReport, temporaryFiles: temps)
    }

    private static func resizedDimensions(width: Int, height: Int, mode: ResizeMode, size: Int) -> (width: Int, height: Int) {
        guard width > 0, height > 0, size > 0 else { return (width, height) }
        let w = Double(width)
        let h = Double(height)
        let limit = Double(size)
        let scale: Double
        switch mode {
        case .original:
            return (width, height)
        case .maxLongEdge, .fitWithin:
            scale = min(1.0, limit / max(w, h))
        case .maxWidth:
            scale = min(1.0, limit / w)
        case .maxHeight:
            scale = min(1.0, limit / h)
        }
        return (max(1, Int((w * scale).rounded())), max(1, Int((h * scale).rounded())))
    }

    private static func resolveTargetFormat(input: ImageFormat, choice: OutputChoice) -> ImageFormat {
        if input == .pdf { return .pdf }
        switch choice {
        case .keepOriginal: return input
        case .jpeg: return .jpeg
        case .png: return .png
        case .webp: return .webp
        case .heic: return .heic
        case .avif: return .avif
        case .tiff: return .tiff
        }
    }

    private static func clean(
        input: URL,
        inputFormat: ImageFormat,
        before: InspectionReport,
        output: URL,
        targetFormat: ImageFormat,
        settings: SettingsSnapshot,
        metadataMode: MetadataMode
    ) throws {
        switch targetFormat {
        case .jpeg:
            try encodeJPEG(
                input: input,
                inputFormat: inputFormat,
                before: before,
                output: output,
                settings: settings,
                metadataMode: metadataMode
            )
        case .png:
            if before.frameCount > 1 {
                try encodeGeneric(
                    input: input, output: output, targetFormat: .png,
                    settings: settings, metadataMode: metadataMode, animated: true
                )
            } else {
                try encodePNG(
                    input: input, inputFormat: inputFormat,
                    output: output, settings: settings, metadataMode: metadataMode
                )
            }
        case .webp:
            if before.frameCount > 1 {
                try encodeGeneric(
                    input: input, output: output, targetFormat: .webp,
                    settings: settings, metadataMode: metadataMode, animated: true
                )
            } else {
                try encodeWebP(
                    input: input, inputFormat: inputFormat,
                    output: output, settings: settings, metadataMode: metadataMode
                )
            }
        case .heic, .avif, .tiff:
            try encodeGeneric(
                input: input, output: output, targetFormat: targetFormat,
                settings: settings, metadataMode: metadataMode, animated: false
            )
        case .raw, .bmp, .tga, .pcx, .pict, .ppm, .pgm, .pbm, .xbm, .xpm, .sgi, .sun, .gif, .apng, .animatedWebP, .pdf, .unknown:
            throw CompressionError.message("Unsupported output format in the static image pipeline.")
        }
    }

    private static func encodeJPEG(
        input: URL,
        inputFormat: ImageFormat,
        before: InspectionReport,
        output: URL,
        settings: SettingsSnapshot,
        metadataMode: MetadataMode
    ) throws {
        let source: URL
        var temporaryFiles: [URL] = []

        if inputFormat == .jpeg && !(metadataMode == .removeAll && (before.orientation ?? 1) != 1) {
            source = input
        } else {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-jpeg-source-\(UUID().uuidString).jpg")
            temporaryFiles += try makeRasterSource(
                input: input,
                inputFormat: inputFormat,
                output: tmp,
                target: .jpeg,
                metadataMode: metadataMode
            )
            source = tmp
        }
        defer { temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }

        if !settings.allowLossyOptimization && settings.output == .keepOriginal && settings.resizeMode == .original {
            try FileManager.default.copyItem(at: source, to: output)
            return
        }

        if settings.useHighQualityJPEG,
           CapabilityResolver.highQualityJPEGAvailable,
           let cjpegli = Toolchain.locate("cjpegli") {
            let jpegliQuality: String
            jpegliQuality = jpegQualityValue(settings, automaticHigh: 94, automaticBalanced: 86, automaticSmall: 76)
            try ProcessRunner.runVoid(cjpegli, [source.path, output.path, "-q", jpegliQuality, "--quiet"])
            if settings.jpegProgressive { try makeJPEGProgressive(at: output) }
            return
        }

        guard let recompress = Toolchain.locate("jpeg-recompress") else {
            throw CompressionError.message("jpeg-recompress is missing.")
        }
        var args = ["--accurate", "--method", "ssim", "--quiet"]
        switch settings.jpegQuality {
        case .high: args += ["--quality", "high", "--min", "68"]
        case .medium: args += ["--quality", "medium", "--min", "55"]
        case .low: args += ["--quality", "low", "--min", "42"]
        case .automatic:
            switch settings.mode {
            case .recommended: args += ["--quality", "medium", "--min", "55"]
            case .smaller: args += ["--quality", "low", "--min", "42"]
            case .bestQuality: args += ["--quality", "high", "--min", "68"]
            }
        }
        args += [source.path, output.path]
        try ProcessRunner.runVoid(recompress, args)
        if settings.jpegProgressive { try makeJPEGProgressive(at: output) }
    }

    private static func encodePNG(
        input: URL,
        inputFormat: ImageFormat,
        output: URL,
        settings: SettingsSnapshot,
        metadataMode: MetadataMode
    ) throws {
        guard let pngquant = Toolchain.locate("pngquant"),
              let oxipng = Toolchain.locate("oxipng") else {
            throw CompressionError.message("PNG tools are missing.")
        }

        let source: URL
        var temporaryFiles: [URL] = []
        if inputFormat == .png && metadataMode == .keep {
            source = input
        } else {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-png-source-\(UUID().uuidString).png")
            temporaryFiles += try makeRasterSource(
                input: input,
                inputFormat: inputFormat,
                output: tmp,
                target: .png,
                metadataMode: metadataMode
            )
            source = tmp
        }
        defer { temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }

        let qualityRange: String
        switch settings.mode {
        case .recommended: qualityRange = "65-86"
        case .smaller: qualityRange = "50-76"
        case .bestQuality: qualityRange = "80-95"
        }

        if settings.allowLossyOptimization && settings.pngLossyOptimization {
            let quantized = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-pngquant-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: quantized) }

            let quantResult = try ProcessRunner.runWithStatus(pngquant, [
                "--force", "--skip-if-larger", "--quality", qualityRange,
                "--speed", "1", "--output", quantized.path, source.path
            ])
            if quantResult.status == 0, FileManager.default.fileExists(atPath: quantized.path) {
                try FileManager.default.copyItem(at: quantized, to: output)
            } else {
                try FileManager.default.copyItem(at: source, to: output)
            }
        } else {
            try FileManager.default.copyItem(at: source, to: output)
        }

        try ProcessRunner.runVoid(oxipng, ["-o", "4", "--strip", "safe", output.path])
    }

    private static func encodeWebP(
        input: URL,
        inputFormat: ImageFormat,
        output: URL,
        settings: SettingsSnapshot,
        metadataMode: MetadataMode
    ) throws {
        guard let cwebp = Toolchain.locate("cwebp") else {
            throw CompressionError.message("cwebp is missing.")
        }

        let source: URL
        var temporaryFiles: [URL] = []
        if inputFormat == .jpeg || inputFormat == .png || inputFormat == .webp || inputFormat == .tiff {
            source = input
        } else {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-webp-source-\(UUID().uuidString).png")
            temporaryFiles += try makeRasterSource(
                input: input,
                inputFormat: inputFormat,
                output: tmp,
                target: .png,
                metadataMode: metadataMode
            )
            source = tmp
        }
        defer { temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }

        let psnr: String
        switch settings.mode {
        case .recommended: psnr = "41"
        case .smaller: psnr = "38"
        case .bestQuality: psnr = "45"
        }
        let metadata = metadataMode == .removeAll ? "none" : "all"
        if !settings.allowLossyOptimization || !settings.webpLossy {
            try ProcessRunner.runVoid(cwebp, [
                "-lossless", "-m", "6", "-mt", "-metadata", metadata,
                source.path, "-o", output.path
            ])
        } else {
            let q = webPQualityValue(settings)
            try ProcessRunner.runVoid(cwebp, [
                "-preset", "picture", "-m", "6", "-mt", "-sharp_yuv", "-af",
                "-alpha_q", "100", "-q", q, "-psnr", psnr, "-pass", "10", "-metadata", metadata,
                source.path, "-o", output.path
            ])
        }
    }

    private static func encodeGeneric(
        input: URL,
        output: URL,
        targetFormat: ImageFormat,
        settings: SettingsSnapshot,
        metadataMode: MetadataMode,
        animated: Bool
    ) throws {
        guard let magick = Toolchain.locate("magick") else {
            throw CompressionError.message("This format needs an IMGLESS format extension.")
        }

        var args = [input.path]
        if metadataMode == .removeAll { args += ["-auto-orient", "-strip"] }

        switch targetFormat {
        case .heic:
            args += ["-quality", quality(settings.mode, high: 92, balanced: 82, small: 72)]
        case .avif:
            args += ["-quality", quality(settings.mode, high: 88, balanced: 76, small: 64)]
        case .tiff:
            if settings.mode == .bestQuality {
                args += ["-compress", "Zip"]
            } else {
                args += ["-compress", "JPEG", "-quality", quality(settings.mode, high: 94, balanced: 88, small: 80)]
            }
        case .webp:
            args += ["-quality", quality(settings.mode, high: 92, balanced: 82, small: 72), "-define", "webp:method=6"]
        case .png:
            args += ["-define", "png:compression-level=9", "-define", "png:compression-filter=5"]
        case .jpeg:
            args += ["-background", "white", "-alpha", "remove", "-alpha", "off",
                     "-quality", quality(settings.mode, high: 94, balanced: 88, small: 80)]
        case .raw, .bmp, .tga, .pcx, .pict, .ppm, .pgm, .pbm, .xbm, .xpm, .sgi, .sun, .gif, .apng, .animatedWebP, .pdf, .unknown:
            throw CompressionError.message("Unsupported format in the static image encoder.")
        }

        args += [output.path]
        try ProcessRunner.runVoid(magick, args)
    }

    // Creates a JPEG/PNG source without requiring ImageMagick for the three core formats.
    // Extra formats use ImageMagick supplied by their extension.
    private static func makeRasterSource(
        input: URL,
        inputFormat: ImageFormat,
        output: URL,
        target: ImageFormat,
        metadataMode: MetadataMode
    ) throws -> [URL] {
        var temporaryFiles: [URL] = [output]
        let shouldAutoOrient = metadataMode == .removeAll

        if let magick = Toolchain.locate("magick"),
           inputFormat != .jpeg && inputFormat != .png && inputFormat != .webp {
            var args = [input.path]
            if shouldAutoOrient { args += ["-auto-orient", "-strip"] }
            if target == .jpeg {
                args += ["-background", "white", "-alpha", "remove", "-alpha", "off", "-quality", "100"]
            }
            args += [output.path]
            try ProcessRunner.runVoid(magick, args)
            return temporaryFiles
        }

        if shouldAutoOrient, let magick = Toolchain.locate("magick") {
            var args = [input.path, "-auto-orient", "-strip"]
            if target == .jpeg {
                args += ["-background", "white", "-alpha", "remove", "-alpha", "off", "-quality", "100"]
            }
            args += [output.path]
            try ProcessRunner.runVoid(magick, args)
            return temporaryFiles
        }

        if inputFormat == .webp {
            guard let dwebp = Toolchain.locate("dwebp") else {
                throw CompressionError.message("dwebp is missing.")
            }
            let png = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMGLESS-webp-decode-\(UUID().uuidString).png")
            temporaryFiles.append(png)
            try ProcessRunner.runVoid(dwebp, [input.path, "-o", png.path])
            if target == .png {
                try FileManager.default.copyItem(at: png, to: output)
            } else {
                try sipsConvert(input: png, output: output, format: "jpeg")
            }
            return temporaryFiles
        }

        switch target {
        case .jpeg:
            try sipsConvert(input: input, output: output, format: "jpeg")
        case .png:
            try sipsConvert(input: input, output: output, format: "png")
        default:
            throw CompressionError.message("IMGLESS could not prepare this image for the selected encoder.")
        }
        return temporaryFiles
    }

    private static func sipsConvert(input: URL, output: URL, format: String) throws {
        let sips = URL(fileURLWithPath: "/usr/bin/sips")
        try ProcessRunner.runVoid(sips, [
            "-s", "format", format,
            input.path,
            "--out", output.path
        ])
    }

    private static func jpegQualityValue(_ settings: SettingsSnapshot, automaticHigh: Int, automaticBalanced: Int, automaticSmall: Int) -> String {
        switch settings.jpegQuality {
        case .high: return "94"
        case .medium: return "86"
        case .low: return "76"
        case .automatic:
            return quality(settings.mode, high: automaticHigh, balanced: automaticBalanced, small: automaticSmall)
        }
    }

    private static func webPQualityValue(_ settings: SettingsSnapshot) -> String {
        switch settings.webpQuality {
        case .high: return "92"
        case .medium: return "82"
        case .low: return "70"
        case .automatic: return quality(settings.mode, high: 92, balanced: 82, small: 70)
        }
    }

    private static func makeJPEGProgressive(at url: URL) throws {
        guard let jpegtran = Toolchain.locate("jpegtran") else { return }
        let temp = url.deletingLastPathComponent().appendingPathComponent(".imgless-progressive-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: temp) }
        let result = try ProcessRunner.runWithStatus(jpegtran, ["-copy", "all", "-optimize", "-progressive", "-outfile", temp.path, url.path])
        guard result.status == 0, FileManager.default.fileExists(atPath: temp.path) else { return }
        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }

    private static func quality(_ mode: CompressionMode, high: Int, balanced: Int, small: Int) -> String {
        switch mode {
        case .bestQuality: return String(high)
        case .recommended: return String(balanced)
        case .smaller: return String(small)
        }
    }

    private static func sanitizeMetadata(at url: URL) throws {
        guard CapabilityResolver.metadataCleanerAvailable,
              let exiftool = Toolchain.locate("exiftool") else { return }
        try ProcessRunner.runVoid(exiftool, ["-overwrite_original", "-all=", url.path])
    }

    private static func finalize(
        temp: URL,
        input: URL,
        targetFormat: ImageFormat,
        settings: SettingsSnapshot,
        outputDir: URL
    ) throws -> URL {
        let fm = FileManager.default
        let inputExt = input.pathExtension.lowercased()
        let stem = input.pathExtension.isEmpty ? input.lastPathComponent : input.deletingPathExtension().lastPathComponent
        let originalDate = try? input.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        func preserveDateIfNeeded(_ url: URL) {
            guard settings.preserveModificationDate, let originalDate else { return }
            try? fm.setAttributes([.modificationDate: originalDate], ofItemAtPath: url.path)
        }

        if settings.keepOriginals {
            let prefix = settings.prefix
            let suffix = settings.suffix.isEmpty ? "_compressed" : settings.suffix
            var candidate = outputDir.appendingPathComponent("\(prefix)\(stem)\(suffix).\(targetFormat.fileExtension)")
            var number = 2
            while fm.fileExists(atPath: candidate.path) {
                candidate = outputDir.appendingPathComponent("\(prefix)\(stem)\(suffix)_\(number).\(targetFormat.fileExtension)")
                number += 1
            }
            try fm.moveItem(at: temp, to: candidate)
            preserveDateIfNeeded(candidate)
            return candidate
        }

        let samePathExtension = !inputExt.isEmpty && inputExt == targetFormat.fileExtension.lowercased()
        if samePathExtension {
            _ = try fm.replaceItemAt(input, withItemAt: temp)
            preserveDateIfNeeded(input)
            return input
        }

        var replacement = input.deletingLastPathComponent()
            .appendingPathComponent("\(stem).\(targetFormat.fileExtension)")
        if replacement != input && fm.fileExists(atPath: replacement.path) {
            var number = 2
            repeat {
                replacement = input.deletingLastPathComponent()
                    .appendingPathComponent("\(stem)_\(number).\(targetFormat.fileExtension)")
                number += 1
            } while fm.fileExists(atPath: replacement.path)
        }
        try fm.moveItem(at: temp, to: replacement)
        try fm.removeItem(at: input)
        preserveDateIfNeeded(replacement)
        return replacement
    }
}

enum Toolchain {
    static func locate(_ name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/Library/Application Support/IMGLESS/bin/\(name)",
            "\(home)/Library/Application Support/IMGLESS/Extensions/high-quality-jpeg/build/tools/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)"
        ]
        for path in paths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}

enum ProcessRunner {
    struct StatusResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    static func runWithStatus(_ executable: URL, _ arguments: [String]) throws -> StatusResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                throw CompressionError.message("Cancelled")
            }
            Thread.sleep(forTimeInterval: 0.04)
        }
        let out = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return StatusResult(status: process.terminationStatus, stdout: out, stderr: err)
    }

    @discardableResult
    static func run(_ executable: URL, _ arguments: [String]) throws -> String {
        let result = try runWithStatus(executable, arguments)
        if result.status != 0 {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CompressionError.message(message.isEmpty ? "A compression engine exited with code \(result.status)." : message)
        }
        return result.stdout
    }

    static func runVoid(_ executable: URL, _ arguments: [String]) throws {
        _ = try run(executable, arguments)
    }
}

enum CompressionError: Error {
    case message(String)
    var description: String {
        switch self { case .message(let message): return message }
    }
}

// MARK: - Native window material

struct NativeMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .underWindowBackground
        nsView.blendingMode = .behindWindow
        nsView.state = .followsWindowActiveState
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.title = "IMGLESS"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}

extension View {
    @ViewBuilder
    func imglessGlassPanel(cornerRadius: CGFloat = 18) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
#else
        self.background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
#endif
    }
}

// MARK: - Lazy thumbnail cache

private struct ThumbnailPayload: @unchecked Sendable {
    let image: NSImage
    let cost: Int
}

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 128
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func thumbnail(for url: URL) async -> NSImage? {
        let key = url.standardizedFileURL as NSURL
        if let cached = cache.object(forKey: key) { return cached }

        let payload = await Task.detached(priority: .utility) { () -> ThumbnailPayload? in
            if Task.isCancelled { return nil }
            if FileSniffer.detect(url: url) == .pdf, let doc = PDFDocument(url: url), let page = doc.page(at: 0) {
                let bounds = page.bounds(for: .mediaBox)
                let image = page.thumbnail(of: NSSize(width: 160, height: max(1, 160 * bounds.height / max(bounds.width, 1))), for: .mediaBox)
                return ThumbnailPayload(image: image, cost: max(1, Int(image.size.width * image.size.height * 4)))
            }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [
                kCGImageSourceShouldCache: false
            ] as CFDictionary) else { return nil }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 160,
                kCGImageSourceShouldCacheImmediately: false
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            return ThumbnailPayload(image: image, cost: max(1, cg.width * cg.height * 4))
        }.value

        guard !Task.isCancelled, let payload else { return nil }
        cache.setObject(payload.image, forKey: key, cost: payload.cost)
        return payload.image
    }
}

struct LazyThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            image = await ThumbnailCache.shared.thumbnail(for: url)
        }
        .onDisappear { image = nil }
    }
}

// MARK: - Views

struct ContentView: View {
    @ObservedObject var model: CompressionModel
    @ObservedObject var extensionManager: ExtensionManager
    @ObservedObject var stats: StatisticsStore

    private var settingsOpen: Bool { model.screen == .settings }
    private var batchDrawerVisible: Bool {
        model.isPreflightingPDF || model.isProcessing || model.pdfEstimateVisible || model.resultDrawerVisible
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NativeMaterialBackground()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if model.items.isEmpty {
                            IdleView(model: model)
                        } else {
                            CompressingView(
                                model: model,
                                bottomInset: batchDrawerVisible ? 116 : 18
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !settingsOpen {
                        Button {
                            model.screen = .settings
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11.5, weight: .medium))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Settings")
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                        .disabled(model.isProcessing || model.isPreflightingPDF)
                        .opacity((model.isProcessing || model.isPreflightingPDF) ? 0.35 : 1)
                    }
                }

                if settingsOpen {
                    SettingsDrawer(
                        settings: model.settings,
                        extensionManager: extensionManager,
                        stats: stats
                    ) {
                        model.screen = .main
                    }
                    .frame(width: 320)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if batchDrawerVisible {
                BatchDrawer(model: model)
                    .padding(.leading, 12)
                    .padding(.trailing, settingsOpen ? 332 : 12)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.screen)
        .animation(.easeInOut(duration: 0.18), value: batchDrawerVisible)
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $model.isDropTargeted
        ) { providers in
            model.acceptDrop(providers: providers)
        }
        .alert("IMGLESS", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("OK") { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
        .alert("Replace original files?", isPresented: $model.showReplaceConfirmation) {
            Button("Cancel", role: .cancel) { model.clearAll() }
            Button("Replace Originals", role: .destructive) { model.startProcessing() }
        } message: {
            Text("IMGLESS replaces an original only after inspect, clean and verify succeed.")
        }
        .sheet(isPresented: Binding(
            get: { model.pdfReviewItemID != nil },
            set: { if !$0 { model.finishPDFSimilarReview() } }
        )) {
            if let itemID = model.pdfReviewItemID {
                PDFDuplicateReviewView(model: model, itemID: itemID)
            }
        }
    }
}

struct PDFDuplicateReviewView: View {
    @ObservedObject var model: CompressionModel
    let itemID: UUID

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Similar pages")
                    .font(.system(size: 16, weight: .medium))
                Text(fileName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(pairs) { pair in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Page \(pair.firstPage + 1) ↔ Page \(pair.secondPage + 1)")
                                    .font(.system(size: 11.5))
                                Text("\(Int((pair.similarity * 100).rounded()))% visually similar")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Remove page \(pair.secondPage + 1)", isOn: Binding(
                                get: { model.isSimilarPageSelected(itemID: itemID, pageIndex: pair.secondPage) },
                                set: { model.setSimilarPageSelected(itemID: itemID, pageIndex: pair.secondPage, selected: $0) }
                            ))
                            .labelsHidden()
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 16)
                    }
                }
            }

            Button("Done") { model.finishPDFSimilarReview() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .frame(width: 360, height: min(520, CGFloat(160 + pairs.count * 54)))
    }

    private var item: CompressionItem? { model.items.first(where: { $0.id == itemID }) }
    private var pairs: [PDFSimilarPair] { item?.pdfSimilarPairs ?? [] }
    private var fileName: String { item?.url.lastPathComponent ?? "PDF" }
}

struct IdleView: View {
    @ObservedObject var model: CompressionModel

    private var hasFileExtensions: Bool {
        ExtensionRegistry.isInstalled(.pdfTools) || ExtensionRegistry.isInstalled(.photography) ||
        ExtensionRegistry.isInstalled(.animation) || ExtensionRegistry.isInstalled(.legacyFormats) ||
        ExtensionRegistry.isInstalled(.applePhotos)
    }

    private var supportedFormats: String {
        var values = ["JPEG", "PNG", "WebP"]
        if ExtensionRegistry.isInstalled(.applePhotos) { values.append("HEIC") }
        if ExtensionRegistry.isInstalled(.photography) { values += ["TIFF", "RAW"] }
        if ExtensionRegistry.isInstalled(.animation) { values += ["GIF", "APNG"] }
        if ExtensionRegistry.isInstalled(.pdfTools) { values.append("PDF") }
        if ExtensionRegistry.isInstalled(.legacyFormats) { values.append("Legacy") }
        return values.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.pickFiles()
            } label: {
                VStack(spacing: 7) {
                    Spacer()
                    Text(model.isDropTargeted ? "Drop" : (hasFileExtensions ? "Drop files" : "Drop images"))
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.primary)
                    Text(supportedFormats)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Color.clear
                .frame(height: 14)
        }
    }
}

struct BatchDrawer: View {
    @ObservedObject var model: CompressionModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.2, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9.8).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                actionArea
            }

            if let progress = progressValue {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .imglessGlassPanel(cornerRadius: 16)
    }

    private var title: String {
        if model.isPreflightingPDF {
            return "Analyzing \(model.pdfPreflightCompletedCount) of \(model.pdfPreflightTotalCount)"
        }
        if model.isProcessing {
            return model.isCancelling
                ? "Cancelling…"
                : "Processing \(model.batchProgress.completed) of \(model.batchProgress.total)"
        }
        if model.pdfEstimateVisible {
            return model.estimatedPDFCount == 1 ? "PDF ready" : "\(model.estimatedPDFCount) PDFs ready"
        }
        return "Saved \(formatBytes(model.totalSavedBytes))"
    }

    private var subtitle: String {
        if model.isPreflightingPDF {
            let left = max(0, model.pdfPreflightTotalCount - model.pdfPreflightCompletedCount)
            return "\(model.pdfPreflightPercent)% · \(left) left"
        }
        if model.isProcessing {
            let left = max(0, model.batchProgress.total - model.batchProgress.completed)
            return "\(model.batchProgress.percent)% · \(left) left"
        }
        if model.pdfEstimateVisible {
            let original = formatBytes(model.totalOriginalPDFBytes)
            let estimated = formatBytes(model.totalEstimatedPDFBytes)
            let percent = model.totalOriginalPDFBytes > 0
                ? Int(((Double(model.totalOriginalPDFBytes - model.totalEstimatedPDFBytes) / Double(model.totalOriginalPDFBytes)) * 100).rounded())
                : 0
            var parts = ["\(original) → ~\(estimated)", "about \(max(0, percent))% smaller"]
            if model.pdfExactDuplicateCount > 0 {
                parts.append("\(model.pdfExactDuplicateCount) duplicates")
            }
            if model.pdfSimilarPairCount > 0 {
                parts.append("\(model.pdfSimilarPairCount) similar")
            }
            return parts.joined(separator: " · ")
        }

        var parts: [String] = []
        if model.optimizedCount > 0 { parts.append("\(model.optimizedCount) optimized") }
        if model.unchangedCount > 0 { parts.append("\(model.unchangedCount) unchanged") }
        if model.failedCount > 0 { parts.append("\(model.failedCount) failed") }
        if model.batchProgress.cancelled > 0 { parts.append("\(model.batchProgress.cancelled) cancelled") }
        if model.totalSavingsPercent > 0 { parts.append("\(model.totalSavingsPercent)% smaller overall") }
        return parts.isEmpty ? "No files changed" : parts.joined(separator: " · ")
    }

    private var progressValue: Double? {
        if model.isPreflightingPDF { return model.pdfPreflightFraction }
        if model.isProcessing { return model.batchProgress.fraction }
        return nil
    }

    @ViewBuilder
    private var actionArea: some View {
        if model.isPreflightingPDF {
            Button("Skip estimate") {
                model.skipPDFEstimate()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)

        } else if model.isProcessing {
            Button(model.isCancelling ? "Cancelling…" : "Cancel") {
                model.cancelBatch()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .disabled(model.isCancelling)

        } else if model.pdfEstimateVisible {
            HStack(spacing: 10) {
                if model.hasPDFSimilarPairs {
                    Button("Review") { model.beginPDFSimilarReview() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Button(model.estimatedPDFCount > 1 ? "Compress all" : "Compress") {
                    model.startEstimatedBatch()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

        } else {
            HStack(spacing: 10) {
                Button("Show in Finder") {
                    model.revealResults()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .disabled(model.optimizedCount == 0 && model.unchangedCount == 0)

                Button("Done") {
                    model.dismissResult()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

struct CompressingView: View {
    @ObservedObject var model: CompressionModel
    let bottomInset: CGFloat

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(model.items) { item in
                    CompressionRow(item: item)
                        .id(item.id)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, bottomInset)
        }
    }
}

struct CompressionRow: View {
    let item: CompressionItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            LazyThumbnail(url: item.url)
                .frame(width: 58, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 12.2, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(detailText)
                    .font(.system(size: 10.3))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if case .squeezing = item.state {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else if case .done = item.state, item.differencePercent > 0 {
                Text("−\(item.differencePercent)%")
                    .font(.system(size: 10.3).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .help(errorMessage ?? "")
    }

    private var detailText: String {
        switch item.state {
        case .done:
            if let output = item.outputBytes {
                if output == item.originalBytes {
                    return "No savings · copy saved"
                }
                return "\(formatBytes(item.originalBytes)) → \(formatBytes(output))"
            }
            return formatBytes(item.originalBytes)
        case .dry:
            return "Already optimal"
        case .failed(let message):
            let firstLine = message
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return "Failed · \(firstLine)"
        case .cancelled:
            return "Cancelled"
        case .analyzing:
            return item.format == .pdf ? "Analyzing PDF…" : formatBytes(item.originalBytes)
        case .squeezing:
            return "Processing · \(formatBytes(item.originalBytes))"
        case .queued:
            if item.format == .pdf, let estimate = item.estimatedBytes {
                var detail = "\(formatBytes(item.originalBytes)) → ~\(formatBytes(estimate))"
                if !item.pdfExactDuplicatePages.isEmpty {
                    detail += " · \(item.pdfExactDuplicatePages.count) duplicates"
                }
                if !item.pdfSimilarPairs.isEmpty {
                    detail += " · \(item.pdfSimilarPairs.count) similar"
                }
                return detail
            }
            return "Waiting · \(formatBytes(item.originalBytes))"
        }
    }

    private var errorMessage: String? {
        if case .failed(let message) = item.state { return message }
        return nil
    }
}

struct SettingGridRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GridRow {
            Text(title)
                .font(.system(size: 11.8))
                .frame(width: 94, alignment: .leading)
            content
                .frame(width: 138, alignment: .trailing)
        }
        .frame(minHeight: 28)
    }
}

struct SettingsDrawer: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var extensionManager: ExtensionManager
    @ObservedObject var stats: StatisticsStore
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 13.5, weight: .medium))
                Spacer()
                Button("Done") { done() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.8, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection(title: "GENERAL") {
                        generalGrid
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    settingsSection(title: "IMAGE SIZE") {
                        imageSizeGrid
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    settingsSection(title: "IMAGE OPTIMIZATION") {
                        imageOptimizationGrid
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    settingsSection(title: "FILES") {
                        filesGrid
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }

                    if settings.output == .jpeg {
                        settingsSection(title: "JPEG") {
                            jpegGrid.padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    } else if settings.output == .webp {
                        settingsSection(title: "WEBP") {
                            webpGrid.padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    } else if settings.output == .png {
                        settingsSection(title: "PNG") {
                            pngGrid.padding(.horizontal, 14).padding(.vertical, 10)
                        }
                    }

                    if !availableExtensions.isEmpty {
                        settingsSection(title: "EXTENSIONS") {
                            VStack(spacing: 0) {
                                ForEach(Array(availableExtensions.enumerated()), id: \.element.id) { index, id in
                                    ExtensionInstallRow(id: id, manager: extensionManager)
                                    if index < availableExtensions.count - 1 {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            }
                        }
                    }

                    ForEach(installedExtensions) { id in
                        settingsSection(title: id.title.uppercased()) {
                            InstalledExtensionSettings(
                                id: id,
                                manager: extensionManager,
                                settings: settings
                            )
                        }
                    }

                    settingsSection(title: "STATISTICS") {
                        statisticsBlock
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }


        }
        .background(.regularMaterial)
        .overlay(alignment: .leading) {
            Divider()
        }
        .onAppear {
            extensionManager.refreshAll()
            coerceSettingsToInstalledCapabilities()
        }
        .onReceive(extensionManager.$states) { _ in
            coerceSettingsToInstalledCapabilities()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9.6, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)

            content()
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.045), lineWidth: 0.5)
                }
        }
    }

    private var generalGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Compression") {
                Picker("Compression", selection: $settings.compressionMode) {
                    ForEach(CompressionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
            }

            SettingGridRow(title: "Format") {
                Picker("Format", selection: $settings.output) {
                    ForEach(availableOutputs) { format in
                        Text(format.title).tag(format)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var imageSizeGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Resize") {
                Picker("Resize", selection: $settings.resizeMode) {
                    ForEach(ResizeMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .labelsHidden()
            }
            if settings.resizeMode != .original {
                SettingGridRow(title: "Size") {
                    HStack(spacing: 5) {
                        TextField("2500", text: Binding(
                            get: { String(settings.resizeSize) },
                            set: { value in
                                if let number = Int(value) { settings.resizeSize = max(64, number) }
                            }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 78)
                        Text("px").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var imageOptimizationGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Lossy optimization") {
                Toggle("", isOn: $settings.allowLossyOptimization).labelsHidden()
            }
            SettingGridRow(title: "Color for sharing") {
                Toggle("", isOn: $settings.optimizeColorForSharing).labelsHidden()
            }
            SettingGridRow(title: "Preserve profile") {
                Toggle("", isOn: $settings.preserveColorProfile).labelsHidden()
            }
        }
    }

    private var filesGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Location") {
                Menu(locationLabel) {
                    Button("Original folder") { settings.saveLocation = .nextToOriginal }
                    Button("Choose folder…") { settings.chooseOutputFolder() }
                }
                .menuStyle(.borderlessButton)
            }
            SettingGridRow(title: "Keep original") {
                Toggle("", isOn: $settings.keepOriginals).labelsHidden()
            }
            SettingGridRow(title: "Prefix") {
                TextField("", text: $settings.prefix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .disabled(!settings.keepOriginals)
                    .opacity(settings.keepOriginals ? 1 : 0.45)
            }
            SettingGridRow(title: "Suffix") {
                TextField("_compressed", text: $settings.suffix)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .disabled(!settings.keepOriginals)
                    .opacity(settings.keepOriginals ? 1 : 0.45)
            }
            SettingGridRow(title: "Modification date") {
                Toggle("", isOn: $settings.preserveModificationDate).labelsHidden()
            }
        }
    }

    private var jpegGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Quality") {
                Picker("JPEG quality", selection: $settings.jpegQuality) {
                    ForEach(QualityPreset.allCases) { preset in Text(preset.title).tag(preset) }
                }.labelsHidden()
            }
            SettingGridRow(title: "Progressive") {
                Toggle("", isOn: $settings.jpegProgressive).labelsHidden()
            }
        }
    }

    private var webpGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Quality") {
                Picker("WebP quality", selection: $settings.webpQuality) {
                    ForEach(QualityPreset.allCases) { preset in Text(preset.title).tag(preset) }
                }.labelsHidden()
            }
            SettingGridRow(title: "Lossy") {
                Toggle("", isOn: $settings.webpLossy).labelsHidden()
            }
        }
    }

    private var pngGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            SettingGridRow(title: "Lossy optimization") {
                Toggle("", isOn: $settings.pngLossyOptimization).labelsHidden()
            }
        }
    }

    private var statisticsBlock: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Space saved")
                    .font(.system(size: 11.3))
                    .foregroundStyle(.secondary)
                    .frame(width: 94, alignment: .leading)
                Text(formatBytes(stats.totalBytesSaved))
                    .font(.system(size: 11.3).monospacedDigit())
                    .frame(width: 138, alignment: .trailing)
            }
            GridRow {
                Text("Files optimized")
                    .font(.system(size: 11.3))
                    .foregroundStyle(.secondary)
                    .frame(width: 94, alignment: .leading)
                Text("\(stats.totalFilesOptimized)")
                    .font(.system(size: 11.3).monospacedDigit())
                    .frame(width: 138, alignment: .trailing)
            }
            GridRow {
                Text("Since \(stats.installedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 9.8))
                    .foregroundStyle(.tertiary)
                    .frame(width: 94, alignment: .leading)
                Button("Reset") { stats.reset() }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.8))
                    .foregroundStyle(.secondary)
                    .frame(width: 138, alignment: .trailing)
            }
        }
    }

    private var availableExtensions: [ExtensionID] {
        ExtensionID.allCases.filter { !extensionManager.state(for: $0).isInstalled }
    }

    private var installedExtensions: [ExtensionID] {
        ExtensionID.allCases.filter { extensionManager.state(for: $0).isInstalled }
    }

    private var availableOutputs: [OutputChoice] {
        var values: [OutputChoice] = [.keepOriginal, .jpeg, .png, .webp]
        if ExtensionRegistry.isInstalled(.applePhotos) {
            values += [.heic, .avif]
        }
        if ExtensionRegistry.isInstalled(.photography) {
            values += [.tiff]
        }
        return values
    }

    private var locationLabel: String {
        if settings.saveLocation == .folder, let path = settings.outputFolderPath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "Original folder"
    }

    private var extensionStateSignature: String {
        ExtensionID.allCases.map { id in
            switch extensionManager.state(for: id) {
            case .notInstalled: return "\(id.rawValue):off"
            case .installing: return "\(id.rawValue):installing"
            case .installed(let version): return "\(id.rawValue):on:\(version)"
            case .removing: return "\(id.rawValue):removing"
            case .failed(let message): return "\(id.rawValue):failed:\(message)"
            }
        }.joined(separator: "|")
    }

    private func coerceSettingsToInstalledCapabilities() {
        if !availableOutputs.contains(settings.output) {
            settings.output = .keepOriginal
        }
        if !ExtensionRegistry.isInstalled(.metadataCleaner) {
            settings.metadataMode = .keep
        }
        if !ExtensionRegistry.isInstalled(.highQualityJPEG) {
            settings.useHighQualityJPEG = true
        }
        if !ExtensionRegistry.isInstalled(.aiProvenance) {
            settings.useAIProvenance = true
        }
    }
}

struct ExtensionInstallRow: View {
    let id: ExtensionID
    @ObservedObject var manager: ExtensionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(id.title)
                        .font(.system(size: 11.4))
                        .foregroundStyle(.primary)
                    Text(id.detail)
                        .font(.system(size: 9.3))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(actionTitle) {
                    manager.install(id)
                }
                .controlSize(.small)
                .disabled(manager.state(for: id).isBusy)
            }

            if case .failed(let message) = manager.state(for: id) {
                Text(message)
                    .font(.system(size: 9.1))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var actionTitle: String {
        switch manager.state(for: id) {
        case .installing: return "Installing…"
        case .removing: return "Removing…"
        case .failed: return "Retry"
        case .installed: return "Installed"
        case .notInstalled: return "Install"
        }
    }
}

struct InstalledExtensionSettings: View {
    let id: ExtensionID
    @ObservedObject var manager: ExtensionManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            switch id {
            case .highQualityJPEG:
                settingsRow("Use Google jpegli") {
                    Toggle("", isOn: $settings.useHighQualityJPEG)
                        .labelsHidden()
                        .controlSize(.small)
                }

            case .applePhotos:
                settingsRow("Formats") {
                    Text("HEIC · HEIF · AVIF")
                        .font(.system(size: 10.3))
                        .foregroundStyle(.secondary)
                }

            case .photography:
                settingsRow("Formats") {
                    Text("TIFF · DNG · RAW")
                        .font(.system(size: 10.3))
                        .foregroundStyle(.secondary)
                }
                settingsRow("RAW output") {
                    Picker("RAW output", selection: $settings.photographyRAWOutput) {
                        ForEach(PhotographyRAWOutput.allCases) { format in Text(format.title).tag(format) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
                settingsRow("Preserve 16-bit") {
                    Toggle("", isOn: $settings.photographyPreserve16Bit)
                        .labelsHidden()
                        .controlSize(.small)
                }

            case .animation:
                settingsRow("Frame rate") {
                    Picker("Frame rate", selection: $settings.animationFrameRate) {
                        ForEach(AnimationFrameRate.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
                settingsRow("Loop") {
                    Picker("Loop", selection: $settings.animationLoopMode) {
                        ForEach(AnimationLoopMode.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
                settingsRow("Resize") {
                    Picker("Animation resize", selection: $settings.animationResize) {
                        ForEach(AnimationResize.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
                settingsRow("Compression") {
                    Picker("Animation compression", selection: $settings.animationCompression) {
                        ForEach(AnimationCompression.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
                settingsRow("Output") {
                    Picker("Animation output", selection: $settings.animationOutput) {
                        ForEach(AnimationOutput.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }

            case .legacyFormats:
                settingsRow("Formats") {
                    Text("BMP · TGA · PCX · PICT · PNM · XBM · XPM · SGI")
                        .font(.system(size: 9.8))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                settingsRow("Preferred output") {
                    Picker("Legacy output", selection: $settings.legacyPreferredOutput) {
                        ForEach(LegacyPreferredOutput.allCases) { value in Text(value.title).tag(value) }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }

            case .metadataCleaner:
                settingsRow("Metadata") {
                    Picker("Metadata", selection: $settings.metadataMode) {
                        Text("Keep").tag(MetadataMode.keep)
                        Text("Remove").tag(MetadataMode.removeAll)
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }

            case .aiProvenance:
                settingsRow("Use extension") {
                    Toggle("", isOn: $settings.useAIProvenance)
                        .labelsHidden()
                        .controlSize(.small)
                }

            case .pdfTools:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Compression")
                        .font(.system(size: 11.3))
                    Picker("PDF compression", selection: $settings.pdfCompressionMode) {
                        ForEach(PDFCompressionMode.allCases) { mode in Text(mode.title).tag(mode) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(settings.pdfCompressionMode.detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    HStack {
                        Text("Duplicate pages").font(.system(size: 11.3))
                        Spacer()
                        Picker("Duplicate pages", selection: $settings.pdfDuplicateMode) {
                            ForEach(PDFDuplicateMode.allCases) { mode in Text(mode.title).tag(mode) }
                        }
                        .labelsHidden()
                        .frame(width: 126)
                    }

                    if settings.pdfDuplicateMode != .off {
                        HStack {
                            Text("Remove exact duplicates").font(.system(size: 11.3))
                            Spacer()
                            Toggle("", isOn: $settings.removeExactPDFDuplicates)
                                .labelsHidden()
                                .controlSize(.small)
                        }
                    }

                    if settings.pdfDuplicateMode == .reviewSimilar {
                        Text("Similar pages are only flagged for review. They are never removed automatically.")
                            .font(.system(size: 9.4))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().padding(.leading, 14)

            HStack {
                Text(versionLabel)
                    .font(.system(size: 9.4))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Remove extension") {
                    manager.remove(id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.8))
                .foregroundStyle(.secondary)
                .disabled(manager.state(for: id).isBusy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11.3))
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var versionLabel: String {
        switch manager.state(for: id) {
        case .installed(let version): return "Version \(version)"
        case .removing: return "Removing…"
        default: return id.detail
        }
    }
}

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
