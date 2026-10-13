import SwiftUI
import AppKit

/// Every state a workspace's work zone can be in — Home's or a plugin's —
/// with one screen each, in the order a job goes through them: drop,
/// choose, where to, the file list while it works, done. The first that
/// applies wins.
enum WorkspaceScreen {
    /// Nothing dropped yet: a centred hint (StatusScreen).
    case empty
    /// The AI label check's result (FormScreen with Back and New Task).
    case labelReport
    /// Where the results go (FormScreen with Back and Start).
    case whereTo
    /// What to do with the files, at Home (FormScreen).
    case choose
    /// How the batch went (StatusScreen).
    case done
    /// The files themselves, with the batch bar: while plugins install,
    /// labels are checked and files are prepared, and for what's left
    /// afterwards (ListScreen).
    case fileList

    @MainActor init(_ model: CompressionModel) {
        if model.items.isEmpty { self = .empty }
        else if model.labelReportVisible { self = .labelReport }
        else if model.awaitingDelivery { self = .whereTo }
        else if model.needsRoutine { self = .choose }
        else if model.resultDrawerVisible && !model.showsResultList && !model.hasWaitingFiles { self = .done }
        else { self = .fileList }
    }
}

/// A workspace's work zone: the screen for its state inside a
/// WorkZoneShell, with the AI label notice and the batch bar.
struct WorkspaceView: View {
    @Environment(CompressionModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions

    /// The bar is the job's progress — plugins installing, labels being
    /// checked, PDFs read, files prepared — and the decisions on the file
    /// list: a PDF estimate, a waiting Start, or the list behind a done
    /// screen. While an answer about AI labels is awaited, the notice asks
    /// instead.
    private var batchBarVisible: Bool {
        guard !model.aiLabelDecisionPending else { return false }
        return model.isWorking ||
            model.pdfEstimateVisible ||
            (model.hasWaitingFiles && !model.needsRoutine) ||
            (model.resultDrawerVisible && model.showsResultList)
    }

    var body: some View {
        WorkZoneShell(
            isDropTargeted: model.isDropTargeted,
            showsBar: batchBarVisible,
            // Asked once, without holding anything up; the answer is remembered.
            showsNotice: model.aiLabelDecisionPending
        ) {
            switch WorkspaceScreen(model) {
            case .empty: emptyState
            case .labelReport: LabelReportScreen()
            case .whereTo: WhereToScreen()
            case .choose: HomeWizard()
            case .done: JobDoneScreen()
            case .fileList: FileListView()
            }
        } bar: {
            BatchBar()
        } notice: {
            AILabelNotice()
        }
    }

    /// The empty window itself is the drop target: no card, just a centred
    /// hint. In a plugin's workspace it names that plugin's job and formats;
    /// at Home, routines are offered once files are dropped. While files are dragged over, the
    /// hint takes the accent colour and the window shows the drop highlight.
    /// A click on the background opens the picker.
    private var emptyState: some View {
        let targeted = model.isDropTargeted

        return StatusScreen(spacing: 8) {
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
        .foregroundStyle(targeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .animation(Design.Motion.hint, value: targeted)
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
        ListScreen {
            ForEach(model.items) { item in
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
        }
    }
}

/// One file, the same row everywhere a file is listed — Home, the file
/// list, the done screen: its cover, name and size or result, and at the
/// end its state: how much smaller, done, failed. A waiting file can have
/// a button to take it off the list.
struct FileRow: View {
    let item: CompressionItem
    /// Takes the file off the list; Home's files have it.
    var onRemove: (() -> Void)?

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
        // The remove button stays a button of its own for VoiceOver.
        .accessibilityElement(children: onRemove == nil ? .combine : .contain)
    }

    @ViewBuilder
    private var status: some View {
        switch item.state {
        case .squeezing, .analyzing:
            ProgressView().controlSize(.small)
        case .done where item.differencePercent > 0:
            // The reduction, at a glance.
            SavingsBadge(percent: item.differencePercent)
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
            if let onRemove {
                RowIconButton(
                    systemImage: "xmark.circle.fill",
                    label: "Remove \(item.url.lastPathComponent)",
                    tint: AnyShapeStyle(.secondary),
                    action: onRemove
                )
            }
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
            return "\(item.format.rawValue) · \(formatBytes(item.originalBytes))"
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
        if !model.preparingPlugins.isEmpty || model.isCheckingAILabels {
            // Nothing is written yet, so Cancel only goes back a step.
            HStack(spacing: Design.Layout.buttonSpacing) {
                ProgressView().controlSize(.small)
                Button("Cancel") { model.cancelPreparation() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
            }
        } else if model.isPreflightingPDF {
            HStack(spacing: Design.Layout.buttonSpacing) {
                Button("Cancel") { model.cancelPreparation() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("Skip Estimate") { model.skipPDFEstimate() }
                    .buttonStyle(.glass)
            }
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
                : "Preparing \(model.batchProgress.completed) of \(model.batchProgress.total)"
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
            FormScreen {
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
