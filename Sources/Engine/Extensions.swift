import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

// MARK: - Extensions / capabilities

enum ExtensionID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case imageProcessing = "image-processing"
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
        case .imageProcessing: return "Images"
        case .highQualityJPEG: return "High-Quality JPEG"
        case .applePhotos: return "Apple Photos"
        case .photography: return "Photography"
        case .animation: return "Animation"
        case .legacyFormats: return "Legacy Formats"
        case .metadataCleaner: return "Metadata Cleaner"
        case .aiProvenance: return "AI Provenance"
        case .pdfTools: return "PDF Tools"
        }
    }

    /// What the plugin does, in a few plain words.
    var detail: String {
        switch self {
        case .imageProcessing: return "Makes JPEG, PNG and WebP lighter"
        case .highQualityJPEG: return "Keeps JPEGs sharp at a smaller size"
        case .applePhotos: return "Opens HEIC, HEIF and AVIF"
        case .photography: return "Turns RAW, DNG and TIFF into everyday images"
        case .animation: return "Makes GIF, APNG and animated WebP lighter"
        case .legacyFormats: return "Turns BMP, TGA and other old formats into modern ones"
        case .metadataCleaner: return "Removes location, camera and other hidden data"
        case .aiProvenance: return "Finds AI labels and removes them if you ask"
        case .pdfTools: return "Makes PDFs lighter and finds repeated pages"
        }
    }

    /// A sentence or two for the plugin's own page.
    var summary: String {
        switch self {
        case .imageProcessing:
            return "Makes JPEG, PNG and WebP images lighter. Can also resize them and change their format."
        case .highQualityJPEG:
            return "Uses Google jpegli to keep JPEGs sharp at a smaller size."
        case .applePhotos:
            return "Opens HEIC, HEIF and AVIF images from iPhone, Apple Photos and modern cameras."
        case .photography:
            return "Turns TIFF, DNG and camera RAW files into everyday images. The RAW original always stays."
        case .animation:
            return "Makes GIF, APNG and animated WebP lighter, and keeps them moving. Can turn them into MP4, HEVC, WebM or AV1 video."
        case .legacyFormats:
            return "Turns BMP, TGA, PCX, PICT and other old formats into images that open anywhere."
        case .metadataCleaner:
            return "Removes location, camera and author details hidden in your images when you send them in a chat, post them or put them on a website."
        case .aiProvenance:
            return "Finds Content Credentials and AI labels in JPEG, PNG and WebP, and removes them only if you ask. It cannot see watermarks drawn into the pixels, such as SynthID."
        case .pdfTools:
            return "Makes PDFs lighter and finds repeated pages for you to review."
        }
    }

    var installable: Bool { true }

    /// Every plugin in display order: by group, then by name.
    static var ordered: [ExtensionID] { PluginCategory.allCases.flatMap(\.plugins) }

    var category: PluginCategory {
        switch self {
        case .imageProcessing, .highQualityJPEG, .applePhotos, .photography, .legacyFormats: return .images
        case .animation: return .animation
        case .pdfTools: return .documents
        case .aiProvenance: return .ai
        case .metadataCleaner: return .utilities
        }
    }

    /// Tile colour comes from the group, so related plugins read as one family.
    var tint: Color { category.tint }

    /// Plugins whose page has options beyond the components list.
    /// Metadata Cleaner has no settings of its own: the routine decides when
    /// hidden details are removed.
    var hasSettings: Bool { self != .applePhotos && self != .metadataCleaner }

    var symbolName: String {
        switch self {
        case .imageProcessing: return "photo"
        case .highQualityJPEG: return "camera"
        case .applePhotos: return "photo.on.rectangle.angled"
        case .photography: return "camera.aperture"
        case .animation: return "play.rectangle"
        case .legacyFormats: return "archivebox"
        case .metadataCleaner: return "eraser"
        case .aiProvenance: return "checkmark.seal"
        case .pdfTools: return "doc.richtext"
        }
    }

    // Dependencies are installed with the requested plugin, so a selected
    // capability can never be left visible but unusable.
    var dependencies: [ExtensionID] {
        switch self {
        case .highQualityJPEG:
            return [.imageProcessing]
        default:
            return []
        }
    }
}

