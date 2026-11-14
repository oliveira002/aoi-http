import Foundation

enum PostmanImporter {
    static func collection(_ root: Node, fallbackName: String) -> APICollection {
        let variables = (root["variable"]?.items ?? []).map {
            KeyValue(key: $0["key"]?.string ?? "", value: $0["value"]?.string ?? "")
        }
        return APICollection(
            name: root["info"]?["name"]?.string ?? fallbackName,
            variables: variables,
            requests: requests(in: root["item"]?.items ?? [], folder: nil, inheritedAuth: auth(root["auth"]))
        )
    }

    static func environment(_ node: Node, fallbackName: String) -> APIEnvironment {
        let variables = (node["values"]?.items ?? []).map {
            KeyValue(enabled: $0.flag("enabled") ?? true, key: $0["key"]?.string ?? "", value: $0["value"]?.string ?? "")
        }
        return APIEnvironment(name: node["name"]?.string ?? fallbackName, variables: variables)
    }

    private static func requests(in items: [Node], folder: String?, inheritedAuth: ImportedAuth?) -> [SavedRequest] {
        items.flatMap { item -> [SavedRequest] in
            let name = item["name"]?.string ?? "Untitled"
            let itemAuth = auth(item["auth"]) ?? inheritedAuth
            if let children = item["item"]?.items {
                let path = [folder, name].compactMap { $0 }.joined(separator: " / ")
                return requests(in: children, folder: path, inheritedAuth: itemAuth)
            }
            guard let request = item["request"] else { return [] }
            return [SavedRequest(name: name, folder: folder, draft: draft(request, inheritedAuth: itemAuth))]
        }
    }

    private static func draft(_ request: Node, inheritedAuth: ImportedAuth?) -> RequestDraft {
        var draft = RequestDraft()
        // A request can be just its URL.
        if let url = request.string {
            draft.url = url
            return draft
        }
        draft.method = HTTPMethod(rawValue: request["method"]?.string?.uppercased() ?? "") ?? .GET
        let rawURL = request["url"]?.string ?? request["url"]?["raw"]?.string ?? ""
        let parts = rawURL.split(separator: "?", maxSplits: 1)
        draft.url = parts.first.map(String.init) ?? ""
        if let query = request["url"]?["query"]?.items {
            draft.params = query.map(row)
        } else if parts.count == 2 {
            draft.params = parts[1].split(separator: "&").map { pair in
                let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                return KeyValue(key: keyValue[0], value: keyValue.count > 1 ? keyValue[1] : "")
            }
        }
        draft.headers = (request["header"]?.items ?? []).map(row)

        let body = request["body"]
        switch body?["mode"]?.string {
        case "raw":
            draft.bodyMode = .json
            draft.rawBody = body?["raw"]?.string ?? ""
            // The editor sends raw bodies as JSON; keep Postman's own type for text, XML and the like.
            let language = body?["options"]?["raw"]?["language"]?.string ?? "json"
            let hasContentType = draft.headers.contains { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }
            if let type = rawContentTypes[language], !hasContentType {
                draft.headers.append(KeyValue(key: "Content-Type", value: type))
            }
        case "urlencoded", "formdata":
            draft.bodyMode = .form
            draft.formFields = (body?[body?["mode"]?.string ?? ""]?.items ?? []).map(row)
        default:
            break
        }
        let imported = auth(request["auth"]) ?? inheritedAuth ?? ImportedAuth(auth: Auth())
        draft.auth = imported.auth
        if let key = imported.apiKey {
            if imported.apiKeyInQuery { draft.params.append(key) } else { draft.headers.append(key) }
        }
        return draft
    }

    private static let rawContentTypes = [
        "text": "text/plain", "xml": "application/xml", "html": "text/html", "javascript": "application/javascript",
    ]

    private static func row(_ node: Node) -> KeyValue {
        KeyValue(enabled: !(node.flag("disabled") ?? false), key: node["key"]?.string ?? "", value: node["value"]?.string ?? "")
    }

    // Postman auth. An API key has no Auth mode here, so it becomes a header or query param.
    private struct ImportedAuth {
        var auth: Auth
        var apiKey: KeyValue?
        var apiKeyInQuery = false
    }

    // nil means "inherit from the parent", which is Postman's default.
    private static func auth(_ node: Node?) -> ImportedAuth? {
        guard let node, let type = node["type"]?.string else { return nil }
        // v2.1 lists {key, value} pairs; v2.0 used a plain object.
        func value(_ key: String) -> String {
            let settings = node[type]
            return settings?.items.first { $0["key"]?.string == key }?["value"]?.string ?? settings?[key]?.string ?? ""
        }
        switch type {
        case "bearer":
            return ImportedAuth(auth: Auth(mode: .bearer, token: value("token")))
        case "basic":
            return ImportedAuth(auth: Auth(mode: .basic, username: value("username"), password: value("password")))
        case "apikey":
            let key = KeyValue(key: value("key").isEmpty ? "X-API-Key" : value("key"), value: value("value"))
            return ImportedAuth(auth: Auth(), apiKey: key, apiKeyInQuery: value("in") == "query")
        default:
            // noauth, and types this app cannot send, mean no Authorization rather than the parent's.
            return ImportedAuth(auth: Auth())
        }
    }
}

extension PostmanImporter {
    enum Collection: ImportFormat {
        static func matches(_ root: Node) -> Bool {
            root["item"] != nil && root["info"] != nil
        }

        static func read(_ root: Node, fallbackName: String) -> ImportResult {
            ImportResult(collections: [PostmanImporter.collection(root, fallbackName: fallbackName)])
        }
    }

    // A single exported environment. Globals share the shape but are not an environment.
    enum Environment: ImportFormat {
        static func matches(_ root: Node) -> Bool {
            root["values"] != nil && root["_postman_variable_scope"]?.string != "globals"
        }

        static func read(_ root: Node, fallbackName: String) -> ImportResult {
            ImportResult(environments: [PostmanImporter.environment(root, fallbackName: fallbackName)])
        }
    }

    // Postman's full data export, with an "environments" list.
    enum DataExport: ImportFormat {
        static func matches(_ root: Node) -> Bool {
            !(root["environments"]?.items.isEmpty ?? true)
        }

        static func read(_ root: Node, fallbackName: String) -> ImportResult {
            ImportResult(environments: root["environments"]?.items.map { PostmanImporter.environment($0, fallbackName: fallbackName) } ?? [])
        }
    }
}
