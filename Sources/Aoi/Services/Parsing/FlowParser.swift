import Foundation

// Flow style YAML, which is a superset of JSON.
struct FlowParser {
    private let chars: [Character]
    private var i = 0

    init(_ text: String) {
        chars = Array(text)
    }

    mutating func document() throws -> Node {
        let node = try value()
        skipSpace()
        guard i == chars.count else { throw ImportError.syntax(line: 1, reason: "unexpected text after value") }
        return node
    }

    mutating func leadingQuoted() -> (String, String)? {
        guard case .scalar(let text, false)? = try? value() else { return nil }
        return (text, String(chars[i...]).trimmingCharacters(in: .whitespaces))
    }

    private mutating func value() throws -> Node {
        skipSpace()
        guard i < chars.count else { throw ImportError.syntax(line: 1, reason: "unexpected end") }
        switch chars[i] {
        case "{": return try map()
        case "[": return try list()
        case "\"": return .scalar(try doubleQuoted(), plain: false)
        case "'": return .scalar(try singleQuoted(), plain: false)
        default: return .scalar(plain(), plain: true)
        }
    }

    private mutating func map() throws -> Node {
        i += 1
        var entries: [(key: String, value: Node)] = []
        while true {
            skipSpace()
            guard i < chars.count else { throw ImportError.syntax(line: 1, reason: "unclosed {") }
            if chars[i] == "}" { i += 1; break }
            let key = try value().string ?? ""
            skipSpace()
            var item = Node.null
            if i < chars.count, chars[i] == ":" {
                i += 1
                skipSpace()
                if i < chars.count, chars[i] != ",", chars[i] != "}" { item = try value() }
            }
            entries.append((key, item))
            try separator(closing: "}")
        }
        return .map(entries)
    }

    private mutating func list() throws -> Node {
        i += 1
        var items: [Node] = []
        while true {
            skipSpace()
            guard i < chars.count else { throw ImportError.syntax(line: 1, reason: "unclosed [") }
            if chars[i] == "]" { i += 1; break }
            items.append(try value())
            try separator(closing: "]")
        }
        return .list(items)
    }

    // Without this, a stray ":" or bracket would leave the parser stuck in place forever.
    private mutating func separator(closing: Character) throws {
        skipSpace()
        guard i < chars.count else { return }
        if chars[i] == "," {
            i += 1
        } else if chars[i] != closing {
            throw ImportError.syntax(line: 1, reason: "expected \",\" or \"\(closing)\" but found \"\(chars[i])\"")
        }
    }

    private mutating func doubleQuoted() throws -> String {
        i += 1
        var result = ""
        var pendingHigh: UInt32?
        while i < chars.count {
            let char = chars[i]
            i += 1
            if char == "\"" { return result }
            guard char == "\\", i < chars.count else {
                result.append(char)
                continue
            }
            let escape = chars[i]
            i += 1
            switch escape {
            case "n": result += "\n"
            case "t": result += "\t"
            case "r": result += "\r"
            case "b": result += "\u{8}"
            case "f": result += "\u{c}"
            case "0": result += "\0"
            case "u":
                guard i + 4 <= chars.count, let code = UInt32(String(chars[i..<i + 4]), radix: 16) else {
                    throw ImportError.syntax(line: 1, reason: "bad \\u escape")
                }
                i += 4
                if (0xD800..<0xDC00).contains(code) {
                    pendingHigh = code
                } else if let high = pendingHigh, (0xDC00..<0xE000).contains(code) {
                    let combined = 0x10000 + ((high - 0xD800) << 10) + (code - 0xDC00)
                    result.unicodeScalars.append(Unicode.Scalar(combined) ?? "?")
                    pendingHigh = nil
                } else {
                    result.unicodeScalars.append(Unicode.Scalar(code) ?? "?")
                }
            default: result.append(escape)
            }
        }
        throw ImportError.syntax(line: 1, reason: "unclosed string")
    }

    private mutating func singleQuoted() throws -> String {
        i += 1
        var result = ""
        while i < chars.count {
            let char = chars[i]
            i += 1
            if char != "'" {
                result.append(char)
            } else if i < chars.count, chars[i] == "'" {
                result.append("'")
                i += 1
            } else {
                return result
            }
        }
        throw ImportError.syntax(line: 1, reason: "unclosed string")
    }

    private mutating func plain() -> String {
        let start = i
        while i < chars.count {
            let char = chars[i]
            if char == "," || char == "]" || char == "}" { break }
            if char == ":", i + 1 == chars.count || " ,]}".contains(chars[i + 1]) { break }
            i += 1
        }
        return String(chars[start..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func skipSpace() {
        while i < chars.count, chars[i].isWhitespace { i += 1 }
    }
}
