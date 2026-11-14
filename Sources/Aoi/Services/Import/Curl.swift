import Foundation

// cURL in both directions: a pasted command becomes a request, and a request becomes a command to share.
enum Curl {
    static func looksLikeCommand(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("curl ")
    }

    // MARK: Reading

    static func parse(_ command: String) -> RequestDraft? {
        let words = shellWords(command)
        guard words.first == "curl" else { return nil }
        var draft = RequestDraft()
        var method: HTTPMethod?
        var data: [String] = []
        var isJSON = false
        var dataInQuery = false
        var rest = Array(words.dropFirst())[...]

        while let word = rest.popFirst() {
            func value() -> String { rest.popFirst() ?? "" }
            // Short options can be joined, as in -sSL, -XPOST or -H'Accept: x'.
            if let split = splitShortOptions(word) {
                rest = split[...] + rest
                continue
            }
            switch word {
            case "-X", "--request": method = HTTPMethod(rawValue: value().uppercased())
            case "-H", "--header": addHeader(value(), to: &draft)
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii", "--data-urlencode": data.append(value())
            case "--json":
                data.append(value())
                isJSON = true
            case "-u", "--user":
                let parts = value().split(separator: ":", maxSplits: 1).map(String.init)
                draft.auth = Auth(mode: .basic, username: parts.first ?? "", password: parts.count > 1 ? parts[1] : "")
            case "-b", "--cookie": draft.headers.append(KeyValue(key: "Cookie", value: value()))
            case "-A", "--user-agent": draft.headers.append(KeyValue(key: "User-Agent", value: value()))
            case "-e", "--referer": draft.headers.append(KeyValue(key: "Referer", value: value()))
            case "-G", "--get": dataInQuery = true
            case "--url": setURL(value(), on: &draft)
            case _ where valueOptions.contains(word): _ = value()
            case _ where word.hasPrefix("-"): break
            default: if draft.url.isEmpty { setURL(word, on: &draft) }
            }
        }

        let body = data.joined(separator: "&")
        if dataInQuery {
            draft.params += formRows(body)
        } else if !body.isEmpty {
            applyBody(body, isJSON: isJSON, to: &draft)
        }
        draft.method = method ?? (body.isEmpty || dataInQuery ? .GET : .POST)
        return draft.url.isEmpty ? nil : draft
    }

    // Options that take a value this app has no use for, so the value is skipped rather than read as the URL.
    private static let valueOptions: Set<String> = [
        "-o", "--output", "-m", "--max-time", "--connect-timeout", "-w", "--write-out", "--retry", "-x", "--proxy",
        "--cacert", "--cert", "--key", "-T", "--upload-file", "-F", "--form", "-r", "--range", "-c", "--cookie-jar",
        "-D", "--dump-header", "-K", "--config", "-E", "--resolve", "--limit-rate", "--max-filesize", "-U", "--proxy-user",
        "--interface", "--retry-delay", "--retry-max-time",
    ]

    // Single-letter options that take a value.
    private static let shortValueOptions: Set<Character> = ["X", "H", "d", "u", "b", "A", "e", "o", "m", "w", "x", "T", "F", "r", "c", "D", "K", "E", "U"]

    // "-sXPOST" as ["-s", "-X", "POST"]; nil for anything that is not a joined short option.
    static func splitShortOptions(_ word: String) -> [String]? {
        guard word.hasPrefix("-"), !word.hasPrefix("--"), word.count > 2 else { return nil }
        var parts: [String] = []
        var letters = word.dropFirst()[...]
        while let letter = letters.popFirst() {
            parts.append("-\(letter)")
            if shortValueOptions.contains(letter) {
                if !letters.isEmpty { parts.append(String(letters)) }
                break
            }
        }
        return parts
    }

    private static func setURL(_ url: String, on draft: inout RequestDraft) {
        let withoutFragment = url.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let parts = withoutFragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        draft.url = parts.first ?? ""
        if parts.count == 2 { draft.params = formRows(parts[1]) }
    }

    // A Bearer Authorization header becomes the request's auth, so it shows in the Auth tab.
    private static func addHeader(_ line: String, to draft: inout RequestDraft) {
        guard let colon = line.firstIndex(of: ":") else { return }
        let name = line[..<colon].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        if name.caseInsensitiveCompare("Authorization") == .orderedSame, value.hasPrefix("Bearer ") {
            draft.auth = Auth(mode: .bearer, token: String(value.dropFirst(7)))
            return
        }
        draft.headers.append(KeyValue(key: name, value: value))
    }

