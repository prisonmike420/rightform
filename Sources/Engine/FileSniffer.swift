import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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
