import Foundation

enum Variables {
    static var pattern: Regex<(Substring, Substring)> { #/\{\{\s*([\w.-]+)\s*\}\}/# }

    // Values may reference other variables, such as baseUrl = {{host}}/v1. The pass limit stops cycles.
    static func resolve(_ text: String, _ vars: [String: String]) -> String {
        var current = text
        for _ in 0..<5 {
            let next = current.replacing(pattern) { match in vars[String(match.1)] ?? String(match.0) }
            if next == current { break }
            current = next
        }
        return current
    }

    static func unresolved(in text: String, _ vars: [String: String]) -> [String] {
        resolve(text, vars).matches(of: pattern).map { String($0.1) }.filter { vars[$0] == nil }
    }
}

extension [KeyValue] {
    var active: [KeyValue] { filter { $0.enabled && !$0.key.isEmpty } }

    func resolved(_ vars: [String: String]) -> [KeyValue] {
        map { row in
            var row = row
            row.key = Variables.resolve(row.key, vars)
            row.value = Variables.resolve(row.value, vars)
            return row
        }
    }

    var texts: [String] { active.flatMap { [$0.key, $0.value] } }

    // Sets a row's value, switching it back on, or adds the row when the name is new.
    func setting(_ name: String, to value: String) -> [KeyValue] {
        // The last row wins when a name repeats, so that is the one to change.
        guard let index = lastIndex(where: { $0.key == name }) else { return self + [KeyValue(key: name, value: value)] }
        var rows = self
        rows[index].value = value
        rows[index].enabled = true
        return rows
    }

    // An empty value counts as unset, so imported placeholders stay highlighted until filled in.
    var values: [String: String] {
        // Trimmed here too, so a stray space or newline can never reach a header such as Authorization.
        let rows = active.map { ($0.key, $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return Dictionary(rows.filter { !$0.1.isEmpty }, uniquingKeysWith: { $1 })
    }

    var formEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?")
        let encode = { (text: String) in text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text }
        return map { "\(encode($0.key))=\(encode($0.value))" }.joined(separator: "&")
    }
}

extension RequestDraft {
    func resolved(_ vars: [String: String]) -> RequestDraft {
        var copy = self
        copy.url = Variables.resolve(url, vars)
        copy.params = params.resolved(vars)
        copy.headers = headers.resolved(vars)
        copy.rawBody = Variables.resolve(rawBody, vars)
        copy.formFields = formFields.resolved(vars)
        copy.auth.token = Variables.resolve(auth.token, vars)
        copy.auth.username = Variables.resolve(auth.username, vars)
        copy.auth.password = Variables.resolve(auth.password, vars)
        return copy
    }

    func unresolvedVariables(_ vars: [String: String]) -> [String] {
        var texts = [url] + params.texts + headers.texts
        switch bodyMode {
        case .none: break
        case .json: texts.append(rawBody)
        case .form: texts += formFields.texts
        }
        switch auth.mode {
        case .none: break
        case .bearer: texts.append(auth.token)
        case .basic: texts += [auth.username, auth.password]
        }
        let names = texts.flatMap { Variables.unresolved(in: $0, vars) }
        return Array(Set(names)).sorted()
    }
}
