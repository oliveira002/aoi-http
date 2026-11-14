import Foundation

// The subset API specs use: block maps and lists, flow [ ] and { } (so all of JSON), quotes, | and > blocks, comments.
struct YAMLParser {
    private var lines: [String]
    private var index = 0
    private var anchors: [String: Node] = [:]

    static func parse(_ text: String) throws -> Node {
        var parser = YAMLParser(lines: text.components(separatedBy: .newlines))
        return try parser.document()
    }

    private init(lines: [String]) {
        self.lines = lines
    }

    private mutating func document() throws -> Node {
        while let line = peek(), line.text.hasPrefix("%") || line.text == "---" { index += 1 }
        guard let first = peek() else { return .null }
        if first.text.hasPrefix("{") || first.text.hasPrefix("[") {
            var flow = FlowParser(lines[index...].joined(separator: "\n"))
            return try flow.document()
        }
        let node = try block(indent: first.indent)
        if let line = peek(), line.text != "---", line.text != "..." {
            throw ImportError.syntax(line: index + 1, reason: "unexpected indentation")
        }
        return node
    }

    private mutating func block(indent: Int) throws -> Node {
        guard let line = peek() else { return .null }
        return Self.isListItem(line.text) ? try list(indent: indent) : try map(indent: indent)
    }

    private mutating func list(indent: Int) throws -> Node {
        var items: [Node] = []
        while let line = peek(), line.indent == indent, Self.isListItem(line.text) {
            let afterDash = lines[index].dropFirst(indent + 1)
            let (anchor, rest) = Self.takeAnchor(String(afterDash.drop { $0 == " " }))
            let content = Self.content(rest)
            let item: Node
            if content.isEmpty || content.hasPrefix("*") {
                index += 1
                item = try value(content, parentIndent: indent, allowsListAtSameIndent: false)
            // A flow item such as "- {type: string}" holds colons but is not a key, so it is read inline below.
            } else if !content.hasPrefix("{"), !content.hasPrefix("["), Self.isListItem(content) || Self.splitKey(content) != nil {
                // Re-read "- key: value" as a map that starts at the column after the dash.
                let itemIndent = indent + 1 + (afterDash.count - rest.count)
                lines[index] = String(repeating: " ", count: itemIndent) + rest
                item = try block(indent: itemIndent)
            } else {
                index += 1
                item = try inline(content, parentIndent: indent)
            }
            if let anchor { anchors[anchor] = item }
            items.append(item)
        }
        return .list(items)
    }

    private mutating func map(indent: Int) throws -> Node {
        var entries: [(key: String, value: Node)] = []
        while let line = peek(), line.indent == indent, !Self.isListItem(line.text) {
            guard let (key, rest) = Self.splitKey(line.text) else {
                throw ImportError.syntax(line: index + 1, reason: "expected \"key: value\"")
            }
            index += 1
            let node = try value(rest, parentIndent: indent, allowsListAtSameIndent: true)
            if key == "<<" {
                // Merge keys: entries written out in this map win over merged ones.
                let merged = node.entries + node.items.flatMap(\.entries)
                entries += merged.filter { item in !entries.contains { $0.key == item.key } }
            } else {
                entries.removeAll { $0.key == key }
                entries.append((key, node))
            }
        }
        return .map(entries)
    }

    // The value after "key:" or "- " once that line is consumed, with an optional &anchor or a *alias.
    private mutating func value(_ text: String, parentIndent: Int, allowsListAtSameIndent: Bool) throws -> Node {
        let (anchor, text) = Self.takeAnchor(text)
        let node: Node
        if text.hasPrefix("*") {
            let name = String(text.dropFirst())
            guard let target = anchors[name] else {
                throw ImportError.syntax(line: index, reason: "unknown alias *\(name)")
            }
            node = target
        } else if !text.isEmpty {
            node = try inline(text, parentIndent: parentIndent)
        } else if let next = peek(), next.indent > parentIndent {
            node = try block(indent: next.indent)
        } else if allowsListAtSameIndent, let next = peek(), next.indent == parentIndent, Self.isListItem(next.text) {
            node = try list(indent: parentIndent)
        } else {
            node = .null
        }
        if let anchor { anchors[anchor] = node }
        return node
    }

    private static func anchor(in text: String) -> String? {
        guard text.hasPrefix("&") else { return nil }
        let name = text.dropFirst().prefix { $0 != " " }
        return name.isEmpty ? nil : String(name)
    }

