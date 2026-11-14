import Foundation

struct BodySuggestion: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let detail: String
    let required: Bool
    let description: String?
    // Inserted in place of the context's replace range; the cursor goes to cursorOffset within it.
    let insertion: String
    let cursorOffset: Int
}

extension BodySchema {
    // Keys still missing at the cursor, required first, or the allowed values of the field being filled in.
    func suggestions(for context: JSONContext) -> [BodySuggestion] {
        let query = context.partial.lowercased()
        func matches(_ text: String) -> Bool { query.isEmpty || text.lowercased().contains(query) }
        switch context.kind {
        case .key:
            let fields = (at(context.path)?.fields ?? []).filter { !context.siblings.contains($0.name) && matches($0.name) }
            return fields.sorted { $0.required && !$1.required }.map { field in
                let name = "\"\(field.name)\""
                let (value, offset) = context.hasColon ? ("", 0) : field.schema.template
                let insertion = context.hasColon ? name : "\(name): \(value)"
                return BodySuggestion(
                    label: field.name,
                    detail: field.schema.typeName,
                    required: field.required,
                    description: field.description,
                    insertion: insertion,
                    cursorOffset: context.hasColon ? (insertion as NSString).length : (name as NSString).length + 2 + offset
                )
            }
        case .value(let key):
            let container = at(context.path)
            let target: BodySchema?
            if let key {
                target = container?.fields.first { $0.name == key }?.schema
            } else if case .array(let items)? = container {
                target = items
            } else {
                target = nil
            }
            guard case .value(let type, _, let choices)? = target else { return [] }
            return choices.filter(matches).map { choice in
                let insertion = type == "string" ? "\"\(choice)\"" : choice
                return BodySuggestion(label: choice, detail: "", required: false, description: nil, insertion: insertion, cursorOffset: (insertion as NSString).length)
            }
        }
    }

    var typeName: String {
        switch self {
        case .object: "object"
        case .array(let items): "\(items.typeName)[]"
        case .value(let type, let format, let choices): choices.isEmpty || type == "boolean" ? (format.map { "\(type) · \($0)" } ?? type) : "enum"
        case .any: "any"
        }
    }

    // What follows the colon when a key is completed, and where the cursor lands inside it.
    // A list of objects or of enum strings starts with its first element open, so its fields or values come up next.
    var template: (String, Int) {
        switch self {
        case .object: ("{}", 1)
        case .array(.object): ("[{}]", 2)
        case .array(.value("string", _, let choices)) where !choices.isEmpty: ("[\"\"]", 2)
        case .array: ("[]", 1)
        case .value("string", _, _): ("\"\"", 1)
        case .value("boolean", _, _): ("false", 5)
        case .value: ("0", 1)
        case .any: ("", 0)
        }
    }
}
