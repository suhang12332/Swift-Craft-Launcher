//
//  HTMLToMarkdownConverter.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Converts the small, safe HTML dialect used by mod descriptions to Markdown.
///
/// This intentionally supports a whitelist instead of trying to implement a
/// browser. Unsupported elements keep their textual content and executable
/// elements are discarded.
enum HTMLToMarkdownConverter {
    fileprivate static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr",
    ]

    private static let ignoredTags: Set<String> = ["head", "script", "style", "template"]

    static func convert(_ html: String) -> String {
        let root = HTMLNode(tag: "root")
        HTMLParser.parse(html, into: root)

        let markdown = renderChildren(of: root)
        return normalize(markdown)
    }

    static func convertIfNeeded(_ content: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<\s*/?\s*(?:a|article|audio|b|blockquote|br|button|code|del|details|div|em|figure|h[1-6]|hr|i|img|li|ol|p|pre|s|section|strong|svg|table|td|th|tr|ul|video)(?:\s|/?>)"#,
            options: [.caseInsensitive],
        ) else {
            return content
        }

        let range = NSRange(content.startIndex..., in: content)
        return regex.firstMatch(in: content, range: range) == nil ? content : convert(content)
    }

    private static func renderChildren(of node: HTMLNode) -> String {
        node.children.map(render).joined()
    }

    private static func render(_ node: HTMLNode) -> String {
        guard !ignoredTags.contains(node.tag) else { return "" }

        switch node.tag {
        case "text":
            return decodeEntities(node.text)
        case "root", "body", "html", "span":
            return renderChildren(of: node)
        case "p", "div", "section", "article", "main", "header", "footer", "center", "figure":
            return block(renderChildren(of: node))
        case let tag where tag.count == 2 && tag.first == "h" && (1...6).contains(Int(tag.dropFirst()) ?? 0):
            let level = Int(tag.dropFirst()) ?? 1
            return block("\(String(repeating: "#", count: level)) \(renderChildren(of: node))")
        case "br":
            return "\n"
        case "hr":
            return "\n\n---\n\n"
        case "strong", "b":
            return wrap(renderChildren(of: node), prefix: "**", suffix: "**")
        case "em", "i":
            return wrap(renderChildren(of: node), prefix: "*", suffix: "*")
        case "s", "del":
            return wrap(renderChildren(of: node), prefix: "~~", suffix: "~~")
        case "code":
            return wrap(renderChildren(of: node), prefix: "`", suffix: "`")
        case "pre":
            let code = rawText(of: node).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return "" }
            return block("```\n\(code)\n```")
        case "a", "button":
            return renderAction(node)
        case "img":
            return renderImage(node)
        case "video", "audio":
            return renderMedia(node)
        case "svg":
            return renderSVG(node)
        case "ul":
            return renderList(node, ordered: false)
        case "ol":
            return renderList(node, ordered: true)
        case "li":
            return renderChildren(of: node)
        case "blockquote":
            let content = normalize(renderChildren(of: node))
            return block(content.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }.joined(separator: "\n"))
        case "table":
            return renderTable(node)
        case "thead", "tbody", "tfoot", "tr", "th", "td", "source":
            return renderChildren(of: node)
        default:
            return renderChildren(of: node)
        }
    }

    private static func renderAction(_ node: HTMLNode) -> String {
        let title = normalizeInline(renderChildren(of: node))
        guard !title.isEmpty else { return "" }

        let url = node.attributes["href"]
            ?? node.attributes["data-url"]
            ?? extractURL(from: node.attributes["onclick"])

        guard let url, isSafeURL(url) else {
            return node.tag == "button" ? wrap(title, prefix: "**", suffix: "**") : title
        }

        return "[\(title)](\(escapeMarkdownURL(url)))"
    }

    private static func renderImage(_ node: HTMLNode) -> String {
        guard let source = node.attributes["src"], isSafeURL(source) else {
            return normalizeInline(node.attributes["alt"] ?? "")
        }

        let alt = normalizeInline(node.attributes["alt"] ?? "image")
        return "![\(alt)](\(escapeMarkdownURL(source)))"
    }

    private static func renderMedia(_ node: HTMLNode) -> String {
        let source = node.attributes["src"] ?? findSource(in: node)
        guard let source, isSafeURL(source) else {
            return normalizeInline(renderChildren(of: node))
        }

        let label = node.attributes["title"]
            ?? (node.tag == "video" ? "▶ Video" : "🔊 Audio")
        return "[\(normalizeInline(label))](\(escapeMarkdownURL(source)))"
    }

    private static func renderSVG(_ node: HTMLNode) -> String {
        let label = node.attributes["aria-label"]
            ?? node.attributes["title"]
            ?? normalizeInline(renderChildren(of: node))

        return label.isEmpty ? "[SVG]" : "[\(label)]"
    }

    private static func renderList(_ node: HTMLNode, ordered: Bool) -> String {
        var index = 1
        let items = node.children.filter { $0.tag == "li" }.map { item -> String in
            let contentLines = normalize(renderChildren(of: item))
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
            guard let firstLine = contentLines.first else {
                defer { index += 1 }
                return ""
            }

            let nestedLines = contentLines.dropFirst().map { "  \($0)" }
            defer { index += 1 }
            let marker = ordered ? "\(index)." : "-"
            return (["\(marker) \(firstLine)"] + nestedLines).joined(separator: "\n")
        }

        return block(items.joined(separator: "\n"))
    }

    private static func renderTable(_ node: HTMLNode) -> String {
        let rows = tableRows(in: node)
        guard let firstRow = rows.first, !firstRow.isEmpty else { return "" }

        let columnCount = rows.map(\.count).max() ?? firstRow.count
        let normalizedRows = rows.map { row in
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }
        let header = normalizedRows[0].map { escapeTableCell(normalizeInline($0)) }
        let separator = Array(repeating: "---", count: columnCount)
        let body = normalizedRows.dropFirst().map { row in
            "| " + row.map { escapeTableCell(normalizeInline($0)) }.joined(separator: " | ") + " |"
        }

        return block(([
            "| " + header.joined(separator: " | ") + " |",
            "| " + separator.joined(separator: " | ") + " |",
        ] + body).joined(separator: "\n"))
    }

    private static func tableRows(in node: HTMLNode) -> [[String]] {
        if node.tag == "tr" {
            return [node.children.filter { $0.tag == "th" || $0.tag == "td" }.map { renderChildren(of: $0) }]
        }
        return node.children.flatMap { tableRows(in: $0) }
    }

    private static func findSource(in node: HTMLNode) -> String? {
        for child in node.children {
            if child.tag == "source", let source = child.attributes["src"] {
                return source
            }
            if let source = findSource(in: child) {
                return source
            }
        }
        return nil
    }

    private static func rawText(of node: HTMLNode) -> String {
        let text = node.children.map { child in
            child.tag == "text" ? child.text : rawText(of: child)
        }
        return text.joined()
    }

    private static func extractURL(from onclick: String?) -> String? {
        guard let onclick else { return nil }
        let patterns = [
            #"(?:location(?:\.href)?|window\.open)\s*\(?\s*['\"]([^'\"]+)['\"]"#,
            #"(?:url|href)\s*[:=]\s*['\"]([^'\"]+)['\"]"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(onclick.startIndex..., in: onclick)
            if let match = regex.firstMatch(in: onclick, range: range), let urlRange = Range(match.range(at: 1), in: onclick) {
                return String(onclick[urlRange])
            }
        }
        return nil
    }

    private static func isSafeURL(_ value: String) -> Bool {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "minecraft"].contains(scheme)
    }

    private static func escapeMarkdownURL(_ value: String) -> String {
        value.replacingOccurrences(of: ")", with: "%29")
    }

    private static func block(_ value: String) -> String {
        let content = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? "" : "\n\n\(content)\n\n"
    }

    private static func wrap(_ value: String, prefix: String, suffix: String) -> String {
        let content = normalizeInline(value)
        return content.isEmpty ? "" : "\(prefix)\(content)\(suffix)"
    }

    private static func normalize(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let preservesMarkdownIndentation = line.hasPrefix("  ")
                    && (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ "))
                return preservesMarkdownIndentation ? String(line).trimmingCharacters(in: .newlines) : trimmed
            }
            .joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeInline(_ value: String) -> String {
        decodeEntities(value)
            .replacingOccurrences(of: "\n", with: " ")
            .split { $0 == " " || $0 == "\t" }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ value: String) -> String {
        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&nbsp;": " ",
        ]
        return entities.reduce(value) { result, entity in
            result.replacingOccurrences(of: entity.key, with: entity.value)
        }
    }

    private static func escapeTableCell(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}