    private mutating func inline(_ text: String, parentIndent: Int) throws -> Node {
        var text = text
        if text.hasPrefix("|") || text.hasPrefix(">") {
            return .scalar(blockScalar(header: text, parentIndent: parentIndent), plain: false)
        }
        if text.hasPrefix("[") || text.hasPrefix("{") || text.hasPrefix("\"") || text.hasPrefix("'") {
            var joined = text
            while true {
                var flow = FlowParser(joined)
                if let node = try? flow.document() { return node }
                guard index < lines.count else { break }
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                // A trailing backslash in a double-quoted string joins the lines without a space.
                let escapes = joined.reversed().prefix { $0 == "\\" }.count
                if escapes % 2 == 1 {
                    joined.removeLast()
                    joined += next
                } else {
                    joined += " " + next
                }
                index += 1
            }
            throw ImportError.syntax(line: index, reason: "unclosed quote or bracket")
        }
        while let next = peek(), next.indent > parentIndent {
            text += " " + next.text
            index += 1
        }
        return .scalar(text, plain: true)
    }

    private mutating func blockScalar(header: String, parentIndent: Int) -> String {
        var collected: [String] = []
        var blockIndent: Int?
        while index < lines.count {
            let raw = lines[index]
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                collected.append("")
                index += 1
                continue
            }
            let indent = Self.indent(of: raw)
            if indent <= parentIndent || indent < (blockIndent ?? indent) { break }
            let width = blockIndent ?? indent
            blockIndent = width
            collected.append(String(raw.dropFirst(width)))
            index += 1
        }
        var trailing = 0
        while collected.last == "" {
            collected.removeLast()
            trailing += 1
        }
        let text = header.hasPrefix(">")
            ? collected.split(separator: "", omittingEmptySubsequences: false).map { $0.joined(separator: " ") }.joined(separator: "\n")
            : collected.joined(separator: "\n")
        if header.contains("-") { return text }
        if header.contains("+") { return text + String(repeating: "\n", count: trailing + 1) }
        return text + "\n"
    }

    private mutating func peek() -> (indent: Int, text: String)? {
        while index < lines.count {
            let text = Self.content(lines[index])
            if !text.isEmpty { return (Self.indent(of: lines[index]), text) }
            index += 1
        }
        return nil
    }

    private static func indent(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func isListItem(_ text: String) -> Bool {
        text == "-" || text.hasPrefix("- ")
    }

    // The line without indentation, trailing spaces or a trailing comment.
    // "&name rest" split into the anchor's name and what follows it.
    private static func takeAnchor(_ text: String) -> (anchor: String?, rest: String) {
        guard let anchor = anchor(in: text) else { return (nil, text) }
        return (anchor, String(text.dropFirst(anchor.count + 1).drop { $0 == " " }))
    }

    private static func content(_ line: String) -> String {
        var quote: Character?
        var escaped = false
        var previous: Character = " "
        var end = line.endIndex
        for index in line.indices {
            let char = line[index]
            if let open = quote {
                // Double quotes escape with a backslash; single quotes escape by doubling ('').
                let next = line.index(after: index) < line.endIndex ? line[line.index(after: index)] : nil
                if escaped {
                    escaped = false
                } else if open == "\"", char == "\\" {
                    escaped = true
                } else if open == "'", char == "'", next == "'" {
                    escaped = true
                } else if char == open {
                    quote = nil
                }
            } else if char == "\"" || char == "'", previous == " " || previous == ":" || previous == "[" || previous == "{" || previous == "," || previous == "-" {
                quote = char
            } else if char == "#", previous == " " || previous == "\t" {
                end = index
                break
            }
            previous = char
        }
        return line[..<end].trimmingCharacters(in: .whitespaces)
    }

    private static func splitKey(_ text: String) -> (String, String)? {
        if let first = text.first, first == "\"" || first == "'" {
            var flow = FlowParser(text)
            guard let (key, rest) = flow.leadingQuoted(), rest.hasPrefix(":") else { return nil }
            return (key, String(rest.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        var index = text.startIndex
        while let colon = text[index...].firstIndex(of: ":") {
            let after = text.index(after: colon)
            if after == text.endIndex || text[after] == " " {
                let key = text[..<colon].trimmingCharacters(in: .whitespaces)
                return (key, String(text[after...]).trimmingCharacters(in: .whitespaces))
            }
            index = after
        }
        return nil
    }
}
