import Foundation

// MARK: - Home options

/// One thing the Home wizard offers for the files at hand: a plugin's job, a
/// routine, or the AI label check, worded for these files, with the expected
/// size when it is known.
struct HomeOption: Identifiable {
    let action: CompressionModel.HomeAction
    let title: String
    let detail: String
    /// A routine shows its symbol; a plugin's job shows the plugin's tile.
    let symbol: String?
    let plugin: ExtensionID?
    /// Expected total size after the job, from a real trial run; nil when
    /// there is none.
    var estimatedBytes: Int64? = nil
    /// An estimate for this option is being worked out.
    var isEstimating = false

    var id: CompressionModel.HomeAction { action }
}

extension CompressionModel {
    /// The options for the waiting files: the ones that fit them best first,
    /// then the rest that still make sense.
    func homeOptions(canRemoveDetails: Bool) -> (main: [HomeOption], more: [HomeOption]) {
        let kinds = Set(waitingKinds.map(\.kind))
        guard !kinds.isEmpty else { return ([], []) }
        let tools = toolsForWaitingFiles
        let fitting = Routine.allCases.filter { $0.fits(kinds) }

        // The routines that suit each kind best. Plugins' own jobs always
        // come first; within each group the largest result comes first, so
        // the list reads from gentlest to smallest.
        let leading: [Routine] = switch kinds {
        case [.pdf]: [.print, .email]
        case [.image]: [.chat, .website]
        case [.photo]: [.print, .chat]
        case [.animation]: [.chat, .website]
        case [.legacy]: [.keep]
        case [.document]: []
        default: [.chat, .email]
        }

        let routineOptions = leading.filter(fitting.contains).map { routineOption($0, kinds: kinds, canRemoveDetails: canRemoveDetails) }
        let toolOptions = tools.map(toolOption)
        let main = largestFirst(toolOptions) + largestFirst(routineOptions)
        // My Settings always close the other options: the same choice for
        // every file, for people who'd rather set it themselves.
        let more = largestFirst(fitting.filter { !leading.contains($0) && $0 != .custom }.map { routineOption($0, kinds: kinds, canRemoveDetails: canRemoveDetails) })
            + (fitting.contains(.custom) ? [routineOption(.custom, kinds: kinds, canRemoveDetails: canRemoveDetails)] : [])
        return (main, more)
    }

    /// By expected size, largest first; options without an estimate keep
    /// their place ahead of them, in their own order.
    private func largestFirst(_ options: [HomeOption]) -> [HomeOption] {
        options.enumerated().sorted { lhs, rhs in
            let l = lhs.element.estimatedBytes ?? .max
            let r = rhs.element.estimatedBytes ?? .max
            return l != r ? l > r : lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    private func routineOption(_ routine: Routine, kinds: Set<FileKind>, canRemoveDetails: Bool) -> HomeOption {
        let title: String = switch routine {
        case .chat: "Send in a chat"
        case .email: "Send by email"
        case .website: "Put on a website"
        case .social: "Post on social media"
        case .print: "Prepare for print"
        case .keep: "Keep for later"
        case .custom: "Use my settings"
        }
        let summary = routine.summary(for: kinds, canRemoveDetails: canRemoveDetails)
        let mode: PDFCompressionMode = switch routine {
        case .print, .keep: .light
        case .email: .aggressive
        case .chat, .website, .social: .balanced
        case .custom: settings.pdfCompressionMode
        }
        return HomeOption(
            action: .routine(routine),
            title: title,
            detail: summary,
            symbol: routine.symbolName,
            plugin: nil,
            estimatedBytes: kinds == [.pdf] ? pdfEstimates[mode] : nil,
            isEstimating: kinds == [.pdf] && isEstimating && pdfEstimates[mode] == nil
        )
    }

    private func toolOption(_ tool: ExtensionID) -> HomeOption {
        switch tool {
        case .aiProvenance:
            return HomeOption(
                action: .checkLabels,
                title: "Check for AI labels",
                detail: "Files aren’t changed",
                symbol: nil,
                plugin: tool
            )
        case .pdfTools:
            return HomeOption(
                action: .tool(tool),
                title: "Make it smaller",
                detail: "Text stays selectable",
                symbol: nil,
                plugin: tool,
                estimatedBytes: pdfEstimates[settings.pdfCompressionMode],
                isEstimating: isEstimating && pdfEstimates[settings.pdfCompressionMode] == nil
            )
        case .markdown:
            return HomeOption(
                action: .tool(tool),
                title: "Turn into Markdown",
                detail: "Title, author and date on top",
                symbol: nil,
                plugin: tool
            )
        default:
            return HomeOption(
                action: .tool(tool),
                title: tool.workspaceAction.uppercasedFirst,
                detail: tool.title,
                symbol: nil,
                plugin: tool
            )
        }
    }
}
