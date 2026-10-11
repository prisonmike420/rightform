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
                // It checks by itself at most once a day. Only the button shows
                // that a check is running, and it keeps its width meanwhile.
                LabeledContent(updateDescription) {
                    if updates.installStep == .downloading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Button("Cancel") { updates.cancelUpdate() }
                        }
                    } else if updates.installStep == .installing {
                        ProgressView().controlSize(.small)
                    } else if case .available(let version) = updates.status {
                        Button("Update to \(version.trimmingCharacters(in: CharacterSet(charactersIn: "v")))") {
                            updates.update()
                        }
                        .buttonStyle(.borderedProminent)
                        // Updating quits Stou, which would stop the batch.
                        .disabled(model.isProcessing)
                    } else {
                        Button {
                            updates.check(force: true)
                        } label: {
                            ZStack {
                                Text("Check for Updates").hidden()
                                Text(updates.isChecking ? "Checking" : "Check for Updates")
                            }
                        }
                        .disabled(updates.isChecking)
                    }
                }
                if case .failed(let message) = updates.installStep {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                        Link("Open the Release Page", destination: UpdateChecker.releasesPage)
                    }
                } else if model.isProcessing, case .available = updates.status, updates.installStep == .idle {
                    Text("You can update once the current batch is done.")
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
        .navigationTitle("Settings")
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear { updates.check() }
    }

    private var updateDescription: String {
        switch updates.status {
        case _ where updates.installStep == .downloading: return "Downloading the update…"
        case _ where updates.installStep == .installing: return "Installing; Stou will reopen"
        case .checking: return "Updates"
        case .current: return "Up to date"
        case .available(let version): return "Version \(version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))) is available"
        case .unavailable: return "Couldn’t check for updates"
        }
    }
}