/// Plugin groups; each has one tile colour. AI comes first, then the rest
/// alphabetically; `plugins` is alphabetical too, so every list of plugins
/// follows the same order.
enum PluginCategory: CaseIterable, Identifiable {
    case ai, animation, documents, images, utilities

    var id: Self { self }

    var title: String {
        switch self {
        case .ai: return "AI"
        case .images: return "Images"
        case .animation: return "Animation"
        case .documents: return "Documents"
        case .utilities: return "Utilities"
        }
    }

    var tint: Color {
        switch self {
        case .ai: return .indigo
        case .images: return .blue
        case .animation: return .purple
        case .documents: return .red
        case .utilities: return .gray
        }
    }

    var plugins: [ExtensionID] {
        ExtensionID.allCases.filter { $0.category == self }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

private struct PluginCatalog: Decodable {
    let schemaVersion: Int
    let plugins: [PluginRelease]
}

private struct PluginRelease: Decodable {
    let id: String
    // The README heading for this plugin; older catalogs have none.
    let name: String?
    let version: String
    let minimumRightformVersion: String
    let repository: URL
    let artifact: PluginArtifact?
    let components: [PluginComponent]?
}

private struct PluginComponent: Decodable, Identifiable {
    let id: String
    let name: String
    let repository: URL
    // Optional so catalogs published before attribution data still decode.
    let license: String?
    let install: String?
}

/// An upstream project a plugin installs. Stou only integrates these
/// tools; it does not redistribute or re-sign them.
struct PluginComponentInfo: Identifiable, Hashable {
    enum Source: Hashable {
        case homebrew(formula: String)
        case builtFromSource(revision: String)
        case unknown
    }

    let id: String
    let name: String
    let repository: URL
    let license: String
    let source: Source
    let installedVersion: String?

    var sourceDescription: String {
        switch source {
        case .homebrew(let formula): return "Homebrew · \(formula)"
        case .builtFromSource(let revision):
            let short = revision.count == 40 ? String(revision.prefix(7)) : revision
            return "Built from source · \(short)"
        case .unknown: return "Local tool"
        }
    }
}

private struct PluginArtifact: Decodable {
    let url: URL
    let sha256: String
}

enum PluginUpdateStatus: Equatable {
    case unchecked
    case checking
    case current
    case updateAvailable(version: String)
    case unavailable
}

enum ExtensionInstallState: Equatable {
    case notInstalled
    case installing
    case cancelling
    case installed(String)
    case removing
    case failed(String)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .installing, .cancelling, .removing: return true
        default: return false
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

enum ExtensionHealth: Equatable {
    case notInstalled
    case ready
    case missingRequirements([String])

    var summary: String {
        switch self {
        case .notInstalled: return "Not installed"
        case .ready: return "Ready"
        case .missingRequirements(let requirements):
            return "Missing: \(requirements.joined(separator: ", "))"
        }
    }
}

enum ExtensionRegistry {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Stou/Extensions", isDirectory: true)

    // Stou (earlier Rightform) succeeds IMGLESS. Read an existing extension in its old location
    // until the user installs or removes it from Stou's Settings.
    static let legacyRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/IMGLESS/Extensions", isDirectory: true)

    static func root(for id: ExtensionID) -> URL {
        root.appendingPathComponent(id.rawValue, isDirectory: true)
    }

    static func manifest(for id: ExtensionID) -> URL {
        root(for: id).appendingPathComponent("manifest.json")
    }

    static func isInstalled(_ id: ExtensionID) -> Bool {
        if isInstalled(id, under: root) { return true }
        return isInstalled(id, under: legacyRoot)
    }

    static func health(for id: ExtensionID) -> ExtensionHealth {
        let manifests = [manifest(for: id), legacyRoot
            .appendingPathComponent(id.rawValue, isDirectory: true)
            .appendingPathComponent("manifest.json")]
        guard manifests.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return .notInstalled
        }

        let requirements: [String]
        switch id {
        case .imageProcessing:
            requirements = ["jpeg-recompress", "pngquant", "oxipng", "cwebp", "dwebp"]
        case .highQualityJPEG:
            requirements = ["cjpegli"]
        case .applePhotos, .photography, .legacyFormats:
            requirements = ["magick"]
        case .animation:
            requirements = ["ffmpeg", "ffprobe"]
        case .metadataCleaner:
            requirements = ["exiftool", "magick"]
        case .aiProvenance:
            requirements = ["python3"]
        case .pdfTools:
            requirements = ["qpdf", "pdfcpu", "gs"]
        }
        let missing = requirements.filter { Toolchain.locate($0) == nil }
        return missing.isEmpty ? .ready : .missingRequirements(missing)
    }

    private static func isInstalled(_ id: ExtensionID, under extensionsRoot: URL) -> Bool {
        let extensionRoot = extensionsRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        let manifest = extensionRoot.appendingPathComponent("manifest.json")
        if id == .imageProcessing {
            return FileManager.default.fileExists(atPath: manifest.path) &&
                   ["jpeg-recompress", "pngquant", "oxipng", "cwebp", "dwebp"].allSatisfy { Toolchain.locate($0) != nil }
        }
        if id == .highQualityJPEG {
            return FileManager.default.fileExists(atPath: extensionRoot.appendingPathComponent("build/tools/cjpegli").path)
        }
        if id == .aiProvenance {
            return FileManager.default.fileExists(atPath: extensionRoot.appendingPathComponent("service/scripts/clean_image.py").path) &&
                   FileManager.default.fileExists(atPath: extensionRoot.appendingPathComponent("service/scripts/inspect_image.py").path)
        }
        if id == .pdfTools {
            return FileManager.default.fileExists(atPath: manifest.path) &&
                   Toolchain.locate("qpdf") != nil && Toolchain.locate("pdfcpu") != nil && Toolchain.locate("gs") != nil
        }
        if id == .animation {
            return FileManager.default.fileExists(atPath: manifest.path) &&
                   Toolchain.locate("ffmpeg") != nil && Toolchain.locate("ffprobe") != nil
        }
        if id == .photography || id == .legacyFormats {
            return FileManager.default.fileExists(atPath: manifest.path) && Toolchain.locate("magick") != nil
        }
        return FileManager.default.fileExists(atPath: manifest.path)
    }

    static var cjpegli: URL {
        let current = root(for: .highQualityJPEG).appendingPathComponent("build/tools/cjpegli")
        return FileManager.default.fileExists(atPath: current.path)
            ? current
            : legacyRoot.appendingPathComponent("high-quality-jpeg/build/tools/cjpegli")
    }

    static var watermarksCleanScript: URL {
        let current = root(for: .aiProvenance).appendingPathComponent("service/scripts/clean_image.py")
        return FileManager.default.fileExists(atPath: current.path)
            ? current
            : legacyRoot.appendingPathComponent("ai-provenance/service/scripts/clean_image.py")
    }

    static var watermarksInspectScript: URL {
        let current = root(for: .aiProvenance).appendingPathComponent("service/scripts/inspect_image.py")
        return FileManager.default.fileExists(atPath: current.path)
            ? current
            : legacyRoot.appendingPathComponent("ai-provenance/service/scripts/inspect_image.py")
    }

    static func requiredExtension(for format: ImageFormat) -> ExtensionID? {
        switch format {
        case .jpeg, .png, .webp: return .imageProcessing
        case .heic, .avif: return .applePhotos
        case .tiff, .raw: return .photography
        case .gif, .apng, .animatedWebP, .mp4, .webm: return .animation
        case .bmp, .tga, .pcx, .pict, .ppm, .pgm, .pbm, .xbm, .xpm, .sgi, .sun: return .legacyFormats
        case .pdf: return .pdfTools
        case .unknown: return nil
        }
    }

    static func supports(_ format: ImageFormat) -> Bool {
        guard let required = requiredExtension(for: format) else {
            return false
        }
        return isInstalled(required)
    }

    static func writeManifest(id: ExtensionID, version: String, capabilities: [String]) throws {
        let fm = FileManager.default
        let dir = root(for: id)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let json: [String: Any] = [
            "id": "com.stou.\(id.rawValue)",
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
@Observable
final class ExtensionManager {
    nonisolated static let watermarksRepositoryURL = "https://github.com/guillaumemeyer/watermarks-remover.git"
    nonisolated static let watermarksTag = "v0.5.0"
    nonisolated static let watermarksCommit = "dc0ff78f39bedfe0a1986eef54efb297645372ba"
    nonisolated static let jpegliRepositoryURL = "https://github.com/google/jpegli.git"
    nonisolated static let jpegliCommit = "031a0077f5799a6041004267fc12b956c1f52a20"

    private(set) var states: [ExtensionID: ExtensionInstallState] = [:]
    private(set) var pluginUpdateStatus: PluginUpdateStatus = .unchecked
    private var availableUpdates: [ExtensionID: PluginRelease] = [:]
    private var installationTasks: [ExtensionID: Task<(Bool, String?), Never>] = [:]

    // Homebrew formulae of installed plugins with a newer version, found by the
    // weekly check. Kept across launches so the button stays until it is used.
    private static let outdatedFormulaeKey = "outdatedPluginFormulae"
    private static let lastFormulaeCheckKey = "lastPluginUpdateCheck"
    private static let formulaeCheckInterval: TimeInterval = 7 * 86_400
    private(set) var outdatedFormulae: Set<String> = Set(UserDefaults.standard.stringArray(forKey: ExtensionManager.outdatedFormulaeKey) ?? [])
    private(set) var lastFormulaeCheck: Date? = UserDefaults.standard.object(forKey: ExtensionManager.lastFormulaeCheckKey) as? Date
    private(set) var isCheckingFormulae = false
    private(set) var updatingFormulae: Set<ExtensionID> = []
    private(set) var formulaeMessage: [ExtensionID: String] = [:]

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

    /// Homebrew formulae behind a plugin, which `brew upgrade` can update.
    /// Plugins built from source have none.
    func formulae(for id: ExtensionID) -> [String] {
        components(for: id).compactMap {
            if case .homebrew(let formula) = $0.source { return formula }
            return nil
        }
    }

    func outdatedFormulae(for id: ExtensionID) -> [String] {
        formulae(for: id).filter { outdatedFormulae.contains($0) }
    }

    /// Asks Homebrew which installed plugins' formulae have newer versions.
    /// Without `force` it runs at most once a week.
    func checkFormulaeUpdates(force: Bool = false) {
        guard !isCheckingFormulae else { return }
        if !force, let last = lastFormulaeCheck, Date().timeIntervalSince(last) < Self.formulaeCheckInterval { return }
        let watched = Array(Set(ExtensionID.allCases.filter { state(for: $0).isInstalled }.flatMap { formulae(for: $0) })).sorted()
        guard !watched.isEmpty else { return }
        isCheckingFormulae = true
        formulaeMessage = [:]
        Task {
            let result = await Task.detached(priority: .utility) { Self.brewOutdated(watched) }.value
            isCheckingFormulae = false
            switch result {
            case .success(let outdated):
                outdatedFormulae = Set(outdated)
                lastFormulaeCheck = Date()
                UserDefaults.standard.set(outdated, forKey: Self.outdatedFormulaeKey)
                UserDefaults.standard.set(lastFormulaeCheck, forKey: Self.lastFormulaeCheckKey)
            case .failure(let error):
                for id in ExtensionID.allCases where !formulae(for: id).isEmpty && state(for: id).isInstalled {
                    formulaeMessage[id] = "Couldn’t check for updates: \(error.description)"
                }
            }
        }
    }

    /// Upgrades the plugin's outdated formulae with Homebrew.
    func updateFormulae(for id: ExtensionID) {
        let names = outdatedFormulae(for: id)
        guard !names.isEmpty, !updatingFormulae.contains(id), !state(for: id).isBusy else { return }
        updatingFormulae.insert(id)
        formulaeMessage[id] = nil
        Task {
            let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    guard let brew = Toolchain.locate("brew") else {
                        throw CompressionError.message("Homebrew isn’t installed.")
                    }
                    _ = try ProcessRunner.run(brew, ["upgrade", "--formula", "--quiet"] + names)
                    return nil
                } catch let error as CompressionError {
                    return error.description
                } catch {
                    return error.localizedDescription
                }
            }.value
            updatingFormulae.remove(id)
            if let failure {
                formulaeMessage[id] = "Couldn’t update \(id.title): \(failure)"
            } else {
                outdatedFormulae.subtract(names)
                UserDefaults.standard.set(Array(outdatedFormulae), forKey: Self.outdatedFormulaeKey)
                refreshAll()
            }
        }
    }

    nonisolated private static func brewOutdated(_ formulae: [String]) -> Result<[String], CompressionError> {
        guard let brew = Toolchain.locate("brew") else {
            return .failure(.message("Homebrew isn’t installed."))
        }
        do {
            // Homebrew only knows about new versions after it refreshes its own list.
            _ = try? ProcessRunner.runWithStatus(brew, ["update", "--quiet"])
            // `brew outdated` exits with 1 when it finds outdated formulae, so only
            // other codes are failures.
            let result = try ProcessRunner.runWithStatus(brew, ["outdated", "--formula", "--json=v2"] + formulae)
            guard result.status == 0 || result.status == 1 else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return .failure(.message(message.isEmpty ? "Homebrew exited with code \(result.status)." : message))
            }
            guard let data = result.stdout.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["formulae"] as? [[String: Any]] else {
                return .failure(.message("Homebrew answered in an unexpected form."))
            }
            return .success(list.compactMap { $0["name"] as? String })
        } catch let error as CompressionError {
            return .failure(error)
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    func checkForUpdates() {
        Task {
            pluginUpdateStatus = .checking
            do {
                let catalog = try await Self.loadPluginCatalog()
                guard catalog.schemaVersion == 2 else { throw URLError(.cannotParseResponse) }
                let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                let releases = Dictionary(uniqueKeysWithValues: catalog.plugins.compactMap { release -> (ExtensionID, PluginRelease)? in
                    guard let id = ExtensionID(rawValue: release.id) else { return nil }
                    return (id, release)
                })
                availableUpdates = Dictionary(uniqueKeysWithValues: ExtensionID.allCases.compactMap { id -> (ExtensionID, PluginRelease)? in
                    guard state(for: id).isInstalled,
                          let release = releases[id],
                          release.artifact != nil,
                          Self.isNewer(release.version, than: installedVersion(for: id)),
                          !Self.isNewer(release.minimumRightformVersion, than: currentAppVersion) else { return nil }
                    return (id, release)
                })
                pluginUpdateStatus = availableUpdates.isEmpty ? .current : .updateAvailable(version: "")
            } catch {
                pluginUpdateStatus = .unavailable
            }
        }
    }

    func install(_ id: ExtensionID) {
        guard id.installable, !state(for: id).isBusy else { return }
        states[id] = .installing
        let task = Task.detached(priority: .userInitiated) { Self.installSynchronously(id) }
        installationTasks[id] = task
        Task { @MainActor [weak self] in
            let result = await task.value
            guard let self, self.installationTasks.removeValue(forKey: id) != nil else { return }
            if result.0 {
                self.refreshAll()
            } else if task.isCancelled {
                self.states[id] = .notInstalled
            } else {
                self.states[id] = .failed(result.1 ?? "Installation failed.")
            }
        }
    }

    func update(_ id: ExtensionID) {
        guard let release = availableUpdates[id], !state(for: id).isBusy else { return }
        states[id] = .installing
        let task = Task.detached(priority: .userInitiated) { await Self.installArtifact(release, for: id) }
        installationTasks[id] = task
        Task { @MainActor [weak self] in
            let result = await task.value
            guard let self, self.installationTasks.removeValue(forKey: id) != nil else { return }
            if result.0 {
                self.availableUpdates.removeValue(forKey: id)
                self.refreshAll()
            } else if task.isCancelled {
                self.states[id] = .notInstalled
            } else {
                self.states[id] = .failed(result.1 ?? "Plugin update failed.")
            }
        }
    }

    func cancelInstall(_ id: ExtensionID) {
        guard case .installing = state(for: id), let task = installationTasks[id] else { return }
        states[id] = .cancelling
        task.cancel()
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
            self.states[id] = result.0 ? .notInstalled : .failed(result.1 ?? "Could not remove plugin.")
        }
    }

    func action(_ id: ExtensionID) {
        if state(for: id).isInstalled { remove(id) } else { install(id) }
    }

    func hasUpdate(for id: ExtensionID) -> Bool { availableUpdates[id] != nil }

    func health(for id: ExtensionID) -> ExtensionHealth {
        ExtensionRegistry.health(for: id)
    }

    func installationDescription(for id: ExtensionID) -> String {
        guard let release = Self.bundledPluginCatalog()?.plugins.first(where: { $0.id == id.rawValue }) else {
            return "Uses local command-line tools."
        }
        return release.artifact == nil
            ? "Uses Homebrew or locally built tools."
            : "Managed Stou package."
    }

    func hasManagedUpdateChannel(for id: ExtensionID) -> Bool {
        Self.bundledPluginCatalog()?.plugins.first(where: { $0.id == id.rawValue })?.artifact != nil
    }

    var hasManagedUpdateChannel: Bool {
        Self.bundledPluginCatalog()?.plugins.contains(where: { $0.artifact != nil }) ?? false
    }

    /// Upstream projects behind a plugin, with the version actually on this Mac.
    func components(for id: ExtensionID) -> [PluginComponentInfo] {
        guard let release = Self.bundledPluginCatalog()?.plugins.first(where: { $0.id == id.rawValue }) else { return [] }
        return (release.components ?? []).map { component in
            let source: PluginComponentInfo.Source
            let raw = component.install ?? ""
            if raw.hasPrefix("homebrew:") {
                source = .homebrew(formula: String(raw.dropFirst("homebrew:".count)))
            } else if raw.hasPrefix("source:") {
                source = .builtFromSource(revision: String(raw.dropFirst("source:".count)))
            } else {
                source = .unknown
            }
            return PluginComponentInfo(
                id: component.id,
                name: component.name,
                repository: component.repository,
                license: component.license ?? "See repository",
                source: source,
                installedVersion: Self.installedUpstreamVersion(source)
            )
        }
    }

    /// Reads Homebrew's `opt` link instead of running `brew`, which is slow to start.
    nonisolated private static func installedUpstreamVersion(_ source: PluginComponentInfo.Source) -> String? {
        switch source {
        case .homebrew(let formula):
            for prefix in ["/opt/homebrew", "/usr/local"] {
                let opt = URL(fileURLWithPath: "\(prefix)/opt/\(formula)")
                guard FileManager.default.fileExists(atPath: opt.path) else { continue }
                return opt.resolvingSymlinksInPath().lastPathComponent
            }
            return nil
        case .builtFromSource(let revision):
            return revision.count == 40 ? String(revision.prefix(7)) : revision
        case .unknown:
            return nil
        }
    }

    func repositoryURL(for id: ExtensionID) -> URL? {
        Self.bundledPluginCatalog()?.plugins.first(where: { $0.id == id.rawValue })?.repository
    }

    /// The plugin's section of the README: the tools it installs, their
    /// licences and repositories, generated from plugins.json.
    func toolsURL(for id: ExtensionID) -> URL {
        let name = Self.bundledPluginCatalog()?.plugins.first(where: { $0.id == id.rawValue })?.name ?? id.title
        // GitHub's anchor for the "### <name>" heading scripts/update-plugin-tools.sh writes.
        let anchor = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return URL(string: "https://github.com/prisonmike420/stou#\(anchor)")!
    }

    nonisolated private static func loadPluginCatalog() async throws -> PluginCatalog {
        let decoder = JSONDecoder()
        let remote = URL(string: "https://raw.githubusercontent.com/prisonmike420/stou/main/Resources/plugins.json")!
        if let (data, response) = try? await URLSession.shared.data(from: remote),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let catalog = try? decoder.decode(PluginCatalog.self, from: data) {
            return catalog
        }
        guard let catalog = bundledPluginCatalog() else { throw URLError(.fileDoesNotExist) }
        return catalog
    }

    nonisolated private static func bundledPluginCatalog() -> PluginCatalog? {
        guard let local = Bundle.main.url(forResource: "plugins", withExtension: "json"),
              let data = try? Data(contentsOf: local) else { return nil }
        return try? JSONDecoder().decode(PluginCatalog.self, from: data)
    }

    nonisolated private static func isNewer(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }
        let localParts = local.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            .split(separator: ".").compactMap { Int($0) }
        guard !remoteParts.isEmpty, !localParts.isEmpty else { return false }
        for index in 0..<max(remoteParts.count, localParts.count) {
            let left = index < remoteParts.count ? remoteParts[index] : 0
            let right = index < localParts.count ? localParts[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    nonisolated private static func installArtifact(_ release: PluginRelease, for id: ExtensionID) async -> (Bool, String?) {
        do {
            guard release.artifact?.sha256.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression) != nil,
                  let artifact = release.artifact else {
                throw CompressionError.message("This plugin release has no verified archive.")
            }
            let (data, response) = try await URLSession.shared.data(from: artifact.url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw CompressionError.message("Could not download the plugin update.")
            }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("stou-plugin-\(UUID().uuidString).zip")
            let stage = FileManager.default.temporaryDirectory.appendingPathComponent("stou-plugin-stage-\(UUID().uuidString)")
            defer {
                try? FileManager.default.removeItem(at: temporary)
                try? FileManager.default.removeItem(at: stage)
            }
            try data.write(to: temporary, options: .atomic)
            guard let shasum = Toolchain.locate("shasum") else {
                throw CompressionError.message("macOS checksum tool is unavailable.")
            }
            let digest = try ProcessRunner.run(shasum, ["-a", "256", temporary.path])
                .split(separator: " ").first.map(String.init)?.lowercased()
            guard digest == artifact.sha256.lowercased() else {
                throw CompressionError.message("Plugin update failed verification (SHA-256 mismatch).")
            }
            guard let ditto = Toolchain.locate("ditto") else {
                throw CompressionError.message("macOS archive tool is unavailable.")
            }
            _ = try ProcessRunner.run(ditto, ["-x", "-k", temporary.path, stage.path])
            let candidate = stage.appendingPathComponent(id.rawValue, isDirectory: true)
            let manifest = candidate.appendingPathComponent("manifest.json")
            guard let manifestData = try? Data(contentsOf: manifest),
                  let json = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
                  json["id"] as? String == "com.stou.\(id.rawValue)",
                  json["version"] as? String == release.version else {
                throw CompressionError.message("Plugin archive has an invalid manifest.")
            }
            let destination = ExtensionRegistry.root(for: id)
            let backup = destination.deletingLastPathComponent().appendingPathComponent(".\(id.rawValue)-backup-\(UUID().uuidString)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.moveItem(at: destination, to: backup)
            }
            do {
                try FileManager.default.moveItem(at: candidate, to: destination)
                try? FileManager.default.removeItem(at: backup)
            } catch {
                if FileManager.default.fileExists(atPath: backup.path) {
                    try? FileManager.default.moveItem(at: backup, to: destination)
                }
                throw error
            }
            return (true, nil)
        } catch let error as CompressionError {
            return (false, error.description)
        } catch {
            return (false, error.localizedDescription)
        }
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
        let manifests = [ExtensionRegistry.manifest(for: id), ExtensionRegistry.legacyRoot
            .appendingPathComponent(id.rawValue, isDirectory: true)
            .appendingPathComponent("manifest.json")]
        if let data = manifests.lazy.compactMap({ try? Data(contentsOf: $0) }).first,
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
            throw CompressionError.message("Homebrew is required to install this plugin.")
        }
        for package in packages {
            _ = try ProcessRunner.run(brew, ["install", package])
        }
    }

    nonisolated private static func installSynchronously(_ id: ExtensionID) -> (Bool, String?) {
        do {
            try FileManager.default.createDirectory(at: ExtensionRegistry.root, withIntermediateDirectories: true)

            for dependency in id.dependencies where !ExtensionRegistry.isInstalled(dependency) {
                let dependencyResult = installSynchronously(dependency)
                guard dependencyResult.0 else {
                    throw CompressionError.message(dependencyResult.1 ?? "Could not install \(dependency.title).")
                }
            }

            switch id {
            case .imageProcessing:
                try brewInstall(["jpeg-archive", "jpeg-turbo", "pngquant", "oxipng", "webp"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "1.0",
                    capabilities: [
                        "decode.jpeg", "encode.jpeg", "decode.png", "encode.png",
                        "decode.webp", "encode.webp", "resize.image", "verify.image"
                    ]
                )
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
                // Ghostscript lowers image resolution for the smaller levels.
                try brewInstall(["qpdf", "pdfcpu", "ghostscript"])
                try ExtensionRegistry.writeManifest(
                    id: id, version: "2.2",
                    capabilities: [
                        "inspect.pdf",
                        "detect.pdf.duplicates.exact",
                        "detect.pdf.duplicates.similar",
                        "remove.pdf.duplicates",
                        "compress.pdf.structure",
                        "compress.pdf.images",
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
            .appendingPathComponent(".stou-provenance-\(UUID().uuidString).\(ext)")
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

    /// Formats the upstream inspector understands.
    static func canInspect(_ format: ImageFormat) -> Bool {
        [.jpeg, .png, .webp].contains(format)
    }

    /// Reports labels without changing the file.
    static func inspect(url: URL) throws -> AILabelReport {
        guard let python = ExtensionManager.supportedPython() else {
            throw CompressionError.message("AI Provenance needs Python 3.10 or newer.")
        }
        // Exit status 1 means labels were found; the JSON report is still complete.
        let result = try ProcessRunner.runWithStatus(python, [
            ExtensionRegistry.watermarksInspectScript.path,
            url.path,
            "--json"
        ])
        guard let data = result.stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CompressionError.message("AI Provenance returned an unreadable report.")
        }
        return AILabelReport(
            hasC2PA: json["has_c2pa"] as? Bool ?? false,
            hasAIMetadata: json["has_ai_metadata"] as? Bool ?? false,
            findings: (json["findings"] as? [Any])?.map { "\($0)" } ?? []
        )
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

