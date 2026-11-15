import Foundation

// Find in a raw body: every case-insensitive match of the query, and which one is current.
struct TextSearch {
    static let matchLimit = 1000

    private(set) var matches: [Range<String.Index>] = []
    private(set) var current = 0

    init(_ query: String = "", in text: String = "") {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return }
        var rest = text.startIndex..<text.endIndex
        while matches.count < Self.matchLimit, let match = text.range(of: needle, options: .caseInsensitive, range: rest) {
            matches.append(match)
            rest = match.upperBound..<text.endIndex
        }
    }

    var currentMatch: Range<String.Index>? { matches.indices.contains(current) ? matches[current] : nil }

    // "No matches", or "2 of 14" with a "+" when the search stopped at its limit.
    var summary: String {
        guard !matches.isEmpty else { return "No matches" }
        return "\(current + 1) of \(matches.count)\(matches.count == Self.matchLimit ? "+" : "")"
    }

    mutating func step(_ offset: Int) {
        guard !matches.isEmpty else { return }
        current = (current + offset + matches.count) % matches.count
    }
}

extension String {
    // Zero-based line and column of an index. "\r\n" is one Character, so it counts as one line break.
    func position(of index: Index) -> (line: Int, column: Int) {
        var line = 0
        var column = 0
        for character in self[..<index] {
            if character.isNewline {
                line += 1
                column = 0
            } else {
                column += 1
            }
        }
        return (line, column)
    }
}
