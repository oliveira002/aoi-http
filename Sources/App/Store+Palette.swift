import Foundation

// The ⌘K palette: every request, environment and common action, found by fuzzy search.
enum PaletteAction: Equatable {
    case openRequest(SavedRequest, collection: UUID)
    case useEnvironment(UUID?)
    case newTab, closeTab, settings, globals, importSpec
    case copyCurl(hidingSecrets: Bool)
}

struct PaletteItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    var method: HTTPMethod?
    let action: PaletteAction

    var searchText: String { "\(title) \(subtitle) \(method?.rawValue ?? "")" }
}

extension Store {
    static let paletteLimit = 50

    // With no query: actions, then environments, then requests. With one: best matches first.
    func paletteResults(for query: String) -> [PaletteItem] {
        let items = paletteActions + paletteEnvironments + paletteRequests
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return Array(items.prefix(Self.paletteLimit)) }
        let scored = items.compactMap { item in Fuzzy.score(query, in: item.searchText).map { (item, $0) } }
        return scored.sorted { $0.1 > $1.1 }.prefix(Self.paletteLimit).map(\.0)
    }

    // Opening it closes the production popup, so Esc and Return only ever reach one of them.
    func togglePalette() {
        confirmingProduction = false
        showingPalette.toggle()
    }

    func perform(_ action: PaletteAction) {
        showingPalette = false
        switch action {
        case .openRequest(let request, let collection): open(request, in: collection)
        case .useEnvironment(let id): activeEnvironmentID = id
        case .newTab: newRequest()
        case .closeTab: closeTab(activeTabID)
        case .settings: detail = .settings
        case .globals: showVariables(.globals)
        case .importSpec: showingImporter = true
        case .copyCurl(let hidingSecrets): curlCommand(hidingSecrets: hidingSecrets).map(Pasteboard.copy)
        }
    }

    private var paletteActions: [PaletteItem] {
        [
            PaletteItem(id: "new-tab", title: "New Tab", subtitle: "⌘T", icon: "plus.square", action: .newTab),
            PaletteItem(id: "close-tab", title: "Close Tab", subtitle: "⌘W", icon: "xmark.square", action: .closeTab),
            PaletteItem(id: "globals", title: "Edit Globals", subtitle: "Token and shared values", icon: "globe", action: .globals),
            PaletteItem(id: "settings", title: "Settings", subtitle: "⌘,", icon: "gearshape", action: .settings),
            PaletteItem(id: "import", title: "Import API Spec…", subtitle: "OpenAPI, Swagger or Postman", icon: "square.and.arrow.down", action: .importSpec),
            PaletteItem(id: "curl", title: "Copy as cURL", subtitle: "⌥⌘C", icon: "terminal", action: .copyCurl(hidingSecrets: false)),
            PaletteItem(id: "curl-hidden", title: "Copy as cURL, Secrets Hidden", subtitle: "For sharing", icon: "terminal", action: .copyCurl(hidingSecrets: true)),
        ]
    }

    private var paletteEnvironments: [PaletteItem] {
        let none = PaletteItem(id: "env-none", title: "No Environment", subtitle: "Environment", icon: "circle.dashed", action: .useEnvironment(nil))
        return environments.map { environment in
            PaletteItem(
                id: "env-\(environment.id)",
                title: "Use \(environment.name)",
                subtitle: environment.isProduction ? "Environment · production" : "Environment",
                icon: environment.isProduction ? "shield.lefthalf.filled" : "circle.fill",
                action: .useEnvironment(environment.id)
            )
        } + [none]
    }

    private var paletteRequests: [PaletteItem] {
        collections.flatMap { collection in
            collection.requests.map { request in
                PaletteItem(
                    id: "req-\(request.id)",
                    title: request.name,
                    subtitle: [collection.name, request.folder, request.draft.displayPath].compactMap { $0 }.joined(separator: " · "),
                    icon: "doc.text",
                    method: request.draft.method,
                    action: .openRequest(request, collection: collection.id)
                )
            }
        }
    }
}
