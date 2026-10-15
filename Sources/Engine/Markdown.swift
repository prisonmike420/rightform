import Foundation
import PDFKit

// MARK: - Markdown

/// Turns a document into a Markdown note. The text and what's known about
/// the document come from Defuddle for a web page, Pandoc for Office,
/// OpenDocument, RTF and EPUB files, and PDFKit for a PDF's text; Knap then
/// writes them into the note's template. Everything runs on this Mac.
enum MarkdownTools {
    static let defuddleScript = "node_modules/defuddle/dist/cli.js"
    static let knapScript = "node_modules/knap/dist/cli.js"
    static var scripts: [String] { [defuddleScript, knapScript] }

    /// Written into the plugin's folder when it's installed.
    static var supportFiles: [(name: String, contents: String)] {
        [(templateName, template), (cleanupFilterName, cleanupFilter), (metadataTemplateName, metadataTemplate)]
    }
    static var files: [String] { scripts + supportFiles.map(\.name) }

    /// Pictures stay behind in the original: the note is one file that can
    /// be copied or shared on its own. Their descriptions stay in the text.
    /// The sections and anchors EPUB and HTML wrap text in are let go of too,
    /// so they don't show up as HTML in the note.
    static let cleanupFilterName = "cleanup.lua"
    static let cleanupFilter = """
    function Figure(figure)
      return figure.caption.long
    end

    function Image(image)
      return image.caption
    end

    function Div(div)
      return div.content
    end

    function Span(span)
      return span.content
    end

    """

    /// Pandoc's own template for a document's details, as JSON.
    static let metadataTemplateName = "metadata.pandoc"
    static let metadataTemplate = "$meta-json$\n"

    static let templateName = "note.knap"
    /// The note: what's known about the page as frontmatter, then its text.
    /// Details the page doesn't have are left out, and so is the frontmatter
    /// when there are none.
    static let template = """
    {% if title or author or site or published or description %}
    ---
    {% if title %}
    {{ title | yaml_property:"title" }}
    {% endif %}
    {% if author %}
    {{ author | yaml_property:"author" }}
    {% endif %}
    {% if site %}
    {{ site | yaml_property:"site" }}
    {% endif %}
    {% if published %}
    {{ published | yaml_property:"published" }}
    {% endif %}
    {% if description %}
    {{ description | yaml_property:"description" }}
    {% endif %}
    ---

    {% endif %}
    {{ content }}

    """

    static func convert(input: URL, format: ImageFormat, output: URL, cancellation: CancellationToken?) throws {
        let root = ExtensionRegistry.root(for: .markdown)
        guard ExtensionRegistry.isInstalled(.markdown), let node = Toolchain.locate("node") else {
            throw CompressionError.message("Install the “Markdown” plugin for this file.")
        }
        let page = output.deletingLastPathComponent().appendingPathComponent(".stou-page-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: page) }

        switch format {
        case .html:
            try readWebPage(input, into: page, node: node, root: root)
        case .pdf:
            try write(readPDF(input), to: page)
        default:
            try write(readDocument(input, format: format, root: root, cancellation: cancellation), to: page)
        }
        try cancellation?.check()

        try ProcessRunner.run(node, [
            root.appendingPathComponent(knapScript).path,
            "render", root.appendingPathComponent(templateName).path,
            "--data", page.path, "--output", output.path
        ])
        try cancellation?.check()
        try verify(output)
    }

    /// Defuddle writes the page's main text and details as JSON.
    private static func readWebPage(_ input: URL, into page: URL, node: URL, root: URL) throws {
        let parsed = try ProcessRunner.runWithStatus(node, [
            root.appendingPathComponent(defuddleScript).path,
            "parse", input.path, "--json", "--markdown", "--output", page.path
        ])
        guard parsed.status == 0 else {
            // Defuddle names the file it couldn't read; the row already does.
            if parsed.stderr.contains("No content could be extracted") {
                throw CompressionError.message("No text found on this page.")
            }
            let message = parsed.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CompressionError.message(message.isEmpty ? "Defuddle couldn’t read this page." : message)
        }
        guard let data = try? Data(contentsOf: page),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompressionError.message("No text found on this page.")
        }
    }