    private static func applyBody(_ body: String, isJSON: Bool, to draft: inout RequestDraft) {
        let contentType = draft.headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?.value.lowercased() ?? ""
        // curl sends -d as a form unless told otherwise; JSON is kept as JSON because that is what it almost always is.
        let looksLikeForm = contentType.isEmpty && !isJSON && JSONBody.problem(in: body) != nil && body.contains("=")
        if contentType.contains("x-www-form-urlencoded") || looksLikeForm {
            draft.bodyMode = .form
            draft.formFields = formRows(body)
            draft.headers.removeAll { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }
            return
        }
        draft.bodyMode = .json
        draft.rawBody = JSONBody.format(body) ?? body
        // JSON mode sets these itself.
        if isJSON || contentType.contains("json") {
            draft.headers.removeAll { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame && $0.value.lowercased().contains("json") }
        }
    }

    private static func formRows(_ query: String) -> [KeyValue] {
        query.split(separator: "&").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map { decode(String($0)) }
            return KeyValue(key: parts[0], value: parts.count > 1 ? parts[1] : "")
        }
    }

    private static func decode(_ text: String) -> String {
        text.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? text
    }

    // Splits a shell command line the way bash would: quotes, backslash escapes, $'...' strings and line continuations.
    static func shellWords(_ command: String) -> [String] {
        var words: [String] = []
        var current = ""
        var inWord = false
        var chars = Array(command.replacingOccurrences(of: "\\\r\n", with: " ").replacingOccurrences(of: "\\\n", with: " "))[...]

        // The escapes inside $'...': \n, \t, \r, \uXXXX, \xHH, and the escaped character itself otherwise.
        func escaped(_ char: Character) -> String {
            switch char {
            case "n": return "\n"
            case "t": return "\t"
            case "r": return "\r"
            case "u", "x":
                let width = char == "u" ? 4 : 2
                let digits = String(chars.prefix(width))
                guard digits.count == width, let code = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(code) else { return String(char) }
                chars.removeFirst(width)
                return String(Character(scalar))
            default: return String(char)
            }
        }

        while let char = chars.popFirst() {
            switch char {
            case " ", "\t", "\n", "\r":
                if inWord { words.append(current) }
                current = ""
                inWord = false
            case "'":
                inWord = true
                while let next = chars.popFirst(), next != "'" { current.append(next) }
            case "\"":
                inWord = true
                while let next = chars.popFirst(), next != "\"" {
                    if next == "\\", let following = chars.first, "\"\\$`".contains(following) {
                        current.append(chars.removeFirst())
                    } else {
                        current.append(next)
                    }
                }
            case "$" where chars.first == "'":
                inWord = true
                chars.removeFirst()
                while let next = chars.popFirst(), next != "'" {
                    if next == "\\", let following = chars.popFirst() {
                        current += escaped(following)
                    } else {
                        current.append(next)
                    }
                }
            case "\\":
                inWord = true
                if let next = chars.popFirst() { current.append(next) }
            default:
                inWord = true
                current.append(char)
            }
        }
        if inWord { words.append(current) }
        return words
    }

    // MARK: Writing

    // A command for a request whose variables are already filled in. Secrets are hidden for sharing.
    static func command(for draft: RequestDraft, hidingSecrets: Bool) throws -> String {
        let request = try draft.urlRequest()
        var parts = ["curl"]
        if request.httpMethod != "GET" { parts.append("-X \(request.httpMethod ?? "GET")") }
        parts.append(quote(hidingSecrets ? maskedQuery(request.url) : request.url?.absoluteString ?? draft.url))
        for (name, value) in (request.allHTTPHeaderFields ?? [:]).sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
            parts.append("-H " + quote("\(name): \(hidingSecrets && isSecret(name) ? masked(value) : value)"))
        }
        if let body = request.httpBody.map({ String(decoding: $0, as: UTF8.self) }), !body.isEmpty {
            parts.append("--data-raw " + quote(body))
        }
        return parts.joined(separator: " \\\n  ")
    }

    // Header and query names that usually carry a credential.
    static func isSecret(_ name: String) -> Bool {
        let name = name.lowercased()
        return ["auth", "cookie", "token", "secret", "key", "password", "session", "signature"].contains { name.contains($0) }
    }

    private static func maskedQuery(_ url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url?.absoluteString ?? "" }
        components.queryItems = components.queryItems?.map { isSecret($0.name) ? URLQueryItem(name: $0.name, value: "hidden") : $0 }
        return components.url?.absoluteString ?? url.absoluteString
    }

    // Keeps the scheme, such as "Bearer", so the reader still knows what kind of credential it was.
    private static func masked(_ value: String) -> String {
        let scheme = value.split(separator: " ", maxSplits: 1)
        return scheme.count == 2 ? "\(scheme[0]) <hidden>" : "<hidden>"
    }

    private static func quote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
