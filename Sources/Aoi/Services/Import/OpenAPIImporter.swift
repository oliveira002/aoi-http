import Foundation

struct OpenAPIImporter {
    let root: Node

    func collection(fallbackName: String) -> APICollection {
        var placeholders: [String] = []
        var requests: [SavedRequest] = []
        var baseURL = self.baseURL
        if !baseURL.contains("://") {
            // A relative server such as "/library/v1" is resolved against a host the user fills in.
            baseURL = "{{host}}" + baseURL
            placeholders.append("host")
        }
        for (path, rawItem) in resolve(root["paths"]).entries {
            let item = resolve(rawItem)
            for (method, operation) in item.entries {
                guard let method = HTTPMethod(rawValue: method.uppercased()) else { continue }
                let (request, variables) = self.request(method, path, resolve(operation), sharedParameters: item["parameters"]?.items ?? [])
                requests.append(request)
                placeholders += variables
            }
        }
        let extra = placeholders.uniqued().map { KeyValue(key: $0) }
        return APICollection(
            name: root["info"]?["title"]?.string ?? fallbackName,
            variables: [KeyValue(key: "baseUrl", value: baseURL)] + extra,
            requests: requests
        )
    }

    // One operation as a saved request, plus the variables its auth needs.
    private func request(_ method: HTTPMethod, _ path: String, _ operation: Node, sharedParameters: [Node]) -> (SavedRequest, [String]) {
        var draft = RequestDraft(method: method, url: "{{baseUrl}}" + path.replacing(#/\{([^}]+)\}/#) { "{{\($0.1)}}" })
        let parameters = sharedParameters + (operation["parameters"]?.items ?? [])
        addParameters(parameters, to: &draft)
        addBody(operation["requestBody"], to: &draft)
        let variables = addAuth(operation["security"] ?? root["security"], to: &draft)
        let request = SavedRequest(
            name: operation["summary"]?.string ?? operation["operationId"]?.string ?? "\(method.rawValue) \(path)",
            folder: operation["tags"]?.items.first?.string,
            draft: draft,
            bodySchema: jsonBodySchema(operation["requestBody"], parameters: parameters)
        )
        return (request, variables)
    }

    private var baseURL: String {
        var url: String
        if let server = root["servers"]?.items.first {
            url = server["url"]?.string ?? ""
            for (name, variable) in server["variables"]?.entries ?? [] {
                url = url.replacingOccurrences(of: "{\(name)}", with: variable["default"]?.string ?? "")
            }
        } else if let host = root["host"]?.string {
            let scheme = root["schemes"]?.items.first?.string ?? "https"
            url = "\(scheme)://\(host)\(root["basePath"]?.string ?? "")"
        } else {
            url = root["basePath"]?.string ?? ""
        }
        while url.hasSuffix("/") { url.removeLast() }
        return url
    }

    private func addParameters(_ parameters: [Node], to draft: inout RequestDraft) {
        // Operation parameters come last, so they replace path-level ones with the same name.
        var byKey: [(String, Node)] = []
        for parameter in parameters.map({ resolve($0) }) {
            let key = "\(parameter["in"]?.string ?? "")/\(parameter["name"]?.string ?? "")"
            byKey.removeAll { $0.0 == key }
            byKey.append((key, parameter))
        }
        for (_, parameter) in byKey {
            guard let name = parameter["name"]?.string else { continue }
            let row = KeyValue(enabled: parameter["required"]?.isTrue ?? false, key: name, value: example(of: parameter))
            switch parameter["in"]?.string {
            case "query": draft.params.append(row)
            case "header": draft.headers.append(row)
            case "formData":
                draft.bodyMode = .form
                draft.formFields.append(row)
            case "body":
                draft.bodyMode = .json
                draft.rawBody = sample(parameter["schema"]).json
            default: break
            }
        }
    }

    private func addBody(_ requestBody: Node?, to draft: inout RequestDraft) {
        if let media = media(of: requestBody, containing: "json") {
            draft.bodyMode = .json
            let example = media["example"] ?? media["examples"]?.entries.first.map { resolve($0.value)["value"] ?? .null }
            draft.rawBody = (example ?? sample(media["schema"])).json
        } else if let media = media(of: requestBody, containing: "form") {
            draft.bodyMode = .form
            draft.formFields = resolve(media["schema"])["properties"]?.entries.map {
                KeyValue(key: $0.key, value: sample($0.value).string ?? "")
            } ?? []
        }
    }

    // OpenAPI 3 keeps it under requestBody, Swagger 2 in a parameter with "in: body".
    private func jsonBodySchema(_ requestBody: Node?, parameters: [Node]) -> BodySchema? {
        if let media = media(of: requestBody, containing: "json") {
            return bodySchema(media["schema"])
        }
        return parameters.map { resolve($0) }.first { $0["in"]?.string == "body" }.map { bodySchema($0["schema"]) }
    }

    func bodySchema(_ schema: Node?, depth: Int = 0) -> BodySchema {
        guard let raw = schema, depth < 12 else { return .any }
        let schema = resolve(raw)
        if let parts = schema["allOf"]?.items {
            // Properties or required next to allOf, and parts that only list required names, still count.
            var own = schema
            if case .map(let entries) = schema { own = .map(entries.filter { $0.key != "allOf" }) }
            let all = parts + [own]
            let required = Set(all.flatMap { resolve($0)["required"]?.items.compactMap(\.string) ?? [] })
            return merged(all.map { bodySchema($0, depth: depth + 1) }, keepRequired: true, alsoRequired: required)
        }
        // For a choice of shapes, offer the keys of all of them, none of them required.
        if let options = (schema["oneOf"] ?? schema["anyOf"])?.items {
            return merged(options.map { bodySchema($0, depth: depth + 1) }, keepRequired: false)
        }
        let type = Self.type(of: schema)
        switch type {
        case "array":
            return .array(bodySchema(schema["items"], depth: depth + 1))
        case "string", "integer", "number":
            return .value(type: type!, format: schema["format"]?.string, choices: schema["enum"]?.items.compactMap(\.string) ?? [])
        case "boolean":
            return .value(type: "boolean", format: nil, choices: ["true", "false"])
        default:
            guard let properties = schema["properties"]?.entries else { return type == "object" ? .object([]) : .any }
            let required = Set(schema["required"]?.items.compactMap(\.string) ?? [])
            return .object(properties.map { property in
                let field = resolve(property.value)
                return BodySchema.BodyField(
                    name: property.key,
                    schema: bodySchema(property.value, depth: depth + 1),
                    required: required.contains(property.key),
                    description: (field["description"] ?? field["title"])?.string
                )
            })
        }
    }

    private func merged(_ parts: [BodySchema], keepRequired: Bool, alsoRequired: Set<String> = []) -> BodySchema {
        guard parts.contains(where: { !$0.fields.isEmpty }) else {
            // A choice of enums of one type offers every value.
            let values = parts.compactMap { part -> (String, String?, [String])? in
                if case .value(let type, let format, let choices) = part { return (type, format, choices) }
                return nil
            }
            if let first = values.first, values.count == parts.count, values.allSatisfy({ $0.0 == first.0 }) {
                return .value(type: first.0, format: first.1, choices: values.flatMap(\.2).uniqued())
            }
            return parts.first { $0 != .any } ?? .any
        }
        var fields: [BodySchema.BodyField] = []
        for var field in parts.flatMap(\.fields) {
            field.required = keepRequired && (field.required || alsoRequired.contains(field.name))
            if let index = fields.firstIndex(where: { $0.name == field.name }) {
                fields[index].required = fields[index].required || field.required
            } else {
                fields.append(field)
            }
        }
        return .object(fields)
    }

    // The first media type of a requestBody whose name contains `kind`, such as "json" or "form".
    private func media(of requestBody: Node?, containing kind: String) -> Node? {
        resolve(requestBody)["content"]?.entries.first { $0.key.contains(kind) }?.value
    }

    // Sets the draft's auth and returns the variables it introduced, such as token.
    private func addAuth(_ security: Node?, to draft: inout RequestDraft) -> [String] {
        guard let requirement = security?.items.first?.entries.first?.key,
              let scheme = (root["components"]?["securitySchemes"] ?? root["securityDefinitions"])?[requirement].map({ resolve($0) })
        else { return [] }
        switch (scheme["type"]?.string, scheme["scheme"]?.string?.lowercased()) {
        case ("http", "basic"), ("basic", _):
            draft.auth = Auth(mode: .basic, username: "{{username}}", password: "{{password}}")
            return ["username", "password"]
        case ("apiKey", _):
            let row = KeyValue(key: scheme["name"]?.string ?? "X-API-Key", value: "{{apiKey}}")
            if scheme["in"]?.string == "query" { draft.params.append(row) } else { draft.headers.append(row) }
            return ["apiKey"]
        case ("http", "bearer"), ("oauth2", _), ("openIdConnect", _):
            draft.auth = Auth(mode: .bearer, token: "{{token}}")
            return ["token"]
        default:
            return []
        }
    }

    private func example(of parameter: Node) -> String {
        let schema = resolve(parameter["schema"])
        let candidates = [parameter["example"], schema["example"], parameter["default"], schema["default"],
                          parameter["enum"]?.items.first, schema["enum"]?.items.first]
        return candidates.compactMap { $0?.string }.first ?? ""
    }

    private func sample(_ schema: Node?, depth: Int = 0) -> Node {
        guard let raw = schema, depth < 8 else { return .null }
        let schema = resolve(raw)
        if let value = schema["example"] ?? schema["default"] ?? schema["enum"]?.items.first { return value }
        if let parts = schema["allOf"]?.items {
            return .map(parts.flatMap { sample($0, depth: depth + 1).entries })
        }
        if let first = (schema["oneOf"] ?? schema["anyOf"])?.items.first {
            return sample(first, depth: depth + 1)
        }
        let type = Self.type(of: schema)
        switch type {
        case "array":
            return .list([sample(schema["items"], depth: depth + 1)])
        case "string":
            return .scalar(BodySchema.sampleString(format: schema["format"]?.string), plain: false)
        case "integer", "number":
            return .scalar("0", plain: true)
        case "boolean":
            return .scalar("false", plain: true)
        default:
            let properties = schema["properties"]?.entries ?? []
            return .map(properties.map { ($0.key, sample($0.value, depth: depth + 1)) })
        }
    }

    // OpenAPI 3.1 allows a list of types, such as [string, "null"].
    private static func type(of schema: Node) -> String? {
        schema["type"]?.string ?? schema["type"]?.items.compactMap(\.string).first { $0 != "null" }
    }

    private func resolve(_ node: Node?, depth: Int = 0) -> Node {
        guard let node else { return .null }
        guard depth < 10, let ref = node["$ref"]?.string, ref.hasPrefix("#/") else { return node }
        var target = root
        for part in ref.dropFirst(2).split(separator: "/") {
            let key = part.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
            guard let next = target[key] else { return .null }
            target = next
        }
        return resolve(target, depth: depth + 1)
    }
}

extension OpenAPIImporter: ImportFormat {
    static func matches(_ root: Node) -> Bool {
        root["openapi"] != nil || root["swagger"] != nil
    }

    static func read(_ root: Node, fallbackName: String) -> ImportResult {
        ImportResult(collections: [OpenAPIImporter(root: root).collection(fallbackName: fallbackName)])
    }
}