    /// Pandoc reads the document twice: its details, then its text as
    /// GitHub Markdown. `--sandbox` keeps it to the files named here.
    private static func readDocument(_ input: URL, format: ImageFormat, root: URL, cancellation: CancellationToken?) throws -> [String: Any] {
        guard let pandoc = Toolchain.locate("pandoc") else {
            throw CompressionError.message("Pandoc is missing. Install the “Markdown” plugin again.")
        }
        var reader = ["--sandbox", "--from", format.fileExtension, input.path]
        let metadataArguments = ["--to", "plain", "--template", root.appendingPathComponent(metadataTemplateName).path]
        let metadata: String
        var repaired: URL?
        defer { if let repaired { try? FileManager.default.removeItem(at: repaired.deletingLastPathComponent()) } }
        do {
            metadata = try ProcessRunner.run(pandoc, reader + metadataArguments)
        } catch where [.docx, .pptx, .xlsx].contains(format) {
            // Some apps write Office files Pandoc can't follow; read a tidied copy.
            guard let copy = try? repairedOfficeCopy(of: input) else { throw error }
            repaired = copy
            reader[reader.count - 1] = copy.path
            guard let retried = try? ProcessRunner.run(pandoc, reader + metadataArguments) else { throw error }
            metadata = retried
        }
        try cancellation?.check()
        let content = try ProcessRunner.run(pandoc, reader + [
            "--to", "gfm", "--wrap", "none",
            "--lua-filter", root.appendingPathComponent(cleanupFilterName).path
        ])
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompressionError.message("No text found in this file.")
        }
        let details = (try? JSONSerialization.jsonObject(with: Data(metadata.utf8)) as? [String: Any]) ?? [:]
        var note: [String: Any] = ["content": content]
        note["title"] = details["title"]
        note["author"] = details["author"]
        note["published"] = details["date"]
        note["description"] = details["description"] ?? details["subject"]
        return note
    }

    /// A copy of an Office file with what Pandoc trips over put right, as
    /// Office itself reads it: a byte-order mark before a part's XML, and
    /// relationships that point at parts by absolute paths ("/xl/workbook.xml").
    private static func repairedOfficeCopy(of input: URL) throws -> URL {
        let fileManager = FileManager.default
        let work = fileManager.temporaryDirectory.appendingPathComponent("stou-office-\(UUID().uuidString)")
        let parts = work.appendingPathComponent("parts")
        try fileManager.createDirectory(at: parts, withIntermediateDirectories: true)
        let ditto = URL(fileURLWithPath: "/usr/bin/ditto")
        do {
            try ProcessRunner.run(ditto, ["-x", "-k", input.path, parts.path])
            let byteOrderMark = Data([0xEF, 0xBB, 0xBF])
            let enumerator = fileManager.enumerator(at: parts, includingPropertiesForKeys: nil)
            while let file = enumerator?.nextObject() as? URL {
                let name = file.lastPathComponent.lowercased()
                guard name.hasSuffix(".xml") || name.hasSuffix(".rels") else { continue }
                var data = try Data(contentsOf: file)
                if data.starts(with: byteOrderMark) { data.removeFirst(byteOrderMark.count) }
                if name.hasSuffix(".rels"), let text = String(data: data, encoding: .utf8) {
                    // A part's relationships live in "<folder>/_rels/"; targets are relative to "<folder>".
                    let folder = file.deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath().pathComponents
                    let base = Array(folder.dropFirst(parts.resolvingSymlinksInPath().pathComponents.count))
                    data = Data(relativeTargets(text, from: base).utf8)
                }
                try data.write(to: file)
            }
            let copy = work.appendingPathComponent("copy." + input.pathExtension)
            try ProcessRunner.run(ditto, ["-c", "-k", parts.path, copy.path])
            return copy
        } catch {
            try? fileManager.removeItem(at: work)
            throw error
        }
    }

    /// Rewrites `Target="/a/b"` as a path relative to the folder `base`.
    private static func relativeTargets(_ rels: String, from base: [String]) -> String {
        guard let pattern = try? NSRegularExpression(pattern: #"Target="/([^"]*)""#) else { return rels }
        var result = rels
        for match in pattern.matches(in: rels, range: NSRange(rels.startIndex..., in: rels)).reversed() {
            guard let whole = Range(match.range, in: rels), let path = Range(match.range(at: 1), in: rels) else { continue }
            let target = rels[path].split(separator: "/").map(String.init)
            var shared = 0
            while shared < base.count, shared < target.count - 1, base[shared] == target[shared] { shared += 1 }
            let relative = Array(repeating: "..", count: base.count - shared) + target[shared...]
            result.replaceSubrange(whole, with: "Target=\"\(relative.joined(separator: "/"))\"")
        }
        return result
    }

    /// PDFKit reads the text layer, page by page, and the document's
    /// details. A scanned page has no text to read.
    private static func readPDF(_ input: URL) throws -> [String: Any] {
        guard let document = PDFDocument(url: input) else {
            throw CompressionError.message("Stou could not open this PDF.")
        }
        guard !document.isLocked else {
            throw CompressionError.message("This PDF is locked with a password. Unlock it in Preview, then try again.")
        }
        let pages = (0..<document.pageCount).compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let content = pages.filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !content.isEmpty else {
            throw CompressionError.message("No text found in this PDF. Scanned pages need text recognition first.")
        }
        let details = document.documentAttributes ?? [:]
        var note: [String: Any] = ["content": content]
        note["title"] = details[PDFDocumentAttribute.titleAttribute] as? String
        note["author"] = details[PDFDocumentAttribute.authorAttribute] as? String
        note["description"] = details[PDFDocumentAttribute.subjectAttribute] as? String
        return note
    }

    private static func write(_ note: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: note).write(to: url, options: .atomic)
    }

    /// The note is readable text that holds the page's text.
    static func verify(_ url: URL) throws {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompressionError.message("The Markdown note came out empty.")
        }
    }
}
