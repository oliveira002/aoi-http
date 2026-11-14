import Foundation

// Our own tree instead of JSONSerialization, so the order of paths and keys survives the import.
indirect enum Node {
    case map([(key: String, value: Node)])
    case list([Node])
    case scalar(String, plain: Bool)
    case null

    subscript(key: String) -> Node? {
        guard case .map(let entries) = self else { return nil }
        return entries.first { $0.key == key }?.value
    }

    var entries: [(key: String, value: Node)] {
        if case .map(let entries) = self { return entries }
        return []
    }

    var items: [Node] {
        if case .list(let items) = self { return items }
        return []
    }

    var string: String? {
        if case .scalar(let text, _) = self { return text }
        return nil
    }

    var isTrue: Bool { string == "true" }

    // A true/false value, or nil when the key is missing or holds something else.
    func flag(_ key: String) -> Bool? {
        switch self[key]?.string {
        case "true": true
        case "false": false
        default: nil
        }
    }

    var json: String { json(indent: 0) }

    private func json(indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        let inner = String(repeating: " ", count: indent + 2)
        switch self {
        case .map(let entries):
            if entries.isEmpty { return "{}" }
            let body = entries.map { "\(inner)\(Node.quoted($0.key)): \($0.value.json(indent: indent + 2))" }
            return "{\n" + body.joined(separator: ",\n") + "\n\(pad)}"
        case .list(let items):
            if items.isEmpty { return "[]" }
            return "[\n" + items.map { inner + $0.json(indent: indent + 2) }.joined(separator: ",\n") + "\n\(pad)]"
        case .scalar(let text, let plain):
            let literal = text == "true" || text == "false" || text == "null" || text.wholeMatch(of: Node.number) != nil
            return plain && literal ? text : Node.quoted(text)
        case .null:
            return "null"
        }
    }

    private static var number: Regex<Substring> { #/-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/# }

    private static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}

extension Node {
    var isScalar: Bool {
        switch self {
        case .map, .list: false
        default: true
        }
    }

    var count: Int? {
        switch self {
        case .map(let entries): entries.count
        case .list(let items): items.count
        default: nil
        }
    }
}

extension Node {
    // JSON text as a tree. Our own parser keeps the key order, which JSONSerialization loses.
    static func parseJSON(_ text: String) -> Node? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil
        else { return nil }
        var parser = FlowParser(trimmed)
        return try? parser.document()
    }
}
