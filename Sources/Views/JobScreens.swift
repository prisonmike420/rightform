import SwiftUI

// The steps after choosing what to do: a progress screen while plugins are
// checked or installed and files are prepared, then a done screen.

/// Progress as a short checklist: plugins, any check that runs first, then
/// the files themselves with a progress bar and Stop.
struct JobProgressScreen: View {
    @Environment(CompressionModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            ScreenHeading(
                title: model.jobTitle,
                subtitle: model.items.count == 1 ? "1 file" : "\(model.items.count) files"
            )

            VStack(alignment: .leading, spacing: 12) {
                if model.preparingPlugins.isEmpty {
                    ChecklistStep(title: "Ready", state: .done)
                } else {
                    ChecklistStep(
                        title: "Installing " + model.preparingPlugins.map(\.title).joined(separator: " and "),
                        detail: "This may take a few minutes.",
                        state: .active
                    )
                }
                if model.isCheckingAILabels {
                    ChecklistStep(title: "Checking for AI labels", state: .active)
                }
                if model.aiLabelDecisionPending {
                    ChecklistStep(title: "Waiting for your answer about AI labels", state: .active)
                }
                if model.isPreflightingPDF {
                    ChecklistStep(
                        title: "Reading PDFs",
                        detail: "\(model.pdfPreflightCompletedCount) of \(model.pdfPreflightTotalCount)",
                        state: .active
                    )
                }
                ChecklistStep(
                    title: model.isProcessing
                        ? "Preparing \(model.batchProgress.completed) of \(model.batchProgress.total)"
                        : "Preparing files",
                    state: model.isProcessing ? .active : .pending
                )
            }
            .frame(width: Design.Layout.contentColumnWidth, alignment: .leading)

            if model.isProcessing {
                ProgressView(value: model.batchProgress.fraction)
                    .frame(width: Design.Layout.contentColumnWidth)
                Button(model.isCancelling ? "Stopping" : "Stop") { model.cancelBatch() }
                    .disabled(model.isCancelling)
            } else if model.canCancelPreparation {
                // Nothing is written yet, so this only goes back a step.
                Button("Cancel") { model.cancelPreparation() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Design.Layout.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The done screen: how many files are ready, what was saved and where, and
/// what next — Show in Finder or a new task.
struct JobDoneScreen: View {
    @Environment(CompressionModel.self) private var model

    private var ready: Int { model.optimizedCount + model.unchangedCount }
    private var total: Int { model.batchProgress.total }
    private var allReady: Bool { ready == total }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: allReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(allReady ? Design.Status.success : Design.Status.warning)
                .accessibilityHidden(true)

            ScreenHeading(
                title: allReady
                    ? (ready == 1 ? "1 file ready" : "\(ready) files ready")
                    : "\(ready) of \(total) ready",
                subtitle: model.jobTitle
            )

            VStack(spacing: 2) {
                if model.totalSavedBytes > 0 {
                    Text("\(formatBytes(model.totalSavedBytes)) smaller · −\(model.totalSavingsPercent)%")
                        .monospacedDigit()
                } else if ready > 0 {
                    Text("They were already as light as they can be.")
                }
                if ready > 0 {
                    Text(model.resultLocation)
                }
                if model.failedCount > 0 {
                    Text(model.failedCount == 1 ? "1 file couldn’t be prepared." : "\(model.failedCount) files couldn’t be prepared.")
                        .foregroundStyle(Design.Status.warning)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if model.failedCount > 0 || model.batchProgress.cancelled > 0 {
                Button("Show Details") { model.showsResultList = true }
                    .buttonStyle(.link)
            }

            HStack(spacing: 10) {
                if model.delivery == .share, !model.shareURLs.isEmpty {
                    // Sharing is the delivery itself, so it leads.
                    Button("New Task") { model.dismissResult() }
                    ShareLink(items: model.shareURLs) {
                        Text("Share…")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Show in Finder") { model.revealResults() }
                        .disabled(!model.hasRevealableResults)
                    Button("New Task") { model.dismissResult() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding(Design.Layout.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The AI label check's result: per file, what was found, and that pixel
/// watermarks can't be seen. Nothing has been written; labels can be removed
/// from here.
struct LabelReportScreen: View {
    @Environment(CompressionModel.self) private var model

    var body: some View {
        let checked = model.items.filter { $0.aiLabels != nil }
        let labelled = checked.filter(\.hasAILabels)

        Form {
            Section {
                ForEach(model.items) { item in
                    HStack(spacing: 12) {
                        FileCover(url: item.url)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(item.aiLabels.map { $0.isEmpty ? "No AI labels" : "AI labels found" } ?? "Can’t be checked")
                                .font(.callout)
                                .foregroundStyle(item.hasAILabels ? AnyShapeStyle(Design.Status.warning) : AnyShapeStyle(.secondary))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: item.hasAILabels ? "sparkles" : "checkmark.circle")
                            .foregroundStyle(item.hasAILabels ? AnyShapeStyle(Design.Status.warning) : AnyShapeStyle(.secondary))
                            .accessibilityHidden(true)
                    }
                    .help(item.aiLabels?.findings.joined(separator: "\n") ?? "")
                }
            } header: {
                Text(labelled.isEmpty
                     ? "No AI labels found"
                     : (labelled.count == 1 ? "1 file has AI labels" : "\(labelled.count) files have AI labels"))
            } footer: {
                Text("Hidden watermarks inside the image, like SynthID, can’t be detected. Your files weren’t changed.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormButtonBar {
                if model.canGoBackFromLabelReport {
                    Button("Back") { model.backFromLabelReport() }
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                if !labelled.isEmpty {
                    Button("Remove Labels") { model.removeReportedLabels() }
                }
                Button("New Task") { model.dismissResult() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
