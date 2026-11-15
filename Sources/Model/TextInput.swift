import Foundation

extension String {
    // A token never holds whitespace, so all of it goes, along with a leading "Bearer ".
    var pastedSecret: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmed.hasPrefix("Bearer ") ? trimmed.dropFirst(7) : Substring(trimmed)
        return token.filter { !$0.isWhitespace }
    }

    // Newlines never belong in a single-line value. Anything other than typing or deleting one character
    // (a paste, even over a selection) is also trimmed; spaces typed one at a time are kept so "a b" works.
    func cleanedInput(previous: String) -> String {
        let joined = filter { !$0.isNewline }
        return isSingleEdit(from: previous) ? joined : joined.trimmingCharacters(in: .whitespaces)
    }

    // What was typed or pasted to get from `previous` to this, found by trimming what both share at each end.
    func insertion(from previous: String) -> String {
        let new = Array(self), old = Array(previous)
        let prefix = zip(new, old).prefix { $0 == $1 }.count
        let suffix = zip(new.dropFirst(prefix).reversed(), old.dropFirst(prefix).reversed()).prefix { $0 == $1 }.count
        return String(new[prefix..<(new.count - suffix)])
    }

    // One character typed or deleted, as opposed to a paste.
    func isSingleEdit(from previous: String) -> Bool {
        let (longer, shorter) = count >= previous.count ? (self, previous) : (previous, self)
        guard longer.count - shorter.count == 1 else { return false }
        let prefix = zip(longer, shorter).prefix { $0 == $1 }.count
        return longer.dropFirst(prefix + 1).elementsEqual(shorter.dropFirst(prefix))
    }
}
