import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import ImageIO
import CoreGraphics
import PDFKit

// MARK: - Model

@MainActor
@Observable
final class CompressionModel {
    var items: [CompressionItem] = []
    var isDropTargeted = false
    var isProcessing = false
    var isCancelling = false
    var alertMessage: String?
    var showReplaceConfirmation = false
    var resultDrawerVisible = false
    var isPreflightingPDF = false
    var pdfEstimateVisible = false
    var pdfReviewItemID: UUID?
    /// The pages chosen when the review opened, for Cancel.
    @ObservationIgnored private var pdfReviewSnapshot: Set<Int> = []
    var isCheckingAILabels = false
    /// Files with AI labels wait here until the user keeps or removes them.
    var aiLabelDecisionPending = false
    private(set) var batchProgress = BatchProgress()

    let settings: AppSettings
    let stats: StatisticsStore

    private var processingTask: Task<Void, Never>?
    private var pdfPreflightTask: Task<Void, Never>?
    private var cancellationToken: CancellationToken?

    /// Installs plugins the chosen action needs. Set by the app at launch.
    @ObservationIgnored var extensions: ExtensionManager?

    init(settings: AppSettings, stats: StatisticsStore) {
        self.settings = settings
        self.stats = stats
    }

    var queuedCount: Int { items.filter { $0.state == .queued }.count }

    /// Files added but not started, with nothing else in progress or asking:
    /// for example after Cancel in the replace-originals dialog.
    var hasWaitingFiles: Bool {
        queuedCount > 0 && !isProcessing && !isCheckingAILabels && !aiLabelDecisionPending &&
        !isPreflightingPDF && !pdfEstimateVisible && preparingPlugins.isEmpty && !awaitingDelivery
    }

    /// What the files are for. Without one, added files wait: nothing is
    /// processed until the user says what comes next.
    private(set) var routine: Routine?

    /// The plugin whose workspace is open, if any. It replaces routines: files
    /// dropped there get that plugin's one job.
    private(set) var tool: ExtensionID?

    /// Files are waiting for a routine to be chosen.
    /// Home is asking what to do. A pending AI-label question shows over it.
    var needsRoutine: Bool {
        queuedCount > 0 && !isProcessing && !isCheckingAILabels && !isPreflightingPDF && !pdfEstimateVisible &&
        preparingPlugins.isEmpty && routine == nil && tool == nil && !labelReportVisible && !awaitingDelivery
    }

    // MARK: AI label check

    /// The check-only job: files are inspected for AI labels and a report is
    /// shown; nothing is written unless labels are then removed.
    private(set) var labelReportVisible = false
    private var labelCheckRequested = false
    private var labelRemovalRequested = false

    /// Forgets the last job's destination and choices; each job asks again.
    private func resetJob() {
        delivery = nil
        trashOriginals = false
        awaitingDelivery = false
        pendingAction = nil
        shareURLs = []
    }

    private func checkLabelsOnly() {
        labelCheckRequested = true
        let ids = items.filter { $0.state == .queued && $0.aiLabels == nil }.map(\.id)
        if ids.isEmpty { continueAfterAdding() } else { checkAILabels(of: ids) }
    }

    /// Back from the report at Home: to the choice of what to do with the
    /// files, which the check left as they were. In AI Provenance's
    /// workspace the step before is the empty window, which New Task is.
    var canGoBackFromLabelReport: Bool { labelReportVisible && tool == nil }

    func backFromLabelReport() {
        guard canGoBackFromLabelReport else { return }
        labelReportVisible = false
        labelCheckRequested = false
        continueAfterAdding()
    }

    /// From the report: remove the labels found, with AI Provenance's job.
    func removeReportedLabels() {
        guard labelReportVisible else { return }
        markAILabelsForRemoval()
        labelRemovalRequested = true
        labelReportVisible = false
        if tool == nil {
            tool = .aiProvenance
            toolIsForThisBatch = true
        }
        continueAfterAdding()
    }

    // MARK: Estimates at Home

    /// Estimated total size of the waiting PDFs per level, for the wizard.
    private(set) var pdfEstimates: [PDFCompressionMode: Int64] = [:]
    /// The trial runs are still going; the wizard shows a spinner meanwhile.
    private(set) var isEstimating = false
    @ObservationIgnored private var estimateTask: Task<Void, Never>?

    var waitingPDFBytes: Int64 {
        items.filter { $0.state == .queued && $0.format == .pdf }.reduce(0) { $0 + $1.originalBytes }
    }

    /// Only for PDFs, and only once PDF Tools can make them: the estimate
    /// is a real trial run, so the wizard's numbers are what will happen.
    private func estimateForHome() {
        estimateTask?.cancel()
        pdfEstimates = [:]
        isEstimating = false
        let pdfs = items.filter { $0.state == .queued }
        guard !pdfs.isEmpty, pdfs.allSatisfy({ $0.format == .pdf }), CapabilityResolver.canProcess(.pdf) else { return }
        isEstimating = true
        let work = pdfs.map { ($0.url, $0.originalBytes) }
        let modes = Array(Set<PDFCompressionMode>([.light, .balanced, .aggressive, settings.pdfCompressionMode]))
        estimateTask = Task { [weak self] in
            for mode in modes {
                let total = await Task.detached(priority: .utility) {
                    work.reduce(Int64(0)) { sum, file in
                        let report = try? PDFTools.preflight(
                            input: file.0, originalBytes: file.1, mode: mode,
                            duplicateMode: .off, removeExactDuplicates: false
                        )
                        return sum + (report?.estimatedBytes ?? file.1)
                    }
                }.value
                guard !Task.isCancelled, let self else { return }
                self.pdfEstimates[mode] = total
            }
            self?.isEstimating = false
        }
    }

