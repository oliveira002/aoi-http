import Foundation

// What the request page says about the active request.
extension Store {
    var breadcrumb: String {
        guard let collection = openCollection else { return "Scratch request" }
        return [collection.name, openRequest?.folder].compactMap { $0 }.joined(separator: "  /  ")
    }

    // The host the request goes to, once its variables are filled in.
    var headline: String {
        URLComponents(string: Variables.resolve(draft.url, variables))?.host ?? "New request"
    }

    // The body schema for the active request: its own, or that of the saved request with the same method and path,
    // so a history entry or a pasted curl still gets autocomplete.
    var activeBodySchema: BodySchema? {
        if let schema = openRequest?.bodySchema { return schema }
        let candidates = collections.flatMap(\.requests).filter { $0.bodySchema != nil && $0.draft.method == draft.method }
        let scored = candidates.compactMap { saved in draft.pathMatchScore(against: saved.draft).map { (saved, $0) } }
        return scored.max { $0.1 < $1.1 }?.0.bodySchema
    }

    var statusLine: String {
        if isSending { return "Sending…" }
        if let response { return "Last response \(response.statusCode) in \(Format.duration(response.duration))" }
        if error != nil { return "The last request failed" }
        let sources = [openCollection?.name, activeEnvironment?.name].compactMap { $0 }
        return sources.isEmpty ? "Build a request and click Send" : "Variables from " + sources.joined(separator: " and ")
    }
}
