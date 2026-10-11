import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
