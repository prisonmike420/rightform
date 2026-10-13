import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

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
    private let state = State<NSImage?>(initialValue: nil) // See PluginDetailView.

    var body: some View {
        Group {
            if let image = state.wrappedValue {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "doc")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: url) {
            state.wrappedValue = await ThumbnailCache.shared.thumbnail(for: url)
        }
        .onDisappear { state.wrappedValue = nil }
    }
}
