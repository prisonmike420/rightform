import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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
            throw CompressionError.message("Stou could not open this PDF.")
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
            let temp = Staging.file("Stou-pdf-preflight-\(UUID().uuidString).pdf")
            defer { try? FileManager.default.removeItem(at: temp) }
            try compressStructurePreserving(input: source, output: temp, mode: mode, cancellation: nil)
            let bytes = FileSniffer.fileSize(url: temp)
            estimate = bytes > 0 ? bytes : originalBytes
        case .maximum:
            guard let dedupedDocument = PDFDocument(url: source) else {
                throw CompressionError.message("Stou could not analyze the deduplicated PDF.")
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
            throw CompressionError.message("Stou could not open this PDF.")
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
                throw CompressionError.message("Stou could not prepare this PDF.")
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
            throw CompressionError.message("Stou could not render a PDF page for duplicate detection.")
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
            throw CompressionError.message("Stou could not open this PDF for duplicate removal.")
        }
        let indexes = valid.filter { $0 < document.pageCount }.sorted(by: >)
        for index in indexes { document.removePage(at: index) }
        guard document.pageCount > 0 else {
            throw CompressionError.message("Duplicate removal would leave the PDF empty.")
        }
        let temp = Staging.file("Stou-pdf-dedup-\(UUID().uuidString).pdf")
        guard document.write(to: temp) else {
            throw CompressionError.message("Stou could not write the PDF after removing duplicate pages.")
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
            throw CompressionError.message("PDF Tools needs qpdf. Reinstall the plugin.")
        }
        guard let pdfcpu = Toolchain.locate("pdfcpu") else {
            throw CompressionError.message("PDF Tools needs pdfcpu. Reinstall the plugin.")
        }

        let fm = FileManager.default
        let workDir = Staging.directory.appendingPathComponent("Stou-pdf-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        let stageQPDF = workDir.appendingPathComponent("qpdf.pdf")
        let stagePDFCPU = workDir.appendingPathComponent("pdfcpu.pdf")
        try cancellation?.check()

        // Balanced and Small lower the resolution of images first, so the
        // levels really differ; text and vectors stay as they are.
        let source = try downsampleImages(input: input, mode: mode, workDir: workDir) ?? input
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
        qpdfArgs += [source.path, stageQPDF.path]

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

    /// Image resolution for each level; Light keeps images untouched.
    private static func imageResolution(for mode: PDFCompressionMode) -> Int? {
        switch mode {
        case .light, .maximum: return nil
        case .balanced: return 150
        case .aggressive: return 100
        }
    }

    /// Re-writes the PDF with Ghostscript at the level's image resolution.
    /// Returns nil when the level keeps images, Ghostscript isn't there, or
    /// the result isn't smaller — then the PDF goes on as it was.
    private static func downsampleImages(input: URL, mode: PDFCompressionMode, workDir: URL) throws -> URL? {
        guard let dpi = imageResolution(for: mode), let gs = Toolchain.locate("gs") else { return nil }
        let output = workDir.appendingPathComponent("downsampled.pdf")
        let result = try ProcessRunner.runWithStatus(gs, [
            "-q", "-dNOPAUSE", "-dBATCH", "-dSAFER",
            "-sDEVICE=pdfwrite",
            "-dPDFSETTINGS=/ebook",
            "-dCompatibilityLevel=1.7",
            "-dDetectDuplicateImages=true",
            "-dPreserveAnnots=true",
            "-dDownsampleColorImages=true", "-dColorImageDownsampleType=/Bicubic",
            "-dColorImageResolution=\(dpi)", "-dColorImageDownsampleThreshold=1.2",
            "-dDownsampleGrayImages=true", "-dGrayImageDownsampleType=/Bicubic",
            "-dGrayImageResolution=\(dpi)", "-dGrayImageDownsampleThreshold=1.2",
            "-dDownsampleMonoImages=true", "-dMonoImageResolution=300",
            "-sOutputFile=\(output.path)",
            input.path
        ])
        let bytes = FileSniffer.fileSize(url: output)
        guard result.status == 0, bytes > 0, bytes < FileSniffer.fileSize(url: input) else { return nil }
        return output
    }

    private static func compressMaximumRaster(
        document: PDFDocument,
        output: URL,
        cancellation: CancellationToken?
    ) throws {
        guard let consumer = CGDataConsumer(url: output as CFURL) else {
            throw CompressionError.message("Stou could not create the output PDF.")
        }
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
            throw CompressionError.message("Stou could not create the output PDF context.")
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
            throw CompressionError.message("Stou could not compress a PDF page.")
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
            throw CompressionError.message("Stou could not render a PDF page.")
        }

        NSGraphicsContext.saveGraphicsState()
        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw CompressionError.message("Stou could not render a PDF page.")
        }
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: NSSize(width: pixelWidth, height: pixelHeight))).fill()
        let cg = graphics.cgContext
        cg.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: cg)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
            throw CompressionError.message("Stou could not encode a PDF page.")
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
            throw CompressionError.message("Stou could not verify the compressed PDF.")
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
