import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

// MARK: - inspect → clean → verify

enum Inspector {
    static func inspect(url: URL, expectedFormat: ImageFormat? = nil) throws -> InspectionReport {
        guard let format = FileSniffer.detect(url: url), format != .unknown else {
            throw CompressionError.message("STOU could not identify this image format.")
        }
        if let expectedFormat, expectedFormat != format {
            throw CompressionError.message("The output file format does not match the requested format.")
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw CompressionError.message("STOU could not decode this image.")
        }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard width > 0, height > 0 else {
            throw CompressionError.message("STOU could not read image dimensions.")
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

