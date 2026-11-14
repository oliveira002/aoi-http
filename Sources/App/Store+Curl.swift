import Foundation

extension Store {
    // A pasted curl command replaces the active request. False when the text is not one.
    func applyCurl(_ text: String) -> Bool {
        guard Curl.looksLikeCommand(text), let parsed = Curl.parse(text) else { return false }
        draft = parsed
        return true
    }

    // The active request as a curl command, with its variables filled in.
    func curlCommand(hidingSecrets: Bool) -> String? {
        try? Curl.command(for: draft.resolved(variables), hidingSecrets: hidingSecrets)
    }
}
