import SwiftUI
import AppKit

// MARK: - General

/// General settings as sections; the Settings page puts them in its form.
struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Group {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section {
                ForEach(settings.favoriteFolders, id: \.self) { path in
                    LabeledContent {
                        Button {
                            settings.favoriteFolders.removeAll { $0 == path }
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: Design.Size.minimumControl, height: Design.Size.minimumControl)
                                .contentShape(Rectangle())
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
            }

            Section {
                TextField("Prefix", text: $settings.prefix, prompt: Text("None"))
                TextField("Suffix", text: $settings.suffix, prompt: Text("_prepared"))
                Toggle("Keep original dates", isOn: $settings.preserveModificationDate)
            } header: {
                Text("File Names")
            }

            Section {
                Toggle("Quit when done", isOn: $settings.quitWhenDone)
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

// MARK: - My Settings

/// What Use my settings does on Home, in Home's panel. The other routines
/// set all of these themselves; animations, RAW files and PDFs follow their
/// plugins.
struct MySettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ExtensionManager.self) private var extensions

    var body: some View {
        @Bindable var settings = settings
        let canRemoveDetails = extensions.state(for: .metadataCleaner).isInstalled

        PanelSection {
            LabeledContent("Size") {
                PanelPicker(title: "Size", selection: $settings.resizeMode, options: ResizeMode.allCases) { $0.title }
            }
            if settings.resizeMode == .percentage {
                LabeledContent("Percent") {
                    TextField("Percent", value: $settings.resizePercentage, format: .number, prompt: Text("50"))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
            } else if settings.resizeMode != .original {
                LabeledContent("Pixels") {
                    TextField("Pixels", value: $settings.resizeSize, format: .number, prompt: Text("2500"))
                        .labelsHidden()
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
            }
            LabeledContent("Format") {
                PanelPicker(title: "Format", selection: $settings.output, options: settings.availableOutputs(extensions)) { $0.title }
            }
            LabeledContent("Quality") {
                PanelPicker(title: "Quality", selection: $settings.compressionMode, options: CompressionMode.allCases) { $0.title }
            }
            Toggle("Allow some quality loss", isOn: $settings.allowLossyOptimization)
            Toggle("Convert colors for sharing", isOn: $settings.optimizeColorForSharing)
            Toggle("Remove color profile", isOn: Binding(
                get: { !settings.preserveColorProfile },
                set: { settings.preserveColorProfile = !$0 }
            ))
            // Offered only with Metadata Cleaner, so it's never a switch
            // that can't be used.
            if canRemoveDetails {
                Toggle("Remove hidden details", isOn: Binding(
                    get: { settings.metadataMode == .removeAll },
                    set: { settings.metadataMode = $0 ? .removeAll : .keep }
                ))
            }
        }
    }

}

// MARK: - Workspace panel

/// The floating panel on the right of a workspace, one surface with no
/// cards inside: its title — My Settings, or the plugin's name — then its
/// rows. Its button is in the window's toolbar. On a plugin: what it does, then
/// its settings. Updates aren't here: Stou and the plugins update together.
/// A batch already running keeps the settings it started with.
struct WorkspaceInspector: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CompressionModel.self) private var model

    var body: some View {
        InspectorShell(title: title) {
            if model.isProcessing {
                Text("Changes apply to the next batch.")
                    .foregroundStyle(.secondary)
            }
            switch settings.selection {
            case .plugin(let id):
                PluginInspector(id: id)
            default:
                MySettingsSection()
            }
        }
    }

    private var title: String {
        if case .plugin(let id) = settings.selection { return id.title }
        return "My Settings"
    }
}

/// A plugin's part of its panel: what it does, then its settings.
struct PluginInspector: View {
    @Environment(ExtensionManager.self) private var extensions
    let id: ExtensionID

    var body: some View {
        let state = extensions.state(for: id)

        VStack(alignment: .leading, spacing: 6) {
            Text(id.summary)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let line = statusLine(for: state) {
                Text(line)
                    .foregroundStyle(state.isFailure ? AnyShapeStyle(Design.Status.failure) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if state.isInstalled {
            if id == .imageProcessing {
                ImageProcessingSettings()
            } else if id.hasSettings {
                PanelSection(title: "Settings") {
                    InstalledExtensionSettings(id: id)
                }
            }
        }
    }

    private func statusLine(for state: ExtensionInstallState) -> String? {
        switch state {
        case .installing: return "Updating… This can take a few minutes."
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

        PanelSection(title: "JPEG") {
            LabeledContent("Quality") {
                PanelPicker(title: "JPEG quality", selection: $settings.jpegQuality, options: QualityPreset.allCases) { $0.title }
            }
            Toggle("Load gradually on the web", isOn: $settings.jpegProgressive)
        }

        PanelSection(title: "WebP") {
            LabeledContent("Quality") {
                PanelPicker(title: "WebP quality", selection: $settings.webpQuality, options: QualityPreset.allCases) { $0.title }
            }
            Toggle("Smaller, slightly softer", isOn: $settings.webpLossy)
        }

        PanelSection(title: "PNG") {
            Toggle("Fewer colors, smaller file", isOn: $settings.pngLossyOptimization)
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
            LabeledContent("RAW output") {
                PanelPicker(title: "RAW output", selection: $settings.photographyRAWOutput, options: PhotographyRAWOutput.allCases) { $0.title }
            }
            Toggle("Keep full color depth", isOn: $settings.photographyPreserve16Bit)

        case .animation:
            LabeledContent("Frame rate") {
                PanelPicker(title: "Frame rate", selection: $settings.animationFrameRate, options: AnimationFrameRate.allCases) { $0.title }
            }
            // A video loops where it's played, so it has no loop setting.
            if !settings.animationOutput.isVideo {
                LabeledContent("Loop") {
                    PanelPicker(title: "Loop", selection: $settings.animationLoopMode, options: AnimationLoopMode.allCases) { $0.title }
                }
            }
            LabeledContent("Resize") {
                PanelPicker(title: "Resize", selection: $settings.animationResize, options: AnimationResize.allCases) { $0.title }
            }
            LabeledContent("Compression") {
                PanelPicker(title: "Compression", selection: $settings.animationCompression, options: AnimationCompression.allCases) { $0.title }
            }
            LabeledContent("Output") {
                PanelPicker(title: "Output", selection: $settings.animationOutput, options: AnimationOutput.allCases) { $0.title }
            }

        case .legacyFormats:
            LabeledContent("Preferred output") {
                PanelPicker(title: "Preferred output", selection: $settings.legacyPreferredOutput, options: LegacyPreferredOutput.allCases) { $0.title }
            }

        case .metadataCleaner:
            EmptyView()

        case .aiProvenance:
            Toggle("Look for AI labels when files are added", isOn: $settings.useAIProvenance)
            LabeledContent("AI labels") {
                PanelPicker(title: "AI labels", selection: $settings.aiLabelPolicy, options: AILabelPolicy.allCases) { $0.title }
            }

        case .pdfTools:
            LabeledContent("Size") {
                PanelPicker(title: "Size", selection: $settings.pdfCompressionMode, options: PDFCompressionMode.allCases) { $0.title }
            }
            LabeledContent("Duplicate pages") {
                PanelPicker(title: "Duplicate pages", selection: $settings.pdfDuplicateMode, options: PDFDuplicateMode.allCases) { $0.title }
            }
            if settings.pdfDuplicateMode != .off {
                Toggle("Remove exact duplicates", isOn: $settings.removeExactPDFDuplicates)
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
