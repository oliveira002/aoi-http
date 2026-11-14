import Foundation
import Testing
@testable import Aoi

@MainActor
struct StoreSendingTests {
    @Test func sendGoesThroughTheInjectedClient() async {
        // Arrange
        let client = StubClient()
        let victim = makeStore(client: client)
        victim.draft.url = "https://example.test/v1/books"

        // Act
        await victim.send()

        // Assert
        #expect(client.requests.map(\.url?.absoluteString) == ["https://example.test/v1/books"])
    }

    @Test func sendShowsTheResponseAndRecordsHistory() async {
        // Arrange
        let victim = makeStore(client: StubClient(status: 201))
        victim.draft.url = "https://example.test/v1/books"

        // Act
        await victim.send()

        // Assert
        #expect(victim.response?.statusCode == 201)
        #expect(victim.history.first?.statusCode == 201)
    }

    @Test func productionAsksInsteadOfSending() {
        // Arrange
        let client = StubClient()
        let victim = makeStore(client: client)
        let production = APIEnvironment(name: "API PRD")
        victim.environments = [production]
        victim.activeEnvironmentID = production.id
        victim.draft.url = "https://example.test/x"

        // Act
        victim.requestSend()

        // Assert
        #expect(victim.confirmingProduction)
        #expect(!victim.isSending)
    }

    @Test func pressingSendAgainDoesNotBypassTheGuard() {
        // Arrange
        let victim = makeStore()
        let production = APIEnvironment(name: "API PRD")
        victim.environments = [production]
        victim.activeEnvironmentID = production.id
        victim.draft.url = "https://example.test/x"
        victim.requestSend()

        // Act
        victim.requestSend()

        // Assert
        #expect(victim.confirmingProduction)
        #expect(!victim.isSending)
    }

    @Test func historyIsCappedBySettings() async {
        // Arrange
        let victim = makeStore()
        victim.settings.historyLimit = 100
        victim.draft.url = "https://example.test/x"

        // Act
        for _ in 0..<101 { await victim.send() }

        // Assert
        #expect(victim.history.count == 100)
    }
}
