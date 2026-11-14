import Foundation

// Path fields: {{variables}} in the URL path that get their own field and write their values into the URL.
extension RequestDraft {
    // The template only applies while the URL is still what it produces; a URL edited by hand becomes the new template.
    private var pathTemplateApplies: Bool {
        pathTemplate.map { Self.fill($0, pathValues ?? [:]) == url } ?? false
    }

    var pathVariables: [String] { Self.pathVariables(in: pathTemplateApplies ? pathTemplate! : url) }

    func pathValue(for name: String) -> String {
        pathTemplateApplies ? pathValues?[name] ?? "" : ""
    }

    mutating func setPathValue(_ value: String, for name: String) {
        let template = pathTemplateApplies ? pathTemplate! : url
        var values = pathTemplateApplies ? pathValues ?? [:] : [:]
        values[name] = value.isEmpty ? nil : value
        pathValues = values.isEmpty ? nil : values
        pathTemplate = values.isEmpty ? nil : template
        url = Self.fill(template, values)
    }

    // The path without the {{baseUrl}} or scheme and host in front, for lists.
    var displayPath: String {
        if url.isEmpty { return "(no URL)" }
        let path = String(url[Self.pathRange(in: url)])
        return path.isEmpty ? "/" : path.removingPercentEncoding ?? path
    }

    // The path's segments, with nil for each segment that is a {{variable}}.
    static func pathShape(of url: String) -> [String?] {
        url[pathRange(in: url)].split(separator: "/").map { segment in
            segment.wholeMatch(of: Variables.pattern) == nil ? String(segment) : nil
        }
    }

    // How many literal segments match a saved request's path, where its {{variables}} match anything; nil when it does not fit.
    func pathMatchScore(against saved: RequestDraft) -> Int? {
        let mine = Self.pathShape(of: pathTemplate ?? url)
        let theirs = Self.pathShape(of: saved.pathTemplate ?? saved.url)
        guard mine.count == theirs.count else { return nil }
        var score = 0
        for (segment, pattern) in zip(mine, theirs) {
            guard let pattern else { continue }
            guard segment == pattern else { return nil }
            score += 1
        }
        return score
    }

    // Variables in the path after the host, like book_id in {{baseUrl}}/v1/books/{{book_id}}.
    static func pathVariables(in url: String) -> [String] {
        url[pathRange(in: url)].matches(of: Variables.pattern).map { String($0.1) }.uniqued()
    }

    static func fill(_ template: String, _ values: [String: String]) -> String {
        let range = pathRange(in: template)
        let path = values.reduce(String(template[range])) { path, entry in
            path.replacingOccurrences(of: "{{\(entry.key)}}", with: entry.value)
        }
        return template.replacingCharacters(in: range, with: path)
    }

    // From after the host to before the query.
    private static func pathRange(in url: String) -> Range<String.Index> {
        let end = url.firstIndex(of: "?") ?? url.endIndex
        var start = url.startIndex
        if url.hasPrefix("{{"), let host = url.range(of: "}}") {
            start = host.upperBound
        } else if let scheme = url.range(of: "://") {
            start = url[scheme.upperBound...].firstIndex(of: "/") ?? end
        }
        return start < end ? start..<end : end..<end
    }
}