    /// Plugins being installed for the action chosen at Home; it runs when
    /// they are ready.
    private(set) var preparingPlugins: [ExtensionID] = []

    /// What Home can do with the waiting files.
    enum HomeAction: Hashable {
        case routine(Routine)
        case tool(ExtensionID)
        case checkLabels
    }

    /// Runs the chosen action. Plugins it needs — for the files' formats, or
    /// the plugin itself — are installed first, without asking again.
    func start(_ action: HomeAction) {
        guard !isProcessing, preparingPlugins.isEmpty, tool == nil else { return }
        // Checking labels writes nothing, so it needs no destination.
        guard action != .checkLabels else {
            proceed(action)
            return
        }
        pendingAction = action
        askWhereTo()
    }

    // MARK: Where to?

    /// The job is chosen and waits for its destination.
    private(set) var awaitingDelivery = false
    /// What Where to? has selected; it starts fresh for every job.
    var deliveryChoice: Delivery = .nextToOriginals
    var trashChoice = false
    /// This job's destination and whether its originals go to the Trash.
    private(set) var delivery: Delivery?
    private(set) var trashOriginals = false
    private var pendingAction: HomeAction?

    private func askWhereTo() {
        deliveryChoice = .nextToOriginals
        trashChoice = false
        awaitingDelivery = true
    }

    /// Where to? confirmed: the job goes on with this destination.
    func confirmDelivery() {
        guard awaitingDelivery else { return }
        delivery = deliveryChoice
        trashOriginals = trashChoice && deliveryChoice.canTrashOriginals
        awaitingDelivery = false
        if let action = pendingAction {
            pendingAction = nil
            proceed(action)
        } else {
            continueAfterAdding()
        }
    }

    /// Back from Where to?: to the choice of job, the label report, or, in a
    /// plugin's workspace, to an empty one.
    func cancelDelivery() {
        guard awaitingDelivery else { return }
        awaitingDelivery = false
        if pendingAction != nil {
            pendingAction = nil
        } else if labelRemovalRequested {
            labelRemovalRequested = false
            labelReportVisible = true
            for index in items.indices { items[index].removeAILabels = false }
            if toolIsForThisBatch { tool = nil; toolIsForThisBatch = false }
        } else {
            clearAll()
        }
    }

    /// Back to Where to? from a later step that hasn't written anything yet:
    /// the job chosen at Home is chosen again there, and the destination
    /// picked before stays selected.
    private func returnToWhereTo() {
        if toolIsForThisBatch, let tool {
            pendingAction = .tool(tool)
            self.tool = nil
            toolIsForThisBatch = false
        } else if tool == nil, let routine {
            pendingAction = .routine(routine)
            self.routine = nil
        }
        deliveryChoice = delivery ?? .nextToOriginals
        trashChoice = trashOriginals
        delivery = nil
        trashOriginals = false
        awaitingDelivery = true
    }

    /// Before any file is prepared, the progress screen's Cancel goes back a
    /// step: installing plugins or reading PDFs back to Where to?; checking
    /// labels back to the choice at Home, or to the empty window when files
    /// were only just added.
    var canCancelPreparation: Bool {
        !isProcessing && (!preparingPlugins.isEmpty || isPreflightingPDF || isCheckingAILabels)
    }

    func cancelPreparation() {
        guard canCancelPreparation else { return }
        if !preparingPlugins.isEmpty {
            // The install's own task takes the job back once it stops.
            preparationCancelled = true
            for id in preparingPlugins { extensions?.cancelInstall(id) }
        } else if isPreflightingPDF {
            pdfPreflightTask?.cancel()
            pdfPreflightTask = nil
            isPreflightingPDF = false
            resetPDFEstimates()
            returnToWhereTo()
        } else if labelCheckRequested && tool == nil {
            jobGeneration += 1
            isCheckingAILabels = false
            labelCheckRequested = false
            continueAfterAdding()
        } else {
            clearAll()
        }
    }

    /// Set by Cancel while plugins install; the job goes back to Where to?.
    private var preparationCancelled = false

    /// Changes whenever the job is abandoned, so work still finishing in the
    /// background doesn't carry on with it.
    private var jobGeneration = 0

