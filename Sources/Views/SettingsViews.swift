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
                Picker("Size", selection: $settings.resizeMode) {
                    ForEach(ResizeMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
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
                Picker("Format", selection: $settings.output) {
                    ForEach(settings.availableOutputs(extensions)) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabeledContent("Quality") {
                Picker("Quality", selection: $settings.compressionMode) {
                    ForEach(CompressionMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
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

// MARK: - Workspace panel

/// The floating panel on the right of a workspace, one surface with no
/// cards inside: its title — My Settings, or the plugin's name — in a row
/// with the corner buttons, then its rows. On a plugin: what it does, its
/// licences and removal under ⋯, then its settings. Updates aren't here:
/// Stou and the plugins update together. A batch already running keeps the
/// settings it started with.
struct WorkspaceInspector: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CompressionModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if case .plugin(let id) = settings.selection {
                    PluginMoreMenu(id: id)
                }
                ShellCornerButtons()
            }
            .padding(.horizontal, ShellCornerButtons.inset)
            .frame(height: ShellCornerButtons.rowHeight)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ShellCornerButtons.inset)
                .padding(.bottom, ShellCornerButtons.inset)
                .labeledContentStyle(PanelRowStyle())
                .toggleStyle(PanelToggleStyle())
            }
        }
    }

    private var title: String {
        if case .plugin(let id) = settings.selection { return id.title }
        return "My Settings"
    }
}

/// ⋯ beside a plugin's name: its included tools and licences, and Remove….
private struct PluginMoreMenu: View {
    @Environment(ExtensionManager.self) private var extensions
    // A plain State value: the @State macro needs Xcode's SwiftUIMacros plugin.
    private let confirmingRemoval = State(initialValue: false)
    let id: ExtensionID

    var body: some View {
        Menu {
            Link("Included Tools and Licences", destination: extensions.toolsURL(for: id))
            Divider()
            Button("Remove \(id.title)…") { confirmingRemoval.wrappedValue = true }
                .disabled(extensions.state(for: id).isBusy)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: Circle())
        .help("More")
        .accessibilityLabel("More for \(id.title)")
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
            : "You can install it again from Plugins at any time."
        return "Files of these formats can’t be prepared until it’s installed again. Its settings and Homebrew packages stay. \(reinstall)"
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
                    .foregroundStyle(state.isFailure ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
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
                Picker("JPEG quality", selection: $settings.jpegQuality) {
                    ForEach(QualityPreset.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            Toggle("Load gradually on the web", isOn: $settings.jpegProgressive)
        }

        PanelSection(title: "WebP") {
            LabeledContent("Quality") {
                Picker("WebP quality", selection: $settings.webpQuality) {
                    ForEach(QualityPreset.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
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
                Picker("RAW output", selection: $settings.photographyRAWOutput) {
                    ForEach(PhotographyRAWOutput.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            Toggle("Keep full color depth", isOn: $settings.photographyPreserve16Bit)

        case .animation:
            LabeledContent("Frame rate") {
                Picker("Frame rate", selection: $settings.animationFrameRate) {
                    ForEach(AnimationFrameRate.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            // A video loops where it's played, so it has no loop setting.
            if !settings.animationOutput.isVideo {
                LabeledContent("Loop") {
                    Picker("Loop", selection: $settings.animationLoopMode) {
                        ForEach(AnimationLoopMode.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            LabeledContent("Resize") {
                Picker("Resize", selection: $settings.animationResize) {
                    ForEach(AnimationResize.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabeledContent("Compression") {
                Picker("Compression", selection: $settings.animationCompression) {
                    ForEach(AnimationCompression.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabeledContent("Output") {
                Picker("Output", selection: $settings.animationOutput) {
                    ForEach(AnimationOutput.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

        case .legacyFormats:
            LabeledContent("Preferred output") {
                Picker("Preferred output", selection: $settings.legacyPreferredOutput) {
                    ForEach(LegacyPreferredOutput.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

        case .metadataCleaner:
            EmptyView()

        case .aiProvenance:
            Toggle("Look for AI labels when files are added", isOn: $settings.useAIProvenance)
            LabeledContent("AI labels") {
                Picker("AI labels", selection: $settings.aiLabelPolicy) {
                    ForEach(AILabelPolicy.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

        case .pdfTools:
            LabeledContent("Size") {
                Picker("Size", selection: $settings.pdfCompressionMode) {
                    ForEach(PDFCompressionMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabeledContent("Duplicate pages") {
                Picker("Duplicate pages", selection: $settings.pdfDuplicateMode) {
                    ForEach(PDFDuplicateMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
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
