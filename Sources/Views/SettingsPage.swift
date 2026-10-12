import SwiftUI

/// Settings and About on one page, opened from the gear at the bottom of the
/// rail or from Stou › Settings… (⌘,).
struct SettingsPage: View {
    @Environment(UpdateChecker.self) private var updates
    @Environment(StatisticsStore.self) private var stats
    @Environment(ExtensionManager.self) private var extensions
    @Environment(CompressionModel.self) private var model

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }

    /// Days since usage started being counted, the first day included.
    private var daysCounted: Int {
        let start = Calendar.current.startOfDay(for: stats.installedAt)
        let today = Calendar.current.startOfDay(for: Date())
        return (Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0) + 1
    }

    private var installedPlugins: Int {
        ExtensionID.allCases.filter { extensions.state(for: $0).isInstalled }.count
    }

    var body: some View {
        Form {
            GeneralSettingsView()

            Section("About") {
                LabeledContent("Version") {
                    Text("\(UpdateChecker.currentVersion) (\(build))").monospacedDigit()
                }
                // Stou and the plugins' engines update together. A waiting
                // update is offered by the blue button in the rail only; this
                // row shows checking, progress and failures. It checks by
                // itself at most once a day, the engines once a week. Only the
                // button shows that a check is running, and it keeps its width
                // meanwhile.
                if !(updates.hasUpdate(extensions) && updates.installStep == .idle) {
                    LabeledContent(updateDescription) {
                        if updates.installStep == .downloading {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Button("Cancel") { updates.cancelUpdate() }
                            }
                        } else if updates.installStep == .installing || updates.installStep == .updatingPlugins {
                            ProgressView().controlSize(.small)
                        } else if updates.hasUpdate(extensions) {
                            Button("Update") { updates.update(extensions) }
                                .buttonStyle(.borderedProminent)
                                // Updating quits Stou and replaces engines, which
                                // would stop the batch.
                                .disabled(model.isProcessing)
                        } else {
                            Button {
                                updates.checkAll(extensions)
                            } label: {
                                ZStack {
                                    Text("Check for Updates").hidden()
                                    Text(isChecking ? "Checking" : "Check for Updates")
                                }
                            }
                            .disabled(isChecking)
                        }
                    }
                }
                if case .failed(let message) = updates.installStep {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                        Link("Open the Release Page", destination: UpdateChecker.releasesPage)
                    }
                } else if case .pluginsFailed(let message) = updates.installStep {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                }
                if let error = extensions.formulaeCheckError, !updates.hasUpdate(extensions) {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Space saved") {
                    Text(formatBytes(stats.totalBytesSaved)).monospacedDigit()
                }
                LabeledContent("Files prepared") {
                    Text(stats.totalFilesOptimized.formatted()).monospacedDigit()
                }
                LabeledContent("Plugins") {
                    Text("\(installedPlugins) of \(ExtensionID.allCases.count)").monospacedDigit()
                }
                LabeledContent("Period") {
                    Text(daysCounted == 1 ? "1 day" : "Over \(daysCounted) days").monospacedDigit()
                }
            }

        }
        .formStyle(.grouped)
        .onAppear { updates.check() }
    }

    private var isChecking: Bool { updates.isChecking || extensions.isCheckingFormulae }

    private var updateDescription: String {
        // Stou's own release and its plugins' engines read as one update.
        switch updates.status {
        case _ where updates.installStep == .updatingPlugins: return "Updating…"
        case _ where updates.installStep == .downloading: return "Downloading the update…"
        case _ where updates.installStep == .installing: return "Installing; Stou will reopen"
        case _ where updates.hasUpdate(extensions): return "An update is available"
        case .checking: return "Updates"
        case .current: return extensions.formulaeCheckError == nil ? "Up to date" : "Couldn’t check for updates"
        case .available, .unavailable: return "Couldn’t check for updates"
        }
    }
}
