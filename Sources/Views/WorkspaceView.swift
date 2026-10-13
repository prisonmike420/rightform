import SwiftUI
import AppKit

struct WorkspaceView: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions

    /// The bar is for decisions on the file list: AI labels, a PDF estimate,
    /// a waiting Start, or the list behind a done screen.
    private var batchBarVisible: Bool {
        !model.isWorking && (
            model.pdfEstimateVisible ||
            (model.hasWaitingFiles && !model.needsRoutine) ||
            (model.resultDrawerVisible && model.showsResultList)
        )
    }

    var body: some View {
        Group {
            // Drop → choose → progress → done, one screen at a time.
            if model.items.isEmpty {
                emptyState
            } else if model.labelReportVisible {
                LabelReportScreen()
            } else if model.awaitingDelivery {
                WhereToScreen()
            } else if model.needsRoutine {
                HomeWizard()
            } else if model.isWorking {
                JobProgressScreen()
            } else if model.resultDrawerVisible && !model.showsResultList && !model.hasWaitingFiles {
                JobDoneScreen()
            } else {
                FileListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { if model.isDropTargeted { DropHighlight() } }
        // Asked once, without holding anything up; the answer is remembered.
        .overlay(alignment: .top) {
            if model.aiLabelDecisionPending {
                AILabelNotice()
                    .padding(Design.Layout.overlayPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Design.Motion.standard, value: model.aiLabelDecisionPending)
        // Along the top, never at the window's bottom edge (HIG, Layout).
        .safeAreaBar(edge: .top, spacing: 0) {
            if batchBarVisible {
                BatchBar()
                    .padding(Design.Layout.overlayPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Design.Motion.standard, value: batchBarVisible)
    }

    /// The empty window itself is the drop target: no card, just a centred
    /// hint. In a plugin's workspace it names that plugin's job and formats;
    /// at Home, routines are offered once files are dropped. While files are dragged over, the
    /// hint takes the accent colour and the window shows the drop highlight.
    /// A click on the background opens the picker.
    private var emptyState: some View {
        let targeted = model.isDropTargeted

        return VStack(spacing: 8) {
            Image(systemName: model.tool?.symbolName ?? model.routine?.symbolName ?? "tray.and.arrow.down")
                .font(.title)
                .fontWeight(.light)
                .symbolEffect(.bounce, value: targeted)
                .padding(.bottom, 4)
            if let tool = model.tool {
                Text(tool.dropTitle)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(tool.dropHint)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let routine = model.routine {
                Text("Drop files to \(routine.title.lowercasedFirst)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(routine.summary(canRemoveDetails: extensions.state(for: .metadataCleaner).isInstalled))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Drop files here")
                    .font(.headline)
                Text("Then choose what to do with them")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Design.Layout.screenPadding)
        .foregroundStyle(targeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .animation(Design.Motion.hint, value: targeted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.pickFiles() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Drop files or choose files")
    }
}

extension String {
    /// "remove hidden details" → "Remove hidden details", for a title.
    var uppercasedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// "Send in a chat" → "send in a chat", for use inside a sentence.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

/// A notice, not a blocker: files have AI labels; keep or remove them. The
/// answer is remembered in AI Provenance’s settings and applied by itself next time.
private struct AILabelNotice: View {
    @Environment(CompressionModel.self) private var model

    var body: some View {
        let count = model.items.filter(\.hasAILabels).count

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(count == 1 ? "1 file has AI labels" : "\(count) files have AI labels")
                    .font(.headline)
                Text("Some sites require them. We’ll remember your choice.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Design.Layout.buttonSpacing) {
                    Button("Remove") { model.removeAILabels() }
                        .buttonStyle(.glass)
                    Button("Keep") { model.keepAILabels() }
                        .buttonStyle(.glassProminent)
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: Design.Layout.noticeMaxWidth)
        .glassSurface(minimumRadius: Design.Radius.panel)
    }
}

// MARK: - File list

struct FileListView: View {
    @Environment(CompressionModel.self) private var model

    var body: some View {
        List(model.items) { item in
            FileRow(item: item)
                .contextMenu {
                    Button("Show Original in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    }
                    if case .done = item.state, let output = item.outputURL {
                        Button("Show Result in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([output])
                        }
                    }
                }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}

struct FileRow: View {
    let item: CompressionItem

    var body: some View {
        HStack(spacing: 12) {
            FileCover(url: item.url)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.url.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(isFailure ? AnyShapeStyle(Design.Status.failure) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let aiLabelText {
                    Label(aiLabelText, systemImage: item.aiLabelsLost ? "exclamationmark.triangle" : "sparkles")
                        .font(.caption)
                        .foregroundStyle(item.aiLabelsLost ? AnyShapeStyle(Design.Status.warning) : AnyShapeStyle(.secondary))
                        .help(item.aiLabels?.findings.joined(separator: "\n") ?? "")
                }
            }

            Spacer(minLength: 8)

            status
        }
        .padding(.vertical, 4)
        .help(errorMessage ?? "")
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        switch item.state {
        case .squeezing, .analyzing:
            ProgressView().controlSize(.small)
        case .done where item.differencePercent > 0:
            // The reduction, at a glance.
            Text("−\(item.differencePercent)%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        case .done, .dry:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Design.Status.success)
                .accessibilityLabel("Done")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Design.Status.failure)
                .accessibilityLabel("Failed")
        case .cancelled:
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Cancelled")
        case .queued:
            EmptyView()
        }
    }

    private var aiLabelText: String? {
        guard let labels = item.aiLabels, !labels.isEmpty else { return nil }
        if item.removeAILabels {
            if case .done = item.state { return "AI labels removed" }
            return "AI labels will be removed"
        }
        if item.aiLabelsLost { return "AI labels were not preserved by re-encoding" }
        return labels.summary
    }

    private var isFailure: Bool {
        if case .failed = item.state { return true }
        return false
    }

    private var errorMessage: String? {
        if case .failed(let message) = item.state { return message }
        return nil
    }

    private var detailText: String {
        switch item.state {
        case .done:
            if let output = item.outputBytes {
                if output == item.originalBytes {
                    return "Already light · copy saved"
                }
                return "\(formatBytes(item.originalBytes)) → \(formatBytes(output))"
            }
            return formatBytes(item.originalBytes)
        case .dry:
            return "Already light"
        case .failed(let message):
            let firstLine = message
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return firstLine
        case .cancelled:
            return "Cancelled"
        case .squeezing:
            return "Preparing…"
        case .analyzing:
            return item.format == .pdf ? "Reading…" : formatBytes(item.originalBytes)
        case .queued:
            if item.format == .pdf, let estimate = item.estimatedBytes {
                var detail = "\(formatBytes(item.originalBytes)) → ~\(formatBytes(estimate))"
                if !item.pdfExactDuplicatePages.isEmpty {
                    detail += " · \(item.pdfExactDuplicatePages.count) repeated pages"
                }
                if !item.pdfSimilarPairs.isEmpty {
                    detail += " · \(item.pdfSimilarPairs.count) similar"
                }
                return detail
            }
            return formatBytes(item.originalBytes)
        }
    }
}

// MARK: - Batch bar

struct BatchBar: View {
    @Environment(CompressionModel.self) private var model

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
                actions
            }

            if let progress = progressValue {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(minimumRadius: Design.Radius.bar)
    }

    @ViewBuilder
    private var actions: some View {
        if !model.preparingPlugins.isEmpty {
            ProgressView().controlSize(.small)
        } else if model.isCheckingAILabels {
            ProgressView().controlSize(.small)
        } else if model.isPreflightingPDF {
            Button("Skip Estimate") { model.skipPDFEstimate() }
                .buttonStyle(.glass)
        } else if model.isProcessing {
            Button(model.isCancelling ? "Stopping" : "Stop") { model.cancelBatch() }
                .buttonStyle(.glass)
                .disabled(model.isCancelling)
        } else if model.pdfEstimateVisible {
            HStack(spacing: Design.Layout.buttonSpacing) {
                Button("Back") { model.backFromPDFEstimate() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                if model.hasPDFSimilarPairs {
                    Button("Review…") { model.beginPDFSimilarReview() }
                        .buttonStyle(.glass)
                }
                Button(model.estimatedPDFCount > 1 ? "Prepare All" : "Prepare") {
                    model.startEstimatedBatch()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
        } else if model.hasWaitingFiles {
            Button("Start") { model.requestStart() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
        } else {
            HStack(spacing: Design.Layout.buttonSpacing) {
                // The list came from Show Details on the done screen.
                if model.showsResultList {
                    Button("Back") { model.hideResultList() }
                        .buttonStyle(.glass)
                        .keyboardShortcut(.cancelAction)
                }
                Button("Show in Finder") { model.revealResults() }
                    .buttonStyle(.glass)
                    .disabled(!model.hasRevealableResults)
                Button("Done") { model.dismissResult() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var title: String {
        if !model.preparingPlugins.isEmpty {
            return "Installing " + model.preparingPlugins.map(\.title).joined(separator: " and ")
        }
        if model.isCheckingAILabels {
            return "Checking for AI labels…"
        }
        if model.isPreflightingPDF {
            return "Analyzing \(model.pdfPreflightCompletedCount) of \(model.pdfPreflightTotalCount)"
        }
        if model.isProcessing {
            return model.isCancelling
                ? "Stopping…"
                : "Processing \(model.batchProgress.completed) of \(model.batchProgress.total)"
        }
        if model.pdfEstimateVisible {
            return model.estimatedPDFCount == 1 ? "PDF ready" : "\(model.estimatedPDFCount) PDFs ready"
        }
        if model.hasWaitingFiles {
            return model.queuedCount == 1 ? "1 file waiting" : "\(model.queuedCount) files waiting"
        }
        return "\(formatBytes(model.totalSavedBytes)) smaller"
    }

    private var subtitle: String {
        if !model.preparingPlugins.isEmpty {
            return "Your files are prepared right after."
        }
        if model.isCheckingAILabels {
            return "Content Credentials and AI metadata"
        }
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
            var parts = ["\(original) → ~\(estimated)", "−\(max(0, percent))%"]
            if model.pdfExactDuplicateCount > 0 {
                parts.append("\(model.pdfExactDuplicateCount) repeated pages")
            }
            if model.pdfSimilarPairCount > 0 {
                parts.append("\(model.pdfSimilarPairCount) similar")
            }
            return parts.joined(separator: " · ")
        }

        if model.hasWaitingFiles {
            return model.resultLocation
        }

        var parts: [String] = []
        if model.optimizedCount > 0 { parts.append("\(model.optimizedCount) lighter") }
        if model.unchangedCount > 0 { parts.append("\(model.unchangedCount) already light") }
        if model.failedCount > 0 { parts.append("\(model.failedCount) couldn’t be prepared") }
        if model.batchProgress.cancelled > 0 { parts.append("\(model.batchProgress.cancelled) cancelled") }
        if model.totalSavingsPercent > 0 { parts.append("−\(model.totalSavingsPercent)%") }
        return parts.isEmpty ? "No files changed" : parts.joined(separator: " · ")
    }

    private var progressValue: Double? {
        if model.isCheckingAILabels { return nil }
        if model.isPreflightingPDF { return model.pdfPreflightFraction }
        if model.isProcessing { return model.batchProgress.fraction }
        return nil
    }
}

// MARK: - PDF review

struct PDFDuplicateReviewView: View {
    @Environment(CompressionModel.self) private var model
    let itemID: UUID

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(pairs) { pair in
                        Toggle(isOn: Binding(
                            get: { model.isSimilarPageSelected(itemID: itemID, pageIndex: pair.secondPage) },
                            set: { model.setSimilarPageSelected(itemID: itemID, pageIndex: pair.secondPage, selected: $0) }
                        )) {
                            Text("Remove page \(pair.secondPage + 1)")
                            Text("\(Int((pair.similarity * 100).rounded()))% similar to page \(pair.firstPage + 1)")
                        }
                        // Choosing items to act on is a checkbox on macOS; a switch
                        // is for a setting that takes effect at once.
                        .toggleStyle(.checkbox)
                    }
                } footer: {
                    Text("Similar pages are never removed unless you select them here.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Similar Pages")
            .navigationSubtitle(fileName)
            .toolbar {
                // Done is paired with Cancel, which keeps the pages chosen before.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancelPDFSimilarReview() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.finishPDFSimilarReview() }
                }
            }
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 320, idealHeight: 480)
    }

    private var item: CompressionItem? { model.items.first(where: { $0.id == itemID }) }
    private var pairs: [PDFSimilarPair] { item?.pdfSimilarPairs ?? [] }
    private var fileName: String { item?.url.lastPathComponent ?? "PDF" }
}
