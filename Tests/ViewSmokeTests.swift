import AppKit
import SwiftUI
import Testing
@testable import Aoi

// Draws the whole window in each state, so a view that crashes or loops fails here instead of in the app.
@MainActor
struct ViewSmokeTests {
    func render(_ store: Store) {
        let host = NSHostingView(rootView: ContentView().environment(store))
        host.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
        host.layoutSubtreeIfNeeded()
        _ = host.fittingSize
    }

    func populatedStore() -> Store {
        let store = makeStore()
        var collection = APICollection(name: "Library")
        var saved = request("Get book", url: "{{host}}/v1/books/{{book_id}}")
        saved.folder = "Books"
        collection.requests = [saved]
        store.collections = [collection]
        var environment = APIEnvironment(name: "API PRD")
        environment.variables = [KeyValue(key: "host", value: "https://api.test")]
        store.environments = [environment]
        store.activeEnvironmentID = environment.id
        store.globals = [KeyValue(key: "token", value: "abc")]
        store.open(saved, in: collection.id)
        return store
    }

    @Test(arguments: SidebarTab.allCases)
    func everySidebarTabDraws(tab: SidebarTab) {
        // Arrange
        let victim = populatedStore()

        // Act
        victim.sidebarTab = tab
        render(victim)

        // Assert
        #expect(victim.sidebarTab == tab)
    }

    @Test(arguments: [Detail.request, .variables(.globals), .settings])
    func everyPageDraws(detail: Detail) {
        // Arrange
        let victim = populatedStore()

        // Act
        victim.detail = detail
        render(victim)

        // Assert
        #expect(victim.detail == detail)
    }

    @Test func anEmptyWorkspaceDraws() {
        // Arrange
        let victim = makeStore()

        // Act
        for tab in SidebarTab.allCases {
            victim.sidebarTab = tab
            render(victim)
        }

        // Assert
        #expect(victim.collections.isEmpty)
    }

    @Test func theProductionPopupDraws() {
        // Arrange
        let victim = populatedStore()
        victim.draft.method = .POST
        victim.draft.url = "https://api.test/x"

        // Act
        victim.requestSend()
        render(victim)

        // Assert
        #expect(victim.confirmingProduction)
    }

    @Test func thePaletteDraws() {
        // Arrange
        let victim = populatedStore()

        // Act
        victim.showingPalette = true
        render(victim)

        // Assert
        #expect(victim.showingPalette)
    }

    @Test func aRawBodyDraws() {
        // Arrange
        let host = NSHostingView(rootView: RawBodyView(text: "{\n  \"id\": 1\n}", isJSON: true).frame(width: 400, height: 300))

        // Act
        host.layoutSubtreeIfNeeded()

        // Assert
        #expect(host.fittingSize.height == 300)
    }

    @Test func aRowLeavesVariableNamesUntilItsMenuOpens() {
        // Arrange
        var asked = 0
        let variables = JSONRowView.VariableActions(suggestions: { asked += 1; return VariableNaming.suggestions(forPath: "$.id", inUse: []) }, set: { _ in })
        let actions = JSONRowView.Actions(toggle: {}, expandAll: {}, collapseAll: {}, copy: {}, copyPath: {}, variables: variables)
        let row = JSONTree.Row(id: "$.id", depth: 0, label: "id", isIndex: false, kind: .node(.scalar("bk_1", plain: false)))
        let host = NSHostingView(rootView: JSONRowView(row: row, node: .scalar("bk_1", plain: false), isOpen: false, mark: .none, actions: actions))

        // Act
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 30)
        host.layoutSubtreeIfNeeded()

        // Assert
        #expect(asked == 0)
    }
}
