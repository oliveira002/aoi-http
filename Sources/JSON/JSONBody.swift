import Foundation

// Checks and formats a JSON body that may hold {{variables}} outside strings, like {"count": {{n}}}.
// Each variable is swapped for a unique number, which is valid JSON inside or outside a string.
enum JSONBody {
    enum Status: Equatable {
        case empty
        case invalid(String)
        case missing([String])
        case valid
    }

    // What the editor shows: empty, the parser's complaint, required fields still missing, or valid.
    static func status(of body: String, schema: BodySchema?) -> Status {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        let text = protect(body).0
        if let problem = problem(inProtected: text) { return .invalid(problem) }
        guard let schema, let node = Node.parseJSON(text) else { return .valid }
        let missing = schema.missingFields(in: node)
        return missing.isEmpty ? .valid : .missing(missing)
    }

    // The parser's complaint, or nil when the body is valid or empty.
    static func problem(in body: String) -> String? {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return problem(inProtected: protect(body).0)
    }

    private static func problem(inProtected text: String) -> String? {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: .fragmentsAllowed)
            return trailingComma(in: text)
        } catch {
            let detail = (error as NSError).userInfo["NSDebugDescription"] as? String
            return detail.map { $0.replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression) } ?? "Not valid JSON"
        }
    }

    static func format(_ body: String) -> String? {
        let (text, names, base) = protect(body)
        guard problem(in: body) == nil, let formatted = Node.parseJSON(text)?.json else { return nil }
        return names.enumerated().reduce(formatted) { result, item in
            result.replacingOccurrences(of: String(base + item.offset), with: "{{\(item.element)}}")
        }
    }

    // Foundation accepts a comma before } or ], but strict servers do not.
    private static func trailingComma(in text: String) -> String? {
        // Blank out strings first, keeping their length, so a ",}" inside one does not count.
        let blanked = text.replacing(#/"(?:[^"\\]|\\.)*"/#) { String(repeating: "x", count: $0.output.count) }
        guard let match = blanked.firstMatch(of: #/,\s*[}\]]/#) else { return nil }
        let line = blanked[..<match.range.lowerBound].utf16.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
        return "Trailing comma on line \(line)"
    }

    // The stand-in numbers start from a base whose digits do not already appear in the body.
    private static func protect(_ body: String) -> (String, [String], Int) {
        let base = [918_273_640_000, 736_192_450_000, 584_726_310_000].first { !body.contains(String($0 / 1000)) } ?? 918_273_640_000
        var names: [String] = []
        let text = body.replacing(Variables.pattern) { match in
            let name = String(match.output.1)
            let index = names.firstIndex(of: name) ?? { names.append(name); return names.count - 1 }()
            return String(base + index)
        }
        return (text, names, base)
    }
}
