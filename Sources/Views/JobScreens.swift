import SwiftUI

// The screens after a job: the done screen, and the AI label check's
// report. While a job runs, the work zone shows the files and the batch
// bar their progress.

/// The done screen: how many files are ready, what was saved and where, the
/// files themselves with how much smaller each got, and what next — Show in
/// Finder or a new task.
struct JobDoneScreen: View {
    @Environment(CompressionModel.self) private var model

    private var ready: Int { model.optimizedCount + model.unchangedCount }
    private var total: Int { model.batchProgress.total }
    private var allReady: Bool { ready == total }
    /// How many files the screen lists before Show All.
    private static let fileRowsShown = 4

    private var readyItems: [CompressionItem] {
        model.items.filter {
            switch $0.state {
            case .done, .dry: return true
            default: return false
            }
        }
    }

    var body: some View {
        StatusScreen(spacing: 14) {
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

            if !readyItems.isEmpty {
                RowGroup {
                    ForEach(readyItems.prefix(Self.fileRowsShown)) { item in
                        FileRow(item: item)
                    }
                }
                .frame(maxWidth: Design.Layout.resultListWidth)
            }

            // The whole list, with what failed or was cancelled.
            if readyItems.count > Self.fileRowsShown || model.failedCount > 0 || model.batchProgress.cancelled > 0 {
                Button(readyItems.count > Self.fileRowsShown ? "Show All \(total) Files" : "Show Details") {
                    model.showsResultList = true
                }
                .buttonStyle(.link)
            }

            HStack(spacing: Design.Layout.buttonSpacing) {
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

        FormScreen {
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
        } actions: {
            Spacer()
            if model.canGoBackFromLabelReport {
                Button("Back") { model.backFromLabelReport() }
                    .keyboardShortcut(.cancelAction)
            }
            if !labelled.isEmpty {
                Button("Remove Labels") { model.removeReportedLabels() }
            }
            Button("New Task") { model.dismissResult() }
                .keyboardShortcut(.defaultAction)
        }
    }
}
