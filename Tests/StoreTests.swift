import Foundation
import Testing
@testable import Aoi

@MainActor
struct StoreGuardTests {
    func productionStore() -> Store {
        let store = makeStore()
        let production = APIEnvironment(name: "API PRD")
        store.environments = [production]
        store.activeEnvironmentID = production.id
        store.draft.method = .POST
        store.draft.url = "https://example.test/x"
        return store
    }

    @Test func editingTheRequestCancelsAPendingConfirmation() {
        // Arrange
        let victim = productionStore()
        victim.requestSend()

        // Act
        victim.draft.url += "/other"

        // Assert
        #expect(!victim.confirmingProduction)
    }

    @Test func anUnchangedWriteKeepsThePendingConfirmation() {
        // Arrange
        let victim = productionStore()
        victim.requestSend()

        // Act
        victim.draft = victim.draft

        // Assert
        #expect(victim.confirmingProduction)
    }

    @Test func switchingEnvironmentCancelsAPendingConfirmation() {
        // Arrange
        let victim = productionStore()
        victim.requestSend()

        // Act
        victim.activeEnvironmentID = nil

        // Assert
        #expect(!victim.confirmingProduction)
    }

    @Test func theConfirmationShowsTheResolvedURL() {
        // Arrange
        let victim = productionStore()
        victim.globals = [KeyValue(key: "host", value: "https://api.test")]
        victim.draft.url = "{{host}}/v1/books"
        victim.draft.params = [KeyValue(key: "page", value: "2")]

        // Act
        let url = victim.resolvedURL

        // Assert
        #expect(url == "https://api.test/v1/books?page=2")
    }
}

@MainActor
struct StoreWorkspaceTests {
    @Test func deletingACollectionWaitsForConfirmation() {
        // Arrange
        let victim = makeStore()
        let id = victim.createCollection()

        // Act
        victim.pendingDeletion = .collection(id)

        // Assert
        #expect(victim.collections.count == 1)
    }

    @Test func confirmingDeletesTheCollection() {
        // Arrange
        let victim = makeStore()
        let id = victim.createCollection()

        // Act
        victim.delete(.collection(id))

        // Assert
        #expect(victim.collections.isEmpty)
        #expect(victim.pendingDeletion == nil)
    }

    @Test func confirmingDeletesTheActiveEnvironmentAndTurnsItOff() {
        // Arrange
        let victim = makeStore()
        let environment = APIEnvironment(name: "Local")
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.delete(.environment(environment.id))

        // Assert
        #expect(victim.environments.isEmpty)
        #expect(victim.activeEnvironmentID == nil)
    }

    @Test func togglingTheActiveEnvironmentTurnsItOff() {
        // Arrange
        let victim = makeStore()
        let environment = APIEnvironment(name: "Local")
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.toggleActive(environment.id)

        // Assert
        #expect(victim.activeEnvironmentID == nil)
    }

    @Test func environmentVariablesOverrideGlobals() {
        // Arrange
        let victim = makeStore()
        var environment = APIEnvironment(name: "Local")
        environment.variables = [KeyValue(key: "host", value: "http://localhost:8080")]
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.globals = [KeyValue(key: "host", value: "https://api.test"), KeyValue(key: "token", value: "t")]

        // Assert
        #expect(victim.variables == ["host": "http://localhost:8080", "token": "t"])
    }

    @Test func showingGlobalsOpensTheEnvironmentsTab() {
        // Arrange
        let victim = makeStore()

        // Act
        victim.showVariables(.globals)

        // Assert
        #expect(victim.sidebarTab == .environments)
        #expect(victim.detail == .variables(.globals))
    }

    @Test func savedDataSurvivesARestart() {
        // Arrange
        let persistence = Persistence.temporary()
        let first = Store(persistence: persistence, client: StubClient())
        first.createCollection()
        first.globals = [KeyValue(key: "token", value: "abc")]

        // Act
        let victim = Store(persistence: persistence, client: StubClient())

        // Assert
        #expect(victim.collections.count == 1)
        #expect(victim.globals.values == ["token": "abc"])
    }
}

struct SearchTests {
    @Test func blankQueryMatchesEverything() {
        // Arrange
        var victim = APICollection(name: "C")
        victim.requests = [request("A", url: "x"), request("B", url: "y")]

        // Act
        let folders = victim.folders(matching: SearchQuery("  "))

        // Assert
        #expect(folders.flatMap(\.requests).count == 2)
    }

    @Test func matchesNameOrURLAndDropsEmptyFolders() {
        // Arrange
        var a = request("Get author", url: "{{host}}/v1/authors")
        a.folder = "Authors"
        var b = request("List books", url: "{{host}}/v1/books")
        b.folder = "Books"
        var victim = APICollection(name: "C")
        victim.requests = [a, b]

        // Act
        let folders = victim.folders(matching: SearchQuery("AUTHORS"))

        // Assert
        #expect(folders.map(\.name) == ["Authors"])
    }

    @Test func groupsHistoryByDayNewestFirst() {
        // Arrange
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let victim = [
            HistoryEntry(date: today.addingTimeInterval(3600), draft: RequestDraft()),
            HistoryEntry(date: today.addingTimeInterval(60), draft: RequestDraft()),
            HistoryEntry(date: today.addingTimeInterval(-3600), draft: RequestDraft()),
        ]

        // Act
        let days = victim.days(matching: SearchQuery(""), calendar: calendar)

        // Assert
        #expect(days.map(\.entries.count) == [2, 1])
    }

    @Test(arguments: [("{{host}}/v1/books?x=1", "/v1/books"), ("https://x.test/files/my%20doc", "/files/my doc"), ("https://api.test", "/"), ("", "(no URL)"), ("relative/path", "relative/path")])
    func displayPathDropsTheHost(url: String, path: String) {
        // Arrange
        var victim = RequestDraft()
        victim.url = url

        // Act
        let shown = victim.displayPath

        // Assert
        #expect(shown == path)
    }
}