private final class HTMLNode {
    let tag: String
    var attributes: [String: String] = [:]
    var children: [HTMLNode] = []
    var text = ""

    init(tag: String) {
        self.tag = tag
    }
}

private enum HTMLParser {
    static func parse(_ html: String, into root: HTMLNode) {
        var stack = [root]
        var cursor = html.startIndex

        while cursor < html.endIndex {
            guard let tagStart = html[cursor...].firstIndex(of: "<") else {
                appendText(String(html[cursor...]), to: stack.last)
                break
            }

            if tagStart > cursor {
                appendText(String(html[cursor..<tagStart]), to: stack.last)
            }

            if html[tagStart...].hasPrefix("<!--"), let commentEnd = html[tagStart...].range(of: "-->")?.upperBound {
                cursor = commentEnd
                continue
            }

            guard let tagEnd = findTagEnd(in: html, from: tagStart) else {
                appendText(String(html[tagStart...]), to: stack.last)
                break
            }

            let rawTag = String(html[html.index(after: tagStart)..<tagEnd])
            cursor = html.index(after: tagEnd)

            if rawTag.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("!") {
                continue
            }

            if rawTag.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/") {
                let closingTagName = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst()
                let closingTag = closingTagName.split { $0.isWhitespace }.first.map(String.init)?.lowercased()
                if let closingTag, let index = stack.lastIndex(where: { $0.tag == closingTag }), index > 0 {
                    stack.removeSubrange(index..<stack.count)
                }
                continue
            }

            let parsed = parseOpeningTag(rawTag)
            guard let tag = parsed.tag else { continue }

            let node = HTMLNode(tag: tag)
            node.attributes = parsed.attributes
            stack[stack.count - 1].children.append(node)

            if !parsed.isSelfClosing, !HTMLToMarkdownConverter.voidTags.contains(tag) {
                stack.append(node)
            }
        }
    }

    private static func appendText(_ text: String, to node: HTMLNode?) {
        guard let node, !text.isEmpty else { return }
        let child = HTMLNode(tag: "text")
        child.text = text
        node.children.append(child)
    }

    private static func findTagEnd(in html: String, from start: String.Index) -> String.Index? {
        var quote: Character?
        var cursor = html.index(after: start)
        while cursor < html.endIndex {
            let character = html[cursor]
            if character == "'" || character == "\"" {
                quote = quote == character ? nil : (quote == nil ? character : quote)
            } else if character == ">" && quote == nil {
                return cursor
            }
            cursor = html.index(after: cursor)
        }
        return nil
    }

    private static func parseOpeningTag(_ rawTag: String) -> (tag: String?, attributes: [String: String], isSelfClosing: Bool) {
        var value = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSelfClosing = value.hasSuffix("/")
        if isSelfClosing {
            value.removeLast()
            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let name = value.prefix { !$0.isWhitespace }
        guard !name.isEmpty else { return (nil, [:], isSelfClosing) }

        var attributes: [String: String] = [:]
        var cursor = value.index(value.startIndex, offsetBy: name.count)

        while cursor < value.endIndex {
            while cursor < value.endIndex, value[cursor].isWhitespace { cursor = value.index(after: cursor) }
            guard cursor < value.endIndex else { break }

            let keyStart = cursor
            while cursor < value.endIndex, !value[cursor].isWhitespace, value[cursor] != "=" {
                cursor = value.index(after: cursor)
            }
            let key = String(value[keyStart..<cursor]).lowercased()
            while cursor < value.endIndex, value[cursor].isWhitespace { cursor = value.index(after: cursor) }

            var attributeValue = ""
            if cursor < value.endIndex, value[cursor] == "=" {
                cursor = value.index(after: cursor)
                while cursor < value.endIndex, value[cursor].isWhitespace { cursor = value.index(after: cursor) }
                if cursor < value.endIndex, value[cursor] == "'" || value[cursor] == "\"" {
                    let quote = value[cursor]
                    cursor = value.index(after: cursor)
                    let valueStart = cursor
                    while cursor < value.endIndex, value[cursor] != quote { cursor = value.index(after: cursor) }
                    attributeValue = String(value[valueStart..<cursor])
                    if cursor < value.endIndex { cursor = value.index(after: cursor) }
                } else {
                    let valueStart = cursor
                    while cursor < value.endIndex, !value[cursor].isWhitespace { cursor = value.index(after: cursor) }
                    attributeValue = String(value[valueStart..<cursor])
                }
            }

            if !key.isEmpty { attributes[key] = attributeValue }
        }

        return (String(name).lowercased(), attributes, isSelfClosing)
    }
}
