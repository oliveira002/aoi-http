import Foundation

// Opening, switching and closing tabs. Every request gets its own tab.
extension Store {
    var isDirty: Bool { isDirty(activeTab) }

    func isDirty(_ tab: OpenTab) -> Bool {
        savedRequest(for: tab).map { $0.draft != tab.draft } ?? (tab.draft != tab.original)
    }

    func title(of tab: OpenTab) -> String {
        savedRequest(for: tab)?.name ?? tab.draft.suggestedName
    }

    func newRequest() {
        insert(OpenTab())
    }

    // A request already open in a tab is brought forward instead of opened twice.
    func open(_ request: SavedRequest, in collectionID: UUID) {
        if let existing = tabs.first(where: { $0.requestID == request.id }) {
            selectTab(existing.id)
            return
        }
        show(makeTab(request.draft, collectionID: collectionID, requestID: request.id, entry: lastEntry(for: request.id)))
    }

    func load(_ entry: HistoryEntry) {
        var tab = makeTab(entry.draft, collectionID: entry.collectionID, requestID: nil, entry: entry)
        tab.historyID = entry.id
        show(tab)
    }

    func selectTab(_ id: UUID) {
        activeTabID = id
        detail = .request
    }

    func selectAdjacentTab(_ offset: Int) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        selectTab(tabs[(index + offset + tabs.count) % tabs.count].id)
    }

    func closeTab(_ id: UUID) {
        guard let closing = tabs.first(where: { $0.id == id }) else { return }
        if isDirty(closing) {
            selectTab(id)
            pendingClose = id
        } else {
            removeTab(id)
        }
    }

    func closeOtherTabs(_ id: UUID) {
        closeTabs(tabs.map(\.id).filter { $0 != id })
        selectTab(id)
    }

    func closeTabsToRight(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        closeTabs(tabs[(index + 1)...].map(\.id))
    }

    func closeAllTabs() {
        closeTabs(tabs.map(\.id))
    }

    // The ids come from the dialog, which may already have cleared the pending state.
    func discardTabs(_ ids: [UUID]) {
        ids.forEach(removeTab)
        pendingTabClose = []
    }

    // The answer to the Save / Discard prompt for one edited tab.
    func finishClose(_ id: UUID, saving: Bool) {
        if saving, let tab = tabs.first(where: { $0.id == id }), let at = location(of: tab.requestID, in: tab.collectionID) {
            collections[at.collection].requests[at.request].draft = tab.draft
        }
        pendingClose = nil
        removeTab(id)
    }

    // Clean tabs close straight away; tabs with edits wait for one Discard for all of them.
    private func closeTabs(_ ids: [UUID]) {
        let dirty = Set(tabs.filter { ids.contains($0.id) && isDirty($0) }.map(\.id))
        ids.filter { !dirty.contains($0) }.forEach(removeTab)
        pendingTabClose = tabs.map(\.id).filter(dirty.contains)
    }

    // An untouched blank tab is filled in rather than left behind.
    private func show(_ tab: OpenTab) {
        if let index = tabs.firstIndex(where: { $0.id == activeTabID }), tabs[index].isBlank {
            tabs[index] = tab
            selectTab(tab.id)
        } else {
            insert(tab)
        }
    }

    // New tabs go right after the active one.
    private func insert(_ tab: OpenTab) {
        let index = tabs.firstIndex { $0.id == activeTabID }.map { $0 + 1 } ?? tabs.endIndex
        tabs.insert(tab, at: index)
        selectTab(tab.id)
    }

    private func removeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty { tabs = [OpenTab()] }
        if activeTabID == id { activeTabID = tabs[min(index, tabs.count - 1)].id }
    }

    // `entry` is the history entry whose response (or error) to show.
    private func makeTab(_ draft: RequestDraft, collectionID: UUID?, requestID: UUID?, entry: HistoryEntry?) -> OpenTab {
        var tab = OpenTab(draft: draft, original: draft, collectionID: collectionID, requestID: requestID)
        tab.response = entry.flatMap { responses[$0.id] }
        if tab.response == nil { tab.error = entry?.error }
        return tab
    }
}
