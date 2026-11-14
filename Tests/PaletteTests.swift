import Foundation
import Testing
@testable import Aoi

struct FuzzyTests {
    @Test(arguments: [("gbo", "Get book"), ("api dev", "Use API DEV"), ("BOOK", "get book"), ("", "anything")])
    func matchesCharactersInOrder(query: String, text: String) {
        // Arrange / Act
        let score = Fuzzy.score(query, in: text)

        // Assert
        #expect(score != nil)
    }

    @Test(arguments: [("xyz", "Get book"), ("koob", "book")])
    func rejectsMissingOrReorderedCharacters(query: String, text: String) {
        // Arrange / Act
        let score = Fuzzy.score(query, in: text)

        // Assert
        #expect(score == nil)
    }

    @Test func prefersWordStartsAndRuns() throws {
        // Arrange / Act
        let tight = try #require(Fuzzy.score("book", in: "Get book"))
        let loose = try #require(Fuzzy.score("book", in: "b o o k s"))

        // Assert
        #expect(tight > loose)
    }
}

@MainActor
struct StorePaletteTests {
    func populated() -> (Store, SavedRequest) {
        let store = makeStore()
        var collection = APICollection(name: "Library")
        let book = request("Get book", url: "{{host}}/v1/books/{{book_id}}")
        collection.requests = [book, request("List books", url: "{{host}}/v1/books")]
        store.collections = [collection]
        store.environments = [APIEnvironment(name: "API DEV"), APIEnvironment(name: "API PRD")]
        return (store, book)
    }

    @Test func theBestMatchComesFirst() {
        // Arrange
        let (victim, book) = populated()

        // Act
        let results = victim.paletteResults(for: "get bo")

        // Assert
        #expect(results.first?.id == "req-\(book.id)")
    }

    @Test func findsEnvironmentsByName() {
        // Arrange
        let (victim, _) = populated()

        // Act
        let results = victim.paletteResults(for: "api prd")

        // Assert
        #expect(results.first?.title == "Use API PRD")
    }

    @Test func anEmptyQueryListsActionsFirst() {
        // Arrange
        let (victim, _) = populated()

        // Act
        let results = victim.paletteResults(for: " ")

        // Assert
        #expect(results.first?.action == .newTab)
    }

    @Test func openingARequestClosesThePalette() {
        // Arrange
        let (victim, book) = populated()
        victim.showingPalette = true

        // Act
        victim.perform(.openRequest(book, collection: victim.collections[0].id))

        // Assert
        #expect(!victim.showingPalette)
        #expect(victim.openRequestID == book.id)
    }

    @Test func switchingEnvironment() {
        // Arrange
        let (victim, _) = populated()
        let target = victim.environments[1].id

        // Act
        victim.perform(.useEnvironment(target))

        // Assert
        #expect(victim.activeEnvironmentID == target)
    }
}
