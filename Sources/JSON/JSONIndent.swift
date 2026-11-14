import Foundation

// Indentation while typing JSON. Pure text maths, so the editor only applies the edit.
enum JSONIndent {
    static let unit = "  "

    struct Edit: Equatable {
        let range: NSRange
        let text: String
        // Where the cursor goes afterwards, in the edited text.
        let cursor: Int
    }

    // Keeps the line's indentation, indents after { or [, and puts a closing bracket right after the cursor on its own line.
    static func newline(in text: String, replacing selection: NSRange) -> Edit {
        let string = text as NSString
        let lineStart = string.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let before = string.substring(with: NSRange(location: lineStart, length: selection.location - lineStart))
        let indent = String(before.prefix { $0 == " " })
        let opens = before.trimmingCharacters(in: .whitespaces).last.map { $0 == "{" || $0 == "[" } ?? false
        guard opens else {
            let insertion = "\n" + indent
            return Edit(range: selection, text: insertion, cursor: selection.location + (insertion as NSString).length)
        }
        let after = NSMaxRange(selection) < string.length ? string.substring(with: NSRange(location: NSMaxRange(selection), length: 1)) : ""
        let inner = "\n" + indent + unit
        let closing = after == "}" || after == "]" ? "\n" + indent : ""
        return Edit(range: selection, text: inner + closing, cursor: selection.location + (inner as NSString).length)
    }

    // A closing bracket typed on an otherwise blank line moves back one level; nil when it should go in as typed.
    static func closingBracket(_ typed: String, in text: String, at location: Int) -> Edit? {
        guard typed == "}" || typed == "]" else { return nil }
        let string = text as NSString
        let lineStart = string.lineRange(for: NSRange(location: location, length: 0)).location
        let before = string.substring(with: NSRange(location: lineStart, length: location - lineStart))
        let width = (unit as NSString).length
        guard before.count >= width, before.allSatisfy({ $0 == " " }) else { return nil }
        return Edit(range: NSRange(location: location - width, length: width), text: typed, cursor: location - width + 1)
    }
}
