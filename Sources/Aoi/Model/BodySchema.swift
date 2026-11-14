import Foundation

// What a JSON body accepts, kept from an API spec.
indirect enum BodySchema: Codable, Equatable {
    case object([BodyField])
    case array(BodySchema)
    // type is string, integer, number or boolean; choices are enum values.
    case value(type: String, format: String?, choices: [String])
    case any

    struct BodyField: Codable, Equatable {
        var name: String
        var schema: BodySchema
        var required: Bool
        var description: String?
    }

    var fields: [BodyField] {
        if case .object(let fields) = self { return fields }
        return []
    }

    // The schema of the container reached by following keys and list positions from the top.
    func at(_ path: [JSONStep]) -> BodySchema? {
        guard let step = path.first else { return self }
        switch (self, step) {
        case (.object(let fields), .key(let name)): return fields.first { $0.name == name }?.schema.at(Array(path.dropFirst()))
        case (.array(let items), .index): return items.at(Array(path.dropFirst()))
        default: return nil
        }
    }

    // Required keys missing anywhere in the body, as dotted paths like "author.name".
    func missingFields(in node: Node, prefix: String = "") -> [String] {
        switch (self, node) {
        case (.object(let fields), .map(let entries)):
            let present = Set(entries.map(\.key))
            return fields.flatMap { field -> [String] in
                let path = prefix + field.name
                guard let value = entries.first(where: { $0.key == field.name })?.value else {
                    return field.required && !present.contains(field.name) ? [path] : []
                }
                return field.schema.missingFields(in: value, prefix: path + ".")
            }
        case (.array(let items), .list(let values)):
            return values.enumerated().flatMap { items.missingFields(in: $1, prefix: String(prefix.dropLast()) + "[\($0)].") }
        default:
            return []
        }
    }
}

extension BodySchema {
    // A body filled from the schema, with every field or only the required ones.
    func example(requiredOnly: Bool, depth: Int = 0) -> Node {
        guard depth < 12 else { return .null }
        switch self {
        case .object(let fields):
            let chosen = requiredOnly ? fields.filter(\.required) : fields
            return .map(chosen.map { ($0.name, $0.schema.example(requiredOnly: requiredOnly, depth: depth + 1)) })
        case .array(let items):
            return .list([items.example(requiredOnly: requiredOnly, depth: depth + 1)])
        case .value("boolean", _, _):
            return .scalar("false", plain: true)
        case .value("string", let format, let choices):
            return .scalar(choices.first ?? BodySchema.sampleString(format: format), plain: false)
        case .value(_, _, let choices):
            return .scalar(choices.first ?? "1", plain: true)
        case .any:
            return .null
        }
    }
}

extension BodySchema {
    // A realistic value for a string field, by its format.
    static func sampleString(format: String?) -> String {
        switch format {
        case "date-time": "2024-01-01T00:00:00Z"
        case "date": "2024-01-01"
        case "email": "user@example.com"
        case "uuid": "00000000-0000-0000-0000-000000000000"
        case "uri", "url": "https://example.com"
        default: "string"
        }
    }
}

enum JSONStep: Equatable {
    case key(String), index
}
