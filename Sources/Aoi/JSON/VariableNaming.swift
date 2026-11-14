import Foundation

// Names to offer when a response value becomes a variable, like book_id for $.book.id.
enum VariableNaming {
    struct Suggestions: Equatable {
        // Made from the value's key, with names the requests already use first.
        let fromKey: [String]
        // Every other variable the requests use, for chaining into a name the key does not hint at.
        let inUse: [String]
    }

    static func suggestions(forPath path: String, inUse: [String]) -> Suggestions {
        let made = names(forPath: path)
        let preferred = inUse.filter(made.contains) + made
        let fromKey = preferred.uniqued()
        return Suggestions(fromKey: fromKey, inUse: inUse.filter { !fromKey.contains($0) })
    }

    // "id" takes its parent's name (book_id, and book_id from books[0].id); other keys become snake_case.
    static func names(forPath path: String) -> [String] {
        let steps = JSONTree.steps(in: path)
        guard let last = steps.lastIndex(where: { $0 != nil }), let key = steps[last] else { return [] }
        let snake = snakeCase(key)
        guard snake == "id", let parentIndex = steps[..<last].lastIndex(where: { $0 != nil }), let parent = steps[parentIndex] else {
            return [snake]
        }
        let listed = parentIndex + 1 < last && steps[parentIndex + 1] == nil
        let owner = snakeCase(listed && parent.hasSuffix("s") ? String(parent.dropLast()) : parent)
        return ["\(owner)_id", "id"]
    }

    // isbnNumber, userID and URLPath become isbn_number, user_id and url_path; anything that is not a letter
    // or digit becomes one underscore, so the name always works inside {{...}}.
    static func snakeCase(_ key: String) -> String {
        let chars = Array(key)
        var result = ""
        for (index, char) in chars.enumerated() {
            guard char.isLetter || char.isNumber else {
                if !result.isEmpty, result.last != "_" { result.append("_") }
                continue
            }
            let previous = index > 0 ? chars[index - 1] : nil
            let next = index + 1 < chars.count ? chars[index + 1] : nil
            let startsWord = char.isUppercase && previous.map { $0.isLowercase || $0.isNumber || ($0.isUppercase && next?.isLowercase == true) } == true
            if startsWord, !result.isEmpty, result.last != "_" { result.append("_") }
            result += char.lowercased()
        }
        return result.hasSuffix("_") ? String(result.dropLast()) : result
    }
}

extension JSONTree {
    // The keys along a path such as $.data["a b"].items[0].id, with nil for each list position.
    static func steps(in path: String) -> [String?] {
        let pattern = #/\.([A-Za-z_$][A-Za-z0-9_$]*)|\[("(?:[^"\\]|\\.)*")\]|\[(\d+)\]/#
        return path.matches(of: pattern).map { match in
            if let name = match.output.1 { return String(name) }
            if let quoted = match.output.2 {
                return (try? JSONSerialization.jsonObject(with: Data(quoted.utf8), options: .fragmentsAllowed)) as? String
            }
            return nil
        }
    }
}
