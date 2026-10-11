import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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

/// AI-generation labels found in a file: C2PA Content Credentials and
/// AI-related metadata. Pixel watermarks such as SynthID are not covered.
struct AILabelReport: Sendable, Equatable {
    let hasC2PA: Bool
    let hasAIMetadata: Bool
    let findings: [String]

    var isEmpty: Bool { !hasC2PA && !hasAIMetadata }

    var summary: String {
        switch (hasC2PA, hasAIMetadata) {
        case (true, true): return "Content Credentials and AI metadata"
        case (true, false): return "Content Credentials"
        case (false, true): return "AI metadata"
        case (false, false): return "No AI labels"
        }
    }
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
    /// nil until checked; only set when the AI Provenance plugin is installed.
    var aiLabels: AILabelReport?
    /// Labels are removed only when the user asks for it.
    var removeAILabels = false
    /// The user kept the labels, but re-encoding did not preserve them.
    var aiLabelsLost = false

    var hasAILabels: Bool { aiLabels.map { !$0.isEmpty } ?? false }

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
    let removeAILabels: Bool
    /// This file's settings, as the planner decided them.
    let settings: SettingsSnapshot
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
        if jobs.contains(where: \.removeAILabels) && CapabilityResolver.aiProvenanceAvailable {
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

