import Foundation

// Fuzzy matching for the command palette: every query character in order, ignoring case and spaces.
enum Fuzzy {
    // Higher is better. Runs of consecutive characters and matches at word starts score more. Nil when it does not match.
    static func score(_ query: String, in text: String) -> Int? {
        let needle = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !needle.isEmpty else { return 0 }
        let haystack = Array(text.lowercased())
        var score = 0
        var next = 0
        var previousMatch: Int?
        for (index, char) in haystack.enumerated() where next < needle.count && char == needle[next] {
            score += 1
            if previousMatch == index - 1 { score += 6 }
            if index == 0 || " /-_.{(".contains(haystack[index - 1]) { score += 3 }
            previousMatch = index
            next += 1
        }
        return next == needle.count ? score : nil
    }
}
