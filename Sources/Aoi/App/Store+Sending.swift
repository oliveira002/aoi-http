import Foundation

// Sending the active request, the production guard, and the history it leaves behind.
extension Store {
    // Production is active and the guard asks for this method.
    var sendNeedsConfirmation: Bool {
        isProduction && settings.asksBeforeSending(draft.method)
    }

    // The URL as it will go out: variables filled in and query params added.
    var resolvedURL: String {
        (try? draft.resolved(variables).urlRequest().url?.absoluteString) ?? draft.url
    }

    // What Send does: on production the guard may ask first.
    func requestSend() {
        guard !isSending, !draft.url.isEmpty else { return }
        if sendNeedsConfirmation {
            confirmingProduction = true
            return
        }
        Task { await send() }
    }

    func send() async {
        guard !isSending else { return }
        confirmingProduction = false
        activeTab.isSending = true
        activeTab.error = nil
        // Keep the unresolved draft so a replay picks up the current variables.
        let sent = activeTab
        let resolved = sent.draft.resolved(variables)
        var entry = HistoryEntry(date: Date(), draft: sent.draft, collectionID: sent.collectionID, requestName: openRequest?.name, requestID: sent.requestID)
        let outcome: (response: ResponseResult?, error: String?)
        do {
            let result = try await RequestSender.send(resolved, timeout: settings.timeout, using: client)
            entry.statusCode = result.statusCode
            responses[entry.id] = result
            outcome = (result, nil)
        } catch {
            entry.error = error.localizedDescription
            outcome = (nil, error.localizedDescription)
        }
        // The tab that sent it, and any other tab showing the same saved request.
        for index in tabs.indices {
            let sameTab = tabs[index].id == sent.id
            let sameRequest = sent.requestID != nil && tabs[index].requestID == sent.requestID
            guard sameTab || sameRequest else { continue }
            tabs[index].response = outcome.response
            tabs[index].error = outcome.error
            if sameTab { tabs[index].isSending = false }
        }
        history.insert(entry, at: 0)
        if history.count > settings.historyLimit { history.removeLast(history.count - settings.historyLimit) }
    }

    func lastEntry(for requestID: UUID) -> HistoryEntry? {
        history.first { $0.requestID == requestID }
    }

    func deleteHistory(_ id: UUID) {
        history.removeAll { $0.id == id }
    }
}
