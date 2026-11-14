import Foundation

// Find in a response: the matches for a query and which one is current.
struct JSONSearch {
    enum Mark { case none, match, current }

    private(set) var matches: [JSONTree.Match] = []
    private(set) var current = 0
    private var paths: Set<String> = []

    init() {}

    init(_ query: String, in root: Node) {
        let text = query.trimmingCharacters(in: .whitespaces)
        matches = text.isEmpty ? [] : JSONTree.search(root, for: text)
        paths = Set(matches.map(\.path))
    }

    var currentMatch: JSONTree.Match? { matches.indices.contains(current) ? matches[current] : nil }

    // "No matches", or "2 of 14" with a "+" when the search stopped at its limit.
    var summary: String {
        guard !matches.isEmpty else { return "No matches" }
        return "\(current + 1) of \(matches.count)\(matches.count == JSONTree.matchLimit ? "+" : "")"
    }

    mutating func step(_ offset: Int) {
        guard !matches.isEmpty else { return }
        current = (current + offset + matches.count) % matches.count
    }

    func mark(_ path: String) -> Mark {
        guard let currentMatch else { return .none }
        if currentMatch.path == path { return .current }
        return paths.contains(path) ? .match : .none
    }

    // Opens the tree, and pages far enough, to list the current match. Only that one, so a broad query
    // does not leave the whole tree open.
    func reveal(expanded: inout Set<String>, shown: inout [String: Int]) {
        for ancestor in currentMatch?.ancestors ?? [] {
            expanded.insert(ancestor.path)
            let needed = (ancestor.index / JSONTree.page + 1) * JSONTree.page
            if needed > shown[ancestor.path, default: JSONTree.page] { shown[ancestor.path] = needed }
        }
    }
}
