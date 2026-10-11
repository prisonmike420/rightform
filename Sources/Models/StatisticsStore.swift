import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

// MARK: - Statistics

@MainActor
@Observable
final class StatisticsStore {
    @ObservationIgnored private let defaults = UserDefaults.standard

    private(set) var totalBytesSaved: Int64
    private(set) var totalFilesOptimized: Int
    private(set) var installedAt: Date

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

