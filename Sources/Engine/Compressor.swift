import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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
        pdfPagesToRemove: [Int] = [],
        removeAILabels: Bool = false
    ) -> CompressionResult {
        Staging.withJob {
            compressInJob(
                url: url,
                format: format,
                originalBytes: originalBytes,
                settings: settings,
                cancellation: cancellation,
                pdfPagesToRemove: pdfPagesToRemove,
                removeAILabels: removeAILabels
            )
        }
    }

    private static func compressInJob(
        url: URL,
        format: ImageFormat,
        originalBytes: Int64,
        settings: SettingsSnapshot,
        cancellation: CancellationToken?,
        pdfPagesToRemove: [Int],
        removeAILabels: Bool
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
                    throw CompressionError.message("Install the “\(required.title)” plugin for this format.")
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
                throw CompressionError.message("The selected output format needs a plugin that is not installed.")
            }

            if before.frameCount > 1 && targetFormat != format {
                throw CompressionError.message("Animated or multi-image files currently stay in their original format.")
            }
            if before.frameCount > 1 && format == .webp && Toolchain.locate("magick") == nil {
                throw CompressionError.message("Animated WebP requires the Animation plugin.")
            }

            let fm = FileManager.default
            let outputDir: URL
            if settings.keepOriginals && settings.saveLocation == .folder, let path = settings.outputFolderPath {
                outputDir = URL(fileURLWithPath: path, isDirectory: true)
            } else {
                outputDir = url.deletingLastPathComponent()
            }
            try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let temp = outputDir.appendingPathComponent(".stou-\(UUID().uuidString).\(targetFormat.fileExtension)")
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
            // Only on the user's explicit request for this file.
            let useAIProvenance = removeAILabels && WatermarksExtensionRunner.isInstalled
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
            let temp = outputDir.appendingPathComponent(".stou-\(UUID().uuidString).pdf")
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
                throw CompressionError.message("Animation plugin is required for this file.")
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
            let temp = outputDir.appendingPathComponent(".stou-animation-\(UUID().uuidString).\(target.fileExtension)")
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
                throw CompressionError.message("Photography plugin is required for TIFF and RAW files.")
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
            let temp = outputDir.appendingPathComponent(".stou-photo-\(UUID().uuidString).\(target.fileExtension)")
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
                throw CompressionError.message("Legacy Formats plugin is required for this file.")
            }
            let target: ImageFormat
            switch settings.legacyPreferredOutput {
            case .original: target = format
            case .png: target = .png
            case .jpeg: target = .jpeg
            case .webp: target = .webp
            }
            let outputDir = try outputDirectory(for: url, settings: settings)
            let temp = outputDir.appendingPathComponent(".stou-legacy-\(UUID().uuidString).\(target.fileExtension)")
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

    /// Names from earlier runs lose their prefix and suffix first, so preparing
    /// `photo_prepared.jpg` again gives `photo_prepared_2.jpg`, not
    /// `photo_prepared_prepared.jpg`.
    static func outputStem(_ stem: String, prefix: String, suffix: String) -> String {
        var base = stem
        if !prefix.isEmpty, base.hasPrefix(prefix), base.count > prefix.count {
            base.removeFirst(prefix.count)
        }
        for marker in [suffix, "_prepared", "_compressed", "_converted"] where !marker.isEmpty {
            if let range = base.range(of: "\(NSRegularExpression.escapedPattern(for: marker))(_[0-9]+)?$", options: .regularExpression),
               range.lowerBound != base.startIndex {
                base.removeSubrange(range)
                break
            }
        }
        return base
    }

    private static func finalizeDerivative(
        temp: URL,
        input: URL,
        targetFormat: ImageFormat,
        settings: SettingsSnapshot,
        outputDir: URL
    ) throws -> URL {
        let fm = FileManager.default
        let prefix = settings.prefix
        let suffix = settings.suffix
        let stem = outputStem(input.deletingPathExtension().lastPathComponent, prefix: prefix, suffix: suffix)
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
        let temp = Staging.file("STOU-prepared-\(UUID().uuidString).png")
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
            let decoded = Staging.file("STOU-prepared-webp-\(UUID().uuidString).png")
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
                throw CompressionError.message("This resize needs the format plugin to be installed.")
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
            let tmp = Staging.file("STOU-jpeg-source-\(UUID().uuidString).jpg")
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
            let tmp = Staging.file("STOU-png-source-\(UUID().uuidString).png")
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
            let quantized = Staging.file("STOU-pngquant-\(UUID().uuidString).png")
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
            let tmp = Staging.file("STOU-webp-source-\(UUID().uuidString).png")
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
            throw CompressionError.message("This format needs a STOU format plugin.")
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
    // Extra formats use ImageMagick supplied by their plugin.
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
            let png = Staging.file("STOU-webp-decode-\(UUID().uuidString).png")
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
            throw CompressionError.message("STOU could not prepare this image for the selected encoder.")
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
        let temp = url.deletingLastPathComponent().appendingPathComponent(".stou-progressive-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: temp) }
        let result = try ProcessRunner.runWithStatus(jpegtran, ["-copy", "all", "-optimize", "-progressive", "-outfile", temp.path, url.path])
        guard result.status == 0, FileManager.default.fileExists(atPath: temp.path) else { return }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
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
            let suffix = settings.suffix
            let stem = outputStem(stem, prefix: prefix, suffix: suffix)
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
            // The swap is atomic and keeps the original's attributes (Finder tags,
            // creation date). The original survives as a backup and goes to the
            // Trash, so it can still be restored.
            var backupName = "\(stem) (original).\(input.pathExtension)"
            var number = 2
            while fm.fileExists(atPath: input.deletingLastPathComponent().appendingPathComponent(backupName).path) {
                backupName = "\(stem) (original \(number)).\(input.pathExtension)"
                number += 1
            }
            _ = try fm.replaceItemAt(input, withItemAt: temp, backupItemName: backupName, options: .withoutDeletingBackupItem)
            // Where the volume has no Trash, the backup stays next to the file.
            try? fm.trashItem(at: input.deletingLastPathComponent().appendingPathComponent(backupName), resultingItemURL: nil)
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
        // The original goes to the Trash, never straight to deletion. Where the
        // volume has no Trash, it stays in place next to the new file.
        try? fm.trashItem(at: input, resultingItemURL: nil)
        preserveDateIfNeeded(replacement)
        return replacement
    }
}

enum Toolchain {
    static func locate(_ name: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "\(home)/Library/Application Support/STOU/bin/\(name)",
            "\(home)/Library/Application Support/STOU/Extensions/high-quality-jpeg/build/tools/\(name)",
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