    /// The chosen job, once it has a destination: installs what it needs,
    /// then runs it.
    private func proceed(_ action: HomeAction) {
        // Checking labels reads files as they are; it needs only its plugin.
        var needed = action == .checkLabels ? [] : pluginsNeededForWaitingFiles
        let own: ExtensionID? = switch action {
        case .tool(let id): id
        case .checkLabels: .aiProvenance
        case .routine: nil
        }
        if let own, !(extensions?.state(for: own).isInstalled ?? false), !needed.contains(own) {
            needed.append(own)
        }
        guard !needed.isEmpty, let extensions else {
            perform(action)
            return
        }
        preparingPlugins = needed
        for id in needed where !extensions.state(for: id).isInstalled {
            extensions.install(id)
        }
        Task { [weak self] in
            while let self, self.preparingPlugins.contains(where: { extensions.state(for: $0).isBusy }) {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard let self else { return }
            let failed = self.preparingPlugins.filter { !extensions.state(for: $0).isInstalled }
            self.preparingPlugins = []
            if self.preparationCancelled {
                self.preparationCancelled = false
                // A label check had no Where to?; it goes back to the choice.
                guard action != .checkLabels else { return }
                self.pendingAction = action
                self.deliveryChoice = self.delivery ?? .nextToOriginals
                self.trashChoice = self.trashOriginals
                self.delivery = nil
                self.trashOriginals = false
                self.awaitingDelivery = true
            } else if let first = failed.first {
                var message = "Couldn’t install \(first.title)."
                if case .failed(let reason) = extensions.state(for: first) { message += " \(reason)" }
                self.alertMessage = message
            } else {
                self.perform(action)
            }
        }
    }

    private func perform(_ action: HomeAction) {
        switch action {
        case .routine(let routine): choose(routine)
        case .tool(let id): run(id)
        case .checkLabels: checkLabelsOnly()
        }
    }

    /// Anything running that the progress screen shows: installing plugins,
    /// checking labels, analysing PDFs or preparing files.
    var isWorking: Bool {
        !preparingPlugins.isEmpty || isCheckingAILabels || isPreflightingPDF || isProcessing ||
        (aiLabelDecisionPending && (routine != nil || tool != nil))
    }

    /// The job, as the progress and done screens name it.
    var jobTitle: String {
        // On Where to?, the job chosen but not started yet.
        switch pendingAction {
        case .routine(let routine): return routine.title
        case .tool(let id): return id.workspaceAction.uppercasedFirst
        case .checkLabels: return "Check for AI labels"
        case nil: break
        }
        if let routine { return routine.title }
        if labelCheckRequested { return labelRemovalRequested ? "Remove AI labels" : "Check for AI labels" }
        if let tool { return tool.workspaceAction.uppercasedFirst }
        return "Preparing files"
    }

    /// After a batch, the done screen can give way to the list of files.
    var showsResultList = false

    /// Where the results went, in plain words.
    var resultLocation: String {
        let afterwards = trashOriginals ? " The originals are in the Trash." : ""
        switch delivery {
        case .nextToOriginals: return "Saved next to the originals." + afterwards
        case .folder(let folder): return "Saved to \(folder.lastPathComponent)." + afterwards
        case .copy: return "Copied. Ready to paste."
        case .share: return "Ready to share."
        case nil: return ""
        }
    }

    var bytesIn: Int64 { batchProgress.bytesIn }
    var bytesOut: Int64 { batchProgress.bytesOut }

    /// The waiting files by kind, in a fixed order.
    var waitingKinds: [(kind: FileKind, items: [CompressionItem])] {
        Dictionary(grouping: items.filter { $0.state == .queued }) { FileKind($0.format) }
            .sorted { $0.key < $1.key }
            .map { (kind: $0.key, items: $0.value) }
    }

    /// Set when Home runs one plugin's job on its files: the job lasts for
    /// that batch only, and the next files at Home are asked about again.
    private var toolIsForThisBatch = false

    /// Switches between Home (`nil`) and a plugin's workspace. Each
    /// workspace starts with an empty list; nothing switches mid-batch.
    func useWorkspace(_ tool: ExtensionID?) {
        guard !isProcessing else { return }
        if toolIsForThisBatch {
            toolIsForThisBatch = false
            self.tool = nil
        }
        guard tool != self.tool else { return }
        self.tool = tool
        routine = nil
        clearAll()
    }

    /// Home: runs one plugin's job on the files waiting, without leaving Home.
    func run(_ tool: ExtensionID) {
        guard !isProcessing, self.tool == nil, pluginsNeededForWaitingFiles.isEmpty,
              items.filter({ $0.state == .queued }).allSatisfy({ tool.workspaceAccepts($0.format) })
        else { return }
        self.tool = tool
        toolIsForThisBatch = true
        continueAfterAdding()
    }

    /// Plugins the waiting files need before anything can be done with them,
    /// in display order.
    var pluginsNeededForWaitingFiles: [ExtensionID] {
        let needed = Set(items.filter { $0.state == .queued }.compactMap {
            CapabilityResolver.canProcess($0.format) ? nil : CapabilityResolver.missingExtension(for: $0.format)
        })
        return ExtensionID.ordered.filter(needed.contains)
    }

    /// Plugins, installed or not, that can do their job on every file
    /// waiting at Home, in display order.
    var toolsForWaitingFiles: [ExtensionID] {
        let formats = Set(items.filter { $0.state == .queued }.map(\.format))
        guard !formats.isEmpty else { return [] }
        return ExtensionID.ordered.filter { tool in formats.allSatisfy(tool.workspaceAccepts) }
    }

    /// Counts of the waiting files by format, largest first: "12 JPEG · 2 PDF".
    var waitingSummary: String {
        let counts = Dictionary(grouping: items.filter { $0.state == .queued }, by: \.format).mapValues(\.count)
        return counts.sorted { $0.value > $1.value }
            .map { "\($0.value) \($0.key.rawValue)" }
            .joined(separator: " · ")
    }

    /// Chooses what the files are for. Files already waiting start right away.
    func choose(_ routine: Routine?) {
        guard !isProcessing, tool == nil else { return }
        // Nothing starts while a file still needs its plugin.
        guard routine == nil || pluginsNeededForWaitingFiles.isEmpty else { return }
        self.routine = routine
        // A PDF estimate depends on the routine, so it is made again.
        for index in items.indices where items[index].state == .queued {
            items[index].estimatedBytes = nil
        }
        pdfEstimateVisible = false
        if routine != nil, queuedCount > 0 { continueAfterAdding() }
    }

    /// The settings a batch runs with: the routine's on top of the plugins'.
    private func processingSnapshot() -> SettingsSnapshot {
        var base = settings.snapshot()
        // Prepared files go to the batch's Results folder under their own
        // names; delivery moves and names them, and handles originals.
        base.keepOriginals = true
        if let resultsFolder {
            base.saveLocation = .folder
            base.outputFolderPath = resultsFolder.path
        }
        base.prefix = ""
        base.suffix = ""
        if let tool { return tool.applyWorkspace(to: base) }
        guard let routine else { return base }
        return routine.apply(to: base, canRemoveDetails: CapabilityResolver.metadataCleanerAvailable)
    }

    /// The planner's decision for one file: the routine's settings adapted
    /// to what the file is. A plugin's job does the same to every file.
    private func settings(for item: CompressionItem, base: SettingsSnapshot) -> SettingsSnapshot {
        guard tool == nil, let routine else { return base }
        return routine.plan(for: item.format, base)
    }

    // MARK: Delivery

    /// This batch's Results folder, where prepared files wait for delivery.
    private var resultsFolder: URL?
    /// The batch on the clipboard stays while the clipboard still holds it.
    private var clipboardBatch: (folder: URL, changeCount: Int)?
    /// Files ready to hand to the Share sheet on the done screen.
    private(set) var shareURLs: [URL] = []

    private func makeResultsFolder() -> Bool {
        var keep: Set<URL> = []
        if let clipboardBatch, NSPasteboard.general.changeCount == clipboardBatch.changeCount {
            keep.insert(clipboardBatch.folder)
        }
        Results.prune(keeping: keep)
        do {
            resultsFolder = try Results.makeBatchFolder()
            return true
        } catch {
            alertMessage = "Stou couldn’t prepare a place for the results. \(error.localizedDescription)"
            return false
        }
    }

    /// Moves the prepared files to their destination, or hands them to the
    /// clipboard or the Share sheet, then applies Afterwards.
    private func deliverResults() {
        guard let delivery, let resultsFolder else { return }
        let files: [DeliveryManager.File] = items.compactMap { item in
            guard item.state == .done, let output = item.outputURL,
                  output.standardizedFileURL.path.hasPrefix(resultsFolder.standardizedFileURL.path) else { return nil }
            return .init(original: item.url, originalFormat: item.format, prepared: output)
        }
        guard !files.isEmpty else { return }
        let base = settings.snapshot()
        let outcome = DeliveryManager.deliver(
            files,
            to: delivery,
            trashOriginals: trashOriginals,
            prefix: base.prefix,
            suffix: base.suffix,
            preserveModificationDate: base.preserveModificationDate
        )
        for index in items.indices {
            if let target = outcome.delivered[items[index].url] {
                items[index].outputURL = target
            } else if let reason = outcome.failures[items[index].url] {
                items[index].state = .failed("Couldn’t save to this folder.\n\(reason)")
            }
        }
        let delivered = files.compactMap { outcome.delivered[$0.original] }
        switch delivery {
        case .copy:
            let count = DeliveryManager.copyToPasteboard(delivered)
            clipboardBatch = (resultsFolder, count)
        case .share:
            shareURLs = delivered
        case .nextToOriginals, .folder:
            Results.removeIfEmpty(resultsFolder)
        }
    }

    var keepsOriginals: Bool { settings.keepOriginals }
    var optimizedCount: Int { batchProgress.optimized }
    var unchangedCount: Int { batchProgress.unchanged }
    var failedCount: Int { batchProgress.failed }
    var completedCount: Int { batchProgress.completed }

    var totalSavedBytes: Int64 { batchProgress.bytesSaved }
    var hasPendingPDFEstimate: Bool { items.contains { $0.format == .pdf && $0.estimatedBytes != nil && ($0.state == .queued || $0.state == .analyzing) } }
    var estimatedPDFCount: Int { items.filter { $0.format == .pdf && $0.estimatedBytes != nil }.count }
    var totalEstimatedPDFBytes: Int64 { items.compactMap { $0.format == .pdf ? $0.estimatedBytes : nil }.reduce(0, +) }
    var totalOriginalPDFBytes: Int64 { items.filter { $0.format == .pdf && $0.estimatedBytes != nil }.map(\.originalBytes).reduce(0, +) }
    var pdfExactDuplicateCount: Int { items.filter { $0.format == .pdf }.reduce(0) { $0 + $1.pdfExactDuplicatePages.count } }
    var pdfSimilarPairCount: Int { items.filter { $0.format == .pdf }.reduce(0) { $0 + $1.pdfSimilarPairs.count } }
    var hasPDFSimilarPairs: Bool { pdfSimilarPairCount > 0 }

    var pdfPreflightTotalCount: Int {
        items.filter { $0.format == .pdf }.count
    }

    var pdfPreflightCompletedCount: Int {
        items.filter { item in
            guard item.format == .pdf else { return false }
            if case .analyzing = item.state { return false }
            return true
        }.count
    }

    var pdfPreflightFraction: Double {
        guard pdfPreflightTotalCount > 0 else { return 0 }
        return min(1, max(0, Double(pdfPreflightCompletedCount) / Double(pdfPreflightTotalCount)))
    }

    var pdfPreflightPercent: Int {
        Int((pdfPreflightFraction * 100).rounded())
    }

    var totalSavingsPercent: Int {
        guard batchProgress.bytesIn > 0 else { return 0 }
        return Int((Double(batchProgress.bytesSaved) / Double(batchProgress.bytesIn) * 100).rounded())
    }

    var resultSummary: String {
        var parts: [String] = []
        if optimizedCount > 0 { parts.append("\(optimizedCount) lighter") }
        if unchangedCount > 0 { parts.append("\(unchangedCount) already light") }
        if failedCount > 0 { parts.append("\(failedCount) couldn’t be prepared") }
        if batchProgress.cancelled > 0 { parts.append("\(batchProgress.cancelled) cancelled") }
        return parts.isEmpty ? "No files changed" : parts.joined(separator: " · ")
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.prompt = "Add"
        panel.message = "Choose files or folders. Install plugins from the sidebar for more formats."
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.resolvesAliases = true
        if panel.runModal() == .OK { add(urls: panel.urls) }
    }

    func add(urls: [URL]) {
        if resultDrawerVisible && !isProcessing {
            items.removeAll()
            resultDrawerVisible = false
            recalculateBatchProgress()
        }
        // Each new set of files starts its own job.
        if !isProcessing, queuedCount == 0 {
            resetJob()
            labelCheckRequested = false
            labelRemovalRequested = false
            labelReportVisible = false
        }
        // Home asks again for each new set of files.
        if !isProcessing, queuedCount == 0, tool == nil || toolIsForThisBatch {
            if toolIsForThisBatch { tool = nil; toolIsForThisBatch = false }
            routine = nil
        }

        let expanded = expandDirectories(urls)
        var existing = Set(items.map { $0.url.standardizedFileURL.path })
        var additions: [CompressionItem] = []
        var missingExtensions: [ExtensionID] = []
        var outsideWorkspace = 0

        for url in expanded {
            let normalized = url.standardizedFileURL
            guard !existing.contains(normalized.path) else { continue }
            guard let format = FileSniffer.detect(url: normalized), format != .unknown else { continue }

            if let tool, !tool.workspaceAccepts(format) {
                outsideWorkspace += 1
                continue
            }

            // Home keeps a recognised file even without its plugin: the wizard
            // offers to install the plugin. A plugin's workspace only takes
            // what it can do.
            if !CapabilityResolver.canProcess(format) {
                let required = CapabilityResolver.missingExtension(for: format)
                guard tool == nil, required != nil else {
                    if let required, !missingExtensions.contains(required) {
                        missingExtensions.append(required)
                    }
                    continue
                }
            }

            let bytes = FileSniffer.fileSize(url: normalized)
            guard bytes > 0 else { continue }
            additions.append(CompressionItem(url: normalized, format: format, originalBytes: bytes))
            existing.insert(normalized.path)
        }

        items.append(contentsOf: additions)
        recalculateBatchProgress()

        if let tool, outsideWorkspace > 0 {
            alertMessage = "\(tool.title) takes \(tool.workspaceFormats). Use Home for other files."
        } else if let missing = missingExtensions.first {
            alertMessage = "Install the “\(missing.title)” plugin from Plugins to work with this file."
        } else if additions.isEmpty && items.isEmpty {
            alertMessage = "Stou can’t open these files."
        }

        if !additions.isEmpty {
            checkAILabels(of: additions.map(\.id))
        }
    }

    private func continueAfterAdding() {
        // An AI-label question waits for its answer.
        guard !aiLabelDecisionPending else { return }
        // A label check ends in its report, unless removal was asked for.
        if (tool == .aiProvenance || labelCheckRequested) && !labelRemovalRequested {
            labelCheckRequested = true
            labelReportVisible = true
            return
        }
        // Home without a choice yet: prepare the wizard's estimates.
        guard routine != nil || tool != nil else {
            estimateForHome()
            return
        }
        // Then where the results go, asked for each job.
        guard delivery != nil else {
            askWhereTo()
            return
        }
        if items.contains(where: { $0.format == .pdf && $0.estimatedBytes == nil && $0.state == .queued }) {
            startPDFPreflight()
        } else {
            requestStart()
        }
    }

    // MARK: AI labels

    var aiLabeledCount: Int { items.filter { $0.hasAILabels && $0.state == .queued }.count }

    /// Reads labels before anything is processed, so the user sees them first.
    private func checkAILabels(of ids: [UUID]) {
        let targets = items.filter { ids.contains($0.id) && WatermarksExtensionRunner.canInspect($0.format) }
        guard settings.useAIProvenance || tool == .aiProvenance || labelCheckRequested,
              WatermarksExtensionRunner.isInstalled, !targets.isEmpty else {
            continueAfterAdding()
            return
        }
        isCheckingAILabels = true
        let work = targets.map { ($0.id, $0.url) }
        let generation = jobGeneration
        Task {
            let reports = await Task.detached(priority: .userInitiated) {
                work.map { id, url in (id, try? WatermarksExtensionRunner.inspect(url: url)) }
            }.value
            // Cancelled or cleared meanwhile.
            guard generation == jobGeneration else { return }
            for (id, report) in reports {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].aiLabels = report
                }
            }
            isCheckingAILabels = false
            // The remembered choice applies by itself. Without one the user
            // is asked once, and the job waits for the answer. A label check
            // shows its own report instead.
            if aiLabeledCount > 0, tool != .aiProvenance, !labelCheckRequested {
                switch settings.aiLabelPolicy {
                case .remove: markAILabelsForRemoval()
                case .keep: break
                case .ask: aiLabelDecisionPending = true
                }
            }
            continueAfterAdding()
        }
    }

    /// Answers the notice and remembers the answer in AI Provenance’s settings.
    func keepAILabels() {
        settings.aiLabelPolicy = .keep
        aiLabelDecisionPending = false
        continueAfterAdding()
    }

    func removeAILabels() {
        settings.aiLabelPolicy = .remove
        markAILabelsForRemoval()
        aiLabelDecisionPending = false
        continueAfterAdding()
    }

    private func markAILabelsForRemoval() {
        for index in items.indices where items[index].hasAILabels && items[index].state == .queued {
            items[index].removeAILabels = true
        }
    }

    /// Re-encoding can drop Content Credentials even when metadata is kept.
    /// Say so instead of letting labels disappear silently.
    private func recheckKeptAILabels(itemID: UUID, output: URL) {
        Task {
            let report = await Task.detached(priority: .utility) {
                try? WatermarksExtensionRunner.inspect(url: output)
            }.value
            guard let report, let index = items.firstIndex(where: { $0.id == itemID }) else { return }
            items[index].aiLabelsLost = report.isEmpty
        }
    }

    func acceptDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let nsurl = item as? NSURL { url = nsurl as URL }
                else if let directURL = item as? URL { url = directURL }
                guard let url else { return }
                Task { @MainActor in self?.add(urls: [url]) }
            }
        }
        return accepted
    }

    func requestStart() {
        guard !isProcessing, queuedCount > 0 else { return }
        resultDrawerVisible = false
        pdfEstimateVisible = false
        startProcessing()
    }

    func startProcessing() {
        guard !isProcessing, queuedCount > 0 else { return }
        let missing = Compressor.missingRequiredTools()
        if !missing.isEmpty {
            alertMessage = "The Images plugin is incomplete. Reinstall it in Plugins."
            return
        }
        guard makeResultsFolder() else { return }

        let token = CancellationToken()
        cancellationToken = token
        isCancelling = false
        isProcessing = true
        resultDrawerVisible = false
        recalculateBatchProgress()
        let snapshot = processingSnapshot()
        processingTask = Task { [weak self] in
            guard let self else { return }
            await self.processQueue(snapshot: snapshot, token: token)
        }
    }

    func cancelBatch() {
        guard isProcessing, !isCancelling else { return }
        isCancelling = true
        cancellationToken?.cancel()
        processingTask?.cancel()
    }

    private func processQueue(snapshot: SettingsSnapshot, token: CancellationToken) async {
        while !token.isCancelled {
            let jobs: [ProcessingJob] = items.compactMap { item in
                guard item.state == .queued else { return nil }
                let exact = snapshot.removeExactPDFDuplicates ? item.pdfExactDuplicatePages : []
                let selected = Array(item.pdfSelectedSimilarDuplicates)
                return ProcessingJob(
                    id: item.id,
                    url: item.url,
                    format: item.format,
                    originalBytes: item.originalBytes,
                    pdfPagesToRemove: Array(Set(exact + selected)).sorted(),
                    removeAILabels: item.removeAILabels,
                    settings: settings(for: item, base: snapshot)
                )
            }
            guard !jobs.isEmpty else { break }

            let parallelism = AdaptiveScheduler.maxConcurrentJobs(for: jobs, settings: snapshot)
            var nextJob = 0

            await withTaskGroup(of: ScheduledCompressionResult.self) { group in
                let initial = min(parallelism, jobs.count)
                for _ in 0..<initial where !token.isCancelled {
                    let job = jobs[nextJob]
                    nextJob += 1
                    markSqueezing(job.id)
                    group.addTask(priority: .userInitiated) {
                        if token.isCancelled || Task.isCancelled {
                            return ScheduledCompressionResult(job: job, result: .init(outcome: .cancelled))
                        }
                        return ScheduledCompressionResult(
                            job: job,
                            result: Compressor.compress(
                                url: job.url,
                                format: job.format,
                                originalBytes: job.originalBytes,
                                settings: job.settings,
                                cancellation: token,
                                pdfPagesToRemove: job.pdfPagesToRemove,
                                removeAILabels: job.removeAILabels
                            )
                        )
                    }
                }

                while let completed = await group.next() {
                    apply(completed)
                    if token.isCancelled || Task.isCancelled {
                        group.cancelAll()
                        continue
                    }
                    if nextJob < jobs.count {
                        let job = jobs[nextJob]
                        nextJob += 1
                        markSqueezing(job.id)
                        group.addTask(priority: .userInitiated) {
                            if token.isCancelled || Task.isCancelled {
                                return ScheduledCompressionResult(job: job, result: .init(outcome: .cancelled))
                            }
                            return ScheduledCompressionResult(
                                job: job,
                                result: Compressor.compress(
                                    url: job.url,
                                    format: job.format,
                                    originalBytes: job.originalBytes,
                                    settings: job.settings,
                                    cancellation: token,
                                    pdfPagesToRemove: job.pdfPagesToRemove,
                                    removeAILabels: job.removeAILabels
                                )
                            )
                        }
                    }
                }
            }
        }

        if token.isCancelled {
            for index in items.indices where items[index].state == .queued {
                items[index].state = .cancelled
            }
        }

        deliverResults()
        isProcessing = false
        isCancelling = false
        cancellationToken = nil
        processingTask = nil
        recalculateBatchProgress()
        resultDrawerVisible = batchProgress.completed > 0 || batchProgress.cancelled > 0
        quitIfDone()
    }

    /// With Quit when done on, Stou quits after a batch only when every file
    /// was saved: nothing failed or was stopped, and nothing waits on the
    /// clipboard or the Share sheet.
    private func quitIfDone() {
        guard settings.quitWhenDone, batchProgress.completed > 0,
              batchProgress.failed == 0, batchProgress.cancelled == 0,
              delivery?.canTrashOriginals == true else { return }
        NSApp.terminate(nil)
    }

    private func markSqueezing(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .squeezing
        recalculateBatchProgress()
    }

    private func apply(_ completed: ScheduledCompressionResult) {
        guard let index = items.firstIndex(where: { $0.id == completed.job.id }) else { return }
        switch completed.result.outcome {
        case .done(let output, let bytes, let outputFormat):
            items[index].outputURL = output
            items[index].outputBytes = bytes
            items[index].outputFormat = outputFormat
            items[index].state = .done
            stats.record(originalBytes: completed.job.originalBytes, outputBytes: bytes)
            if items[index].hasAILabels && !items[index].removeAILabels {
                recheckKeptAILabels(itemID: items[index].id, output: output)
            }
        case .dry:
            items[index].state = .dry
        case .failed(let message):
            items[index].state = .failed(message)
        case .cancelled:
            items[index].state = .cancelled
        }
        recalculateBatchProgress()
    }

    private func recalculateBatchProgress() {
        var progress = BatchProgress(total: items.count)
        for item in items {
            switch item.state {
            case .queued, .analyzing:
                progress.waiting += 1
            case .squeezing:
                progress.active += 1
            case .done:
                progress.completed += 1
                progress.bytesIn += item.originalBytes
                let output = item.outputBytes ?? item.originalBytes
                progress.bytesOut += output
                let saved = max(0, item.originalBytes - output)
                progress.bytesSaved += saved
                if saved > 0 { progress.optimized += 1 }
                else { progress.unchanged += 1 }
            case .dry:
                progress.completed += 1
                progress.unchanged += 1
                progress.bytesIn += item.originalBytes
                progress.bytesOut += item.originalBytes
            case .failed:
                progress.completed += 1
                progress.failed += 1
            case .cancelled:
                progress.cancelled += 1
            }
        }
        batchProgress = progress
    }



    func startPDFPreflight() {
        // Capture every value needed by background workers while we are still
        // on MainActor. The task group never reads CompressionModel.items.
        let workItems: [PDFPreflightWorkItem] = items.compactMap { item in
            guard item.format == .pdf,
                  item.estimatedBytes == nil,
                  item.state == .queued else { return nil }
            return PDFPreflightWorkItem(
                id: item.id,
                url: item.url,
                originalBytes: item.originalBytes
            )
        }

        guard !workItems.isEmpty else {
            pdfEstimateVisible = items.contains { $0.format == .pdf && $0.estimatedBytes != nil }
            return
        }

        let snapshot = processingSnapshot()

        pdfPreflightTask?.cancel()
        isPreflightingPDF = true
        pdfEstimateVisible = false
        resultDrawerVisible = false

        for work in workItems {
            if let index = items.firstIndex(where: { $0.id == work.id }) {
                items[index].state = .analyzing
            }
        }
        recalculateBatchProgress()

        pdfPreflightTask = Task { [weak self, workItems, snapshot] in
            guard let self else { return }
            let parallelism = min(2, max(1, workItems.count))
            var nextIndex = 0

            await withTaskGroup(of: (UUID, Result<PDFPreflightReport, CompressionError>).self) { group in
                func addJob(_ work: PDFPreflightWorkItem) {
                    group.addTask(priority: .userInitiated) {
                        if Task.isCancelled {
                            return (work.id, .failure(.message("Cancelled")))
                        }
                        do {
                            let report = try PDFTools.preflight(
                                input: work.url,
                                originalBytes: work.originalBytes,
                                mode: snapshot.pdfCompressionMode,
                                duplicateMode: snapshot.pdfDuplicateMode,
                                removeExactDuplicates: snapshot.removeExactPDFDuplicates
                            )
                            return (work.id, .success(report))
                        } catch let error as CompressionError {
                            return (work.id, .failure(error))
                        } catch {
                            return (work.id, .failure(.message(error.localizedDescription)))
                        }
                    }
                }

                for _ in 0..<parallelism where nextIndex < workItems.count {
                    addJob(workItems[nextIndex])
                    nextIndex += 1
                }

                while let (id, result) = await group.next() {
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }

                    guard let index = self.items.firstIndex(where: { $0.id == id }) else { continue }
                    switch result {
                    case .success(let report):
                        if report.encrypted {
                            self.items[index].state = .failed("Encrypted PDF")
                        } else if report.signed {
                            self.items[index].state = .failed("Digitally signed PDF")
                        } else if report.alreadyOptimal {
                            self.items[index].state = .dry
                        } else {
                            self.items[index].estimatedBytes = report.estimatedBytes
                            self.items[index].pdfExactDuplicatePages = report.exactDuplicatePages
                            self.items[index].pdfSimilarPairs = report.similarPairs
                            self.items[index].state = .queued
                        }
                    case .failure(let error):
                        if error.description != "Cancelled" {
                            self.items[index].state = .failed(error.description)
                        }
                    }
                    self.recalculateBatchProgress()

                    if nextIndex < workItems.count && !Task.isCancelled {
                        addJob(workItems[nextIndex])
                        nextIndex += 1
                    }
                }
            }

            guard !Task.isCancelled else { return }
            self.isPreflightingPDF = false
            self.pdfPreflightTask = nil
            self.pdfEstimateVisible = self.hasPendingPDFEstimate
            // The job was already chosen, so it goes on by itself. It stops
            // only when similar pages need the user's review.
            if self.pdfEstimateVisible && !self.hasPDFSimilarPairs {
                self.startEstimatedBatch()
                return
            }
            if !self.pdfEstimateVisible {
                self.resultDrawerVisible = self.batchProgress.completed > 0
            }
        }
    }

    func skipPDFEstimate() {
        guard isPreflightingPDF else { return }

        pdfPreflightTask?.cancel()
        pdfPreflightTask = nil
        isPreflightingPDF = false
        pdfEstimateVisible = false

        for index in items.indices {
            if case .analyzing = items[index].state {
                items[index].state = .queued
                items[index].estimatedBytes = nil
                items[index].pdfExactDuplicatePages = []
                items[index].pdfSimilarPairs = []
                items[index].pdfSelectedSimilarDuplicates = []
            }
        }
        recalculateBatchProgress()
        requestStart()
    }

    /// Back from the PDF estimate, before anything is prepared: to Where to?.
    func backFromPDFEstimate() {
        guard pdfEstimateVisible, !isProcessing else { return }
        pdfEstimateVisible = false
        pdfReviewItemID = nil
        resetPDFEstimates()
        returnToWhereTo()
    }

    /// Forgets what reading the PDFs found, so they are read again with the
    /// job's settings next time.
    private func resetPDFEstimates() {
        for index in items.indices where items[index].format == .pdf && items[index].state != .done {
            items[index].state = .queued
            items[index].estimatedBytes = nil
            items[index].pdfExactDuplicatePages = []
            items[index].pdfSimilarPairs = []
            items[index].pdfSelectedSimilarDuplicates = []
        }
        recalculateBatchProgress()
    }

    func beginPDFSimilarReview() {
        let item = items.first(where: { !$0.pdfSimilarPairs.isEmpty })
        pdfReviewSnapshot = item?.pdfSelectedSimilarDuplicates ?? []
        pdfReviewItemID = item?.id
    }

    func finishPDFSimilarReview() {
        pdfReviewItemID = nil
    }

    /// Closes the review with the pages it opened with.
    func cancelPDFSimilarReview() {
        if let id = pdfReviewItemID, let index = items.firstIndex(where: { $0.id == id }) {
            items[index].pdfSelectedSimilarDuplicates = pdfReviewSnapshot
        }
        pdfReviewItemID = nil
    }

    func isSimilarPageSelected(itemID: UUID, pageIndex: Int) -> Bool {
        items.first(where: { $0.id == itemID })?.pdfSelectedSimilarDuplicates.contains(pageIndex) ?? false
    }

    func setSimilarPageSelected(itemID: UUID, pageIndex: Int, selected: Bool) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if selected {
            items[index].pdfSelectedSimilarDuplicates.insert(pageIndex)
        } else {
            items[index].pdfSelectedSimilarDuplicates.remove(pageIndex)
        }
    }

    func startEstimatedBatch() {
        pdfReviewItemID = nil
        requestStart()
    }
    func dismissResult() {
        clearAll()
    }

    /// Back from the list of files to the done screen.
    func hideResultList() {
        showsResultList = false
    }

    func clearAll() {
        guard !isProcessing else { return }
        jobGeneration += 1
        isCheckingAILabels = false
        resetJob()
        showsResultList = false
        labelReportVisible = false
        labelCheckRequested = false
        labelRemovalRequested = false
        estimateTask?.cancel()
        pdfEstimates = [:]
        isEstimating = false
        pdfPreflightTask?.cancel()
        pdfPreflightTask = nil
        items.removeAll()
        resultDrawerVisible = false
        pdfEstimateVisible = false
        pdfReviewItemID = nil
        isPreflightingPDF = false
        aiLabelDecisionPending = false
        recalculateBatchProgress()
    }

    var hasRevealableResults: Bool {
        items.contains { item in
            switch item.state {
            case .done: return item.outputURL != nil
            case .dry: return true
            default: return false
            }
        }
    }

    func revealResults() {
        let urls = items.compactMap { item -> URL? in
            switch item.state {
            case .done: return item.outputURL
            case .dry: return item.url
            default: return nil
            }
        }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func expandDirectories(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        for url in urls {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                if let enumerator = fm.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) {
                    for case let child as URL in enumerator {
                        if (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                            result.append(child)
                        }
                    }
                }
            } else {
                result.append(url)
            }
        }
        return result
    }
}

