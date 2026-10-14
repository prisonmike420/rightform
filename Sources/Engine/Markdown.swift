import Foundation

// MARK: - Markdown

/// Turns a saved web page into a Markdown note: Defuddle finds the page's
/// main text and its details, then Knap writes them into the note's
/// template. Both run on this Mac with the plugin's own Node.js packages.
enum MarkdownTools {
    static let defuddleScript = "node_modules/defuddle/dist/cli.js"
    static let knapScript = "node_modules/knap/dist/cli.js"
    static var scripts: [String] { [defuddleScript, knapScript] }

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

    static func convert(input: URL, output: URL, cancellation: CancellationToken?) throws {
        let root = ExtensionRegistry.root(for: .markdown)
        guard ExtensionRegistry.isInstalled(.markdown), let node = Toolchain.locate("node") else {
            throw CompressionError.message("Install the “Markdown” plugin for web pages.")
        }
        let page = output.deletingLastPathComponent().appendingPathComponent(".stou-page-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: page) }

        let parsed = try ProcessRunner.runWithStatus(node, [
            root.appendingPathComponent(defuddleScript).path,
            "parse", input.path, "--json", "--markdown", "--output", page.path
        ])
        try cancellation?.check()
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

        try ProcessRunner.run(node, [
            root.appendingPathComponent(knapScript).path,
            "render", root.appendingPathComponent(templateName).path,
            "--data", page.path, "--output", output.path
        ])
        try cancellation?.check()
        try verify(output)
    }

    /// The note is readable text that holds the page's text.
    static func verify(_ url: URL) throws {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CompressionError.message("The Markdown note came out empty.")
        }
    }
}
