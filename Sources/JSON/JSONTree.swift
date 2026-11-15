import SwiftUI

// Paths and previews for a parsed JSON tree. Paths read like "$.data[0].id".
enum JSONTree {
    static let page = 50

    static func defaultExpanded(_ root: Node, levels: Int) -> Set<String> {
        containerPaths(root, path: "$", maxDepth: levels - 1)
    }

    static func containerPaths(_ node: Node, path: String, maxDepth: Int = .max, depth: Int = 0) -> Set<String> {
        guard depth <= maxDepth, !node.isScalar else { return [] }
        return children(of: node, path: path).reduce(into: [path]) {
            $0.formUnion(containerPaths($1.node, path: $1.path, maxDepth: maxDepth, depth: depth + 1))
        }
    }

    struct Child {
        let label: String
        let isIndex: Bool
        let path: String
        let node: Node
    }

    // The single place child paths are built, so rows, expanding and search always agree.
    // A repeated key gets a suffix, so every row keeps its own identity.
    static func children(of node: Node, path: String, limit: Int = .max) -> [Child] {
        switch node {
        case .map(let entries):
            var seen: [String: Int] = [:]
            return entries.prefix(limit).map { entry in
                let repeats = seen[entry.key, default: 0]
                seen[entry.key] = repeats + 1
                return Child(label: entry.key, isIndex: false, path: path + component(entry.key) + (repeats == 0 ? "" : "#\(repeats)"), node: entry.value)
            }
        case .list(let items):
            return items.prefix(limit).enumerated().map { Child(label: "\($0.offset)", isIndex: true, path: "\(path)[\($0.offset)]", node: $0.element) }
        default:
            return []
        }
    }

    struct Match {
        let path: String
        // Each container on the way down, with the position of the next step inside it.
        let ancestors: [(path: String, index: Int)]
    }

    static let matchLimit = 1000

    // Rows whose key or value contains the query, in display order. Plain case-insensitive matching on the
    // raw value: locale-aware matching and rendering each value as JSON made typing lag on big responses.
    // A query with a quote or backslash still matches the JSON form, so "active" finds exact strings.
    static func search(_ root: Node, for query: String) -> [Match] {
        var matches: [Match] = []
        let asJSON = query.contains { $0 == "\"" || $0 == "\\" }
        func contains(_ text: String?) -> Bool {
            text?.range(of: query, options: .caseInsensitive) != nil
        }
        func visit(_ node: Node, path: String, key: String?, ancestors: [(path: String, index: Int)]) {
            guard matches.count < matchLimit else { return }
            let keyHit = contains(key)
            let valueHit = node.isScalar && contains(asJSON ? node.json : node.string ?? "null")
            if keyHit || valueHit { matches.append(Match(path: path, ancestors: ancestors)) }
            for (index, child) in children(of: node, path: path).enumerated() {
                visit(child.node, path: child.path, key: child.isIndex ? nil : child.label, ancestors: ancestors + [(path, index)])
            }
        }
        visit(root, path: "$", key: nil, ancestors: [])
        return matches
    }

    // True for the path itself and anything below it, but not for siblings like $.ab next to $.a.
    static func isPath(_ candidate: String, inside path: String) -> Bool {
        candidate == path || candidate.hasPrefix(path + ".") || candidate.hasPrefix(path + "[") || candidate.hasPrefix(path + "#")
    }

    static func component(_ key: String) -> String {
        isIdentifier(key) ? ".\(key)" : "[\(Node.scalar(key, plain: false).json)]"
    }

    // [A-Za-z_$][A-Za-z0-9_$]*, checked byte by byte: this runs for every key in the tree.
    private static func isIdentifier(_ key: String) -> Bool {
        func isStart(_ byte: UInt8) -> Bool {
            (65...90).contains(byte) || (97...122).contains(byte) || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "$")
        }
        guard let first = key.utf8.first, isStart(first) else { return false }
        return key.utf8.allSatisfy { isStart($0) || (48...57).contains($0) }
    }

    // One line that stands in for a collapsed object or list.
    static func preview(_ node: Node) -> String {
        switch node {
        case .map(let entries):
            if entries.isEmpty { return "{}" }
            let parts = entries.prefix(3).map { "\($0.key): \(short($0.value))" }
            return "{ " + parts.joined(separator: ", ") + (entries.count > 3 ? ", …" : "") + " }"
        case .list(let items):
            if items.isEmpty { return "[]" }
            if items.allSatisfy(\.isScalar) {
                return "[" + items.prefix(5).map(short).joined(separator: ", ") + (items.count > 5 ? ", …" : "") + "]"
            }
            return items.count == 1 ? "1 item" : "\(items.count) items"
        default:
            return short(node)
        }
    }

    static func short(_ node: Node) -> String {
        switch node {
        case .map: return "{…}"
        case .list(let items): return "[\(items.count)]"
        default:
            let text = node.json
            return text.count > 40 ? String(text.prefix(38)) + "…\"" : text
        }
    }

    static func color(_ node: Node) -> Color {
        switch node {
        case .scalar(_, plain: false): return Theme.JSONColors.string
        case .scalar("true", plain: true), .scalar("false", plain: true): return Theme.JSONColors.boolean
        case .scalar("null", plain: true), .null: return Theme.JSONColors.null
        default: return Theme.JSONColors.number
        }
    }

    // A string value that is a web link, so it can be opened with a click.
    static func link(_ node: Node) -> URL? {
        guard case .scalar(let text, plain: false) = node, text.hasPrefix("http://") || text.hasPrefix("https://") else { return nil }
        return URL(string: text)
    }

    struct Row: Identifiable {
        enum Kind { case node(Node), more(parent: String, remaining: Int) }
        let id: String
        let depth: Int
        let label: String?
        let isIndex: Bool
        let kind: Kind
    }

    // Only the rows that are open, each container paged by `shown` (default one page), so a huge response stays fast.
    static func visibleRows(of root: Node, expanded: Set<String>, shown: [String: Int]) -> [Row] {
        var rows: [Row] = []
        func visit(_ node: Node, path: String, depth: Int, label: String?, isIndex: Bool) {
            rows.append(Row(id: path, depth: depth, label: label, isIndex: isIndex, kind: .node(node)))
            guard expanded.contains(path), let count = node.count else { return }
            let limit = shown[path] ?? page
            for child in children(of: node, path: path, limit: limit) {
                visit(child.node, path: child.path, depth: depth + 1, label: child.label, isIndex: child.isIndex)
            }
            if count > limit {
                rows.append(Row(id: path + "#more", depth: depth + 1, label: nil, isIndex: false, kind: .more(parent: path, remaining: count - limit)))
            }
        }
        visit(root, path: "$", depth: 0, label: nil, isIndex: false)
        return rows
    }
}
