import AppKit

// The app's state. Each feature's behaviour lives in a Store+Feature.swift extension;
// this file holds the state itself, how it is saved, and lookups every feature shares.
@MainActor
@Observable
final class Store {
    // MARK: Saved

    var collections: [APICollection] = [] { didSet { persistence.save(collections, to: .collections) } }
    var environments: [APIEnvironment] = [] {
        didSet {
            saveEnvironments()
            confirmingProduction = false
        }
    }
    var activeEnvironmentID: UUID? {
        didSet {
            saveEnvironments()
            confirmingProduction = false
        }
    }
    var globals: [KeyValue] = [] {
        didSet {
            persistence.save(globals, to: .globals)
            confirmingProduction = false
        }
    }
    var settings = AppSettings() {
        didSet {
            persistence.save(settings, to: .settings)
            applyAppearance()
        }
    }

    // MARK: Session only

    var tabs: [OpenTab]
    var activeTabID: UUID { didSet { confirmingProduction = false } }
    // Kept only while the app is open. Dropping an entry drops its response too.
    var history: [HistoryEntry] = [] {
        didSet {
            let ids = Set(history.map(\.id))
            if responses.keys.contains(where: { !ids.contains($0) }) { responses = responses.filter { ids.contains($0.key) } }
        }
    }
    // The response of each history entry. A saved request shows the one from its newest entry.
    var responses: [UUID: ResponseResult] = [:]
    // Values taken from responses, such as a book_id to chain into the next request. Gone on quit.
    var sessionVariables: [KeyValue] = [] { didSet { confirmingProduction = false } }

    // MARK: Interface

    var detail = Detail.request { didSet { confirmingProduction = false } }
    var sidebarTab = SidebarTab.collections
    var expanded: Set<String> = []
    var showingImporter = false
    var showingPalette = false
    var sidebarCollapsed = false
    var importError: String?
    // Set by Send on a production environment; shows the confirmation popup.
    var confirmingProduction = false
    // An edited tab waiting on Save / Discard before it closes.
    var pendingClose: UUID?
    // Tabs with unsaved edits from a bulk close, waiting for Discard.
    var pendingTabClose: [UUID] = []
    // A collection or environment waiting on the user to confirm its deletion.
    var pendingDeletion: Deletion?

    let persistence: Persistence
    let client: any HTTPClient

    // The app passes the real folder and network; tests pass a temporary folder and a stub.
    init(persistence: Persistence, client: any HTTPClient) {
        self.persistence = persistence
        self.client = client
        let first = OpenTab()
        tabs = [first]
        activeTabID = first.id
        let saved = persistence.load(.environments)
        environments = saved?.environments ?? []
        activeEnvironmentID = saved?.activeEnvironmentID
        collections = persistence.load(.collections) ?? []
        globals = persistence.load(.globals) ?? []
        settings = persistence.load(.settings) ?? AppSettings()
    }

    // MARK: Active tab

    var activeTab: OpenTab {
        get { tabs.first { $0.id == activeTabID } ?? tabs[0] }
        set {
            guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
            tabs[index] = newValue
        }
    }

    // Any edit cancels a pending production confirmation, so what was confirmed is what gets sent.
    var draft: RequestDraft {
        get { activeTab.draft }
        set {
            guard newValue != activeTab.draft else { return }
            activeTab.draft = newValue
            confirmingProduction = false
        }
    }
    var response: ResponseResult? { activeTab.response }
    var error: String? { activeTab.error }
    var isSending: Bool { activeTab.isSending }
    var openCollectionID: UUID? { get { activeTab.collectionID } set { activeTab.collectionID = newValue } }
    var openRequestID: UUID? { get { activeTab.requestID } set { activeTab.requestID = newValue } }
    var loadedHistoryID: UUID? { activeTab.historyID }

    // MARK: Lookups

    func collection(_ id: UUID?) -> APICollection? { collections.first { $0.id == id } }
    func environment(_ id: UUID?) -> APIEnvironment? { environments.first { $0.id == id } }

    var openCollection: APICollection? { collection(openCollectionID) }
    var openRequest: SavedRequest? { openCollection?.requests.first { $0.id == openRequestID } }
    var activeEnvironment: APIEnvironment? { environment(activeEnvironmentID) }
    var isProduction: Bool { activeEnvironment?.isProduction == true }

    // Where a saved request sits, as collection and request indexes.
    func location(of requestID: UUID?, in collectionID: UUID?) -> (collection: Int, request: Int)? {
        guard let c = collections.firstIndex(where: { $0.id == collectionID }),
              let r = collections[c].requests.firstIndex(where: { $0.id == requestID })
        else { return nil }
        return (c, r)
    }

    func savedRequest(for tab: OpenTab) -> SavedRequest? {
        location(of: tab.requestID, in: tab.collectionID).map { collections[$0.collection].requests[$0.request] }
    }

    func applyAppearance() {
        NSApplication.shared.appearance = settings.appearance.nsAppearance
    }

    private func saveEnvironments() {
        persistence.save(SavedEnvironments(environments: environments, activeEnvironmentID: activeEnvironmentID), to: .environments)
    }
}

extension AppSettings.Appearance {
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
