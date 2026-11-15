import SwiftUI

// The colour of each JSON token, shared by the response view and the body editor.
enum JSONSyntax {
    // Colouring a bigger body would stall typing and scrolling.
    static let highlightLimit = 300_000

    // One pass over the UTF-8 bytes. It runs on every keystroke in the body editor, where a Regex was ten
    // times slower. Strings (keys when a colon follows), numbers, and whole-word true, false and null.
    static func tokens(in text: String) -> [(range: Range<String.Index>, color: Color)] {
        var scanner = Scanner(text.utf8)
        var tokens: [(range: Range<String.Index>, color: Color)] = []
        while let byte = scanner.current {
            let start = scanner.index
            if byte == UInt8(ascii: "\""), !scanner.pastUnclosedString, scanner.skipString() {
                let end = scanner.index
                tokens.append((start..<end, scanner.followedByColon() ? Theme.JSONColors.key : Theme.JSONColors.string))
            } else if scanner.skipNumber() {
                tokens.append((start..<scanner.index, Theme.JSONColors.number))
            } else if let keyword = scanner.skipKeyword() {
                tokens.append((start..<scanner.index, keyword == "null" ? Theme.JSONColors.null : Theme.JSONColors.boolean))
            } else {
                scanner.advance()
            }
        }
        return tokens
    }

    private struct Scanner {
        let bytes: String.UTF8View
        private(set) var index: String.Index
        // Once a string runs to the end without closing, every later quote sits inside it as an escaped
        // quote, so none can close either. Remembering that keeps a half-typed body from going quadratic.
        private(set) var pastUnclosedString = false

        init(_ bytes: String.UTF8View) {
            self.bytes = bytes
            index = bytes.startIndex
        }

        var current: UInt8? { index < bytes.endIndex ? bytes[index] : nil }

        mutating func advance() { index = bytes.index(after: index) }

        // A quoted string with backslash escapes. Without a closing quote it is not a string, and nothing is skipped.
        mutating func skipString() -> Bool {
            let start = index
            advance()
            while let byte = current {
                advance()
                if byte == UInt8(ascii: "\\") {
                    if current != nil { advance() }
                } else if byte == UInt8(ascii: "\"") {
                    return true
                }
            }
            index = start
            pastUnclosedString = true
            return false
        }

        // Whether a colon comes next, past any whitespace, without moving.
        func followedByColon() -> Bool {
            var probe = index
            while probe < bytes.endIndex, Self.isSpace(bytes[probe]) { probe = bytes.index(after: probe) }
            return probe < bytes.endIndex && bytes[probe] == UInt8(ascii: ":")
        }

        // -?\d+(\.\d+)?([eE][+-]?\d+)?, where each optional part needs its own digits.
        mutating func skipNumber() -> Bool {
            let start = index
            if current == UInt8(ascii: "-") { advance() }
            guard skipDigits() else {
                index = start
                return false
            }
            optionally { scanner in
                guard scanner.current == UInt8(ascii: ".") else { return false }
                scanner.advance()
                return scanner.skipDigits()
            }
            optionally { scanner in
                guard scanner.current == UInt8(ascii: "e") || scanner.current == UInt8(ascii: "E") else { return false }
                scanner.advance()
                if scanner.current == UInt8(ascii: "+") || scanner.current == UInt8(ascii: "-") { scanner.advance() }
                return scanner.skipDigits()
            }
            return true
        }

        // true, false or null as a whole word.
        mutating func skipKeyword() -> String? {
            guard !precededByWordCharacter() else { return nil }
            let rest = bytes[index...]
            for keyword in ["true", "false", "null"] where rest.starts(with: keyword.utf8) {
                let end = bytes.index(index, offsetBy: keyword.utf8.count)
                guard end == bytes.endIndex || !Self.isWord(bytes[end]) else { return nil }
                index = end
                return keyword
            }
            return nil
        }

        private mutating func skipDigits() -> Bool {
            let start = index
            while let byte = current, Self.isDigit(byte) { advance() }
            return index > start
        }

        // Runs a part that may not be there; if it does not complete, the scanner is put back.
        private mutating func optionally(_ part: (inout Scanner) -> Bool) {
            let start = index
            if !part(&self) { index = start }
        }

        private func precededByWordCharacter() -> Bool {
            index > bytes.startIndex && Self.isWord(bytes[bytes.index(before: index)])
        }

        private static func isDigit(_ byte: UInt8) -> Bool { (48...57).contains(byte) }

        // Letters, digits and underscore, plus any non-ASCII byte, which belongs to a letter in practice.
        private static func isWord(_ byte: UInt8) -> Bool {
            isDigit(byte) || (65...90).contains(byte) || (97...122).contains(byte) || byte == UInt8(ascii: "_") || byte >= 0x80
        }

        private static func isSpace(_ byte: UInt8) -> Bool {
            byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\r")
        }
    }
}
