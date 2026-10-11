import SwiftUI
import AppKit

// MARK: - General

/// General settings as sections; the Settings page puts them in its form.
struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions

    var body: some View {
        @Bindable var settings = settings

        Group {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if extensions.state(for: .aiProvenance).isInstalled {
                Section {
                    Picker("AI labels", selection: $settings.aiLabelPolicy) {
                        ForEach(AILabelPolicy.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("AI Labels")
                } footer: {
                    Text("Some sites require them.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(settings.favoriteFolders, id: \.self) { path in
                    LabeledContent {
                        Button {
                            settings.favoriteFolders.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from favorites")
                        .accessibilityLabel("Remove \(URL(fileURLWithPath: path).lastPathComponent)")
                    } label: {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                        Text((path as NSString).abbreviatingWithTildeInPath)
                    }
                }
                Button("Add Folder…") { addFavorite() }
            } header: {
                Text("Favorite Folders")
            } footer: {
                Text("Offered in Where to? for every job.")
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Prefix", text: $settings.prefix, prompt: Text("None"))
                TextField("Suffix", text: $settings.suffix, prompt: Text("_prepared"))
                Toggle("Keep original dates", isOn: $settings.preserveModificationDate)
            } header: {
                Text("File Names")
            } footer: {
                Text("For files saved next to their originals: photo.jpg → \(settings.prefix)photo\(settings.suffix.isEmpty ? "_prepared" : settings.suffix).jpg")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addFavorite() {
        let panel = NSOpenPanel()
        panel.message = "Choose a folder to offer in Where to?."
        panel.prompt = "Add"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let path = panel.url?.path, !settings.favoriteFolders.contains(path) {
            settings.favoriteFolders.append(path)
        }
    }
}

// MARK: - Plugins

/// Plugin symbol on a rounded colour tile, in the style of System Settings:
/// 20 pt beside a list row's text, 32 pt where the plugin is the subject.
struct PluginIcon: View {
    let id: ExtensionID
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: id.symbolName)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(id.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A plain grey tile for a symbol that isn't a plugin — routines and
/// destinations — so every row icon has the same shape as the plugins'.
struct SymbolTile: View {
    let symbol: String
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.gray.gradient, in: RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Plugin

struct PluginDetailView: View {
    @Environment(ExtensionManager.self) private var extensions
    // A plain State value: the @State macro needs Xcode's SwiftUIMacros plugin.
    private let confirmingRemoval = State(initialValue: false)
    let id: ExtensionID

    var body: some View {
        let state = extensions.state(for: id)

        Form {
            Section {
                // The page has no header bar: the name leads the first card,
                // and the description sits below it as its own row.
                HStack(alignment: .center, spacing: 12) {
                    PluginIcon(id: id)
                    Text(id.title)
                        .font(.title3.weight(.semibold))
                    Spacer(minLength: 12)
                    actionButton(for: state)
                }
                .padding(.vertical, 2)

                Text(id.summary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let line = statusLine(for: state) {
                    Text(line)
                        .foregroundStyle(state.isFailure ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                }
            }

            if state.isInstalled {
                if id == .imageProcessing {
                    ImageProcessingSettings()
                } else if id.hasSettings {
                    Section {
                        InstalledExtensionSettings(id: id)
                    }
                }

                if extensions.hasManagedUpdateChannel(for: id), extensions.hasUpdate(for: id) {
                    Section {
                        Button("Update \(id.title)") { extensions.update(id) }
                    }
                }
            }

            Section {
                Link(destination: extensions.toolsURL(for: id)) {
                    Label("Included Tools and Licences", systemImage: "arrow.up.forward.square")
                }
                .help(extensions.toolsURL(for: id).absoluteString)
            }
        }
        .formStyle(.grouped)
        // Removal is undone only by installing again, which can take minutes,
        // so it is confirmed. The red button is the dialog's, as macOS does it.
        .confirmationDialog("Remove \(id.title)?", isPresented: confirmingRemoval.projectedValue) {
            Button("Remove", role: .destructive) { extensions.remove(id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(removalMessage)
        }
    }

    private var removalMessage: String {
        let builtFromSource = extensions.components(for: id).contains {
            if case .builtFromSource = $0.source { return true }
            return false
        }
        let reinstall = builtFromSource
            ? "Installing it again builds it from source and can take several minutes."
            : "You can install it again at any time."
        return "Files of these formats can’t be prepared until it’s installed again. Its settings and Homebrew packages stay. \(reinstall)"
    }

    @ViewBuilder
    private func actionButton(for state: ExtensionInstallState) -> some View {
        switch state {
        case .installed:
            // A standard push button: macOS shows a destructive action in red
            // only in the confirmation dialog that follows.
            Button("Remove", role: .destructive) {
                confirmingRemoval.wrappedValue = true
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Button("Cancel") { extensions.cancelInstall(id) }
            }
        case .cancelling, .removing:
            ProgressView().controlSize(.small)
        case .notInstalled, .failed:
            Button("Install") { extensions.install(id) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func statusLine(for state: ExtensionInstallState) -> String? {
        switch state {
        case .installing: return "Installing… This can take a few minutes."
        case .cancelling: return "Cancelling…"
        case .removing: return "Removing…"
        case .failed(let message): return message
        default: return nil
        }
    }
}

// MARK: - Images plugin

/// Fine controls per format. Quality level, size, format, colour and hidden
/// details come from the routine chosen in the workspace.
struct ImageProcessingSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Section("JPEG") {
            Picker("Quality", selection: $settings.jpegQuality) {
                ForEach(QualityPreset.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Load gradually on the web", isOn: $settings.jpegProgressive)
        }

        Section("WebP") {
            Picker("Quality", selection: $settings.webpQuality) {
                ForEach(QualityPreset.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Smaller, slightly softer", isOn: $settings.webpLossy)
        }

        Section {
            Toggle("Fewer colors, smaller file", isOn: $settings.pngLossyOptimization)
        } header: {
            Text("PNG")
        } footer: {
            Text("Size, format and overall quality come from what you choose for your files. Fewer colors applies only when some quality loss is allowed.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Other plugins

struct InstalledExtensionSettings: View {
    @Environment(AppSettings.self) private var settings
    let id: ExtensionID

    var body: some View {
        @Bindable var settings = settings

        switch id {
        case .imageProcessing, .applePhotos:
            EmptyView()

        case .highQualityJPEG:
            Toggle("Use jpegli for JPEGs", isOn: $settings.useHighQualityJPEG)

        case .photography:
            Picker("RAW output", selection: $settings.photographyRAWOutput) {
                ForEach(PhotographyRAWOutput.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Keep full color depth", isOn: $settings.photographyPreserve16Bit)

        case .animation:
            Picker("Frame rate", selection: $settings.animationFrameRate) {
                ForEach(AnimationFrameRate.allCases) { Text($0.title).tag($0) }
            }
            Picker("Loop", selection: $settings.animationLoopMode) {
                ForEach(AnimationLoopMode.allCases) { Text($0.title).tag($0) }
            }
            Picker("Resize", selection: $settings.animationResize) {
                ForEach(AnimationResize.allCases) { Text($0.title).tag($0) }
            }
            Picker("Compression", selection: $settings.animationCompression) {
                ForEach(AnimationCompression.allCases) { Text($0.title).tag($0) }
            }
            Picker("Output", selection: $settings.animationOutput) {
                ForEach(AnimationOutput.allCases) { Text($0.title).tag($0) }
            }

        case .legacyFormats:
            Picker("Preferred output", selection: $settings.legacyPreferredOutput) {
                ForEach(LegacyPreferredOutput.allCases) { Text($0.title).tag($0) }
            }

        case .metadataCleaner:
            EmptyView()

        case .aiProvenance:
            Toggle("Look for AI labels when files are added", isOn: $settings.useAIProvenance)

        case .pdfTools:
            Picker(selection: $settings.pdfCompressionMode) {
                ForEach(PDFCompressionMode.allCases) { Text($0.title).tag($0) }
            } label: {
                Text("Size")
                Text(settings.pdfCompressionMode.detail)
            }
            Picker("Duplicate pages", selection: $settings.pdfDuplicateMode) {
                ForEach(PDFDuplicateMode.allCases) { Text($0.title).tag($0) }
            }
            if settings.pdfDuplicateMode != .off {
                Toggle("Remove exact duplicates", isOn: $settings.removeExactPDFDuplicates)
            }
            if settings.pdfDuplicateMode == .reviewSimilar {
                Text("Similar pages are only flagged for review. They are never removed automatically.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Capability coercion

extension AppSettings {
    func availableOutputs(_ extensions: ExtensionManager) -> [OutputChoice] {
        var values: [OutputChoice] = [.keepOriginal, .jpeg, .png, .webp]
        if extensions.state(for: .applePhotos).isInstalled { values += [.heic, .avif] }
        if extensions.state(for: .photography).isInstalled { values.append(.tiff) }
        return values
    }

    /// Falls back to safe defaults when the plugin behind a setting is removed.
    func coerceToInstalledCapabilities(_ extensions: ExtensionManager) {
        if !availableOutputs(extensions).contains(output) {
            output = .keepOriginal
        }
        if !extensions.state(for: .metadataCleaner).isInstalled {
            metadataMode = .keep
        }
    }
}
