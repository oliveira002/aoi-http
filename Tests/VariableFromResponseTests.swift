import Foundation
import Testing
@testable import Aoi

struct VariableNamingTests {
    @Test(arguments: [
        ("$.id", ["id"]),
        ("$.book.id", ["book_id", "id"]),
        ("$.books[0].id", ["book_id", "id"]),
        ("$.data.isbnNumber", ["isbn_number"]),
        (#"$["book-shelf"].id"#, ["book_shelf_id", "id"]),
        ("$.list[0]", ["list"]),
    ])
    func namesFromThePath(path: String, names: [String]) {
        // Arrange / Act
        let result = VariableNaming.names(forPath: path)

        // Assert
        #expect(result == names)
    }

    @Test func namesAlreadyInUseComeFirst() {
        // Arrange / Act
        let victim = VariableNaming.suggestions(forPath: "$.book.id", inUse: ["author_id", "id"])

        // Assert
        #expect(victim.fromKey == ["id", "book_id"])
        #expect(victim.inUse == ["author_id"])
    }

    @Test func stepsReadEveryKindOfComponent() {
        // Arrange / Act
        let steps = JSONTree.steps(in: #"$.a["b c"][2].d#1"#)

        // Assert
        #expect(steps == ["a", "b c", nil, "d"])
    }
}

struct SettingVariableTests {
    @Test func addsANewRow() {
        // Arrange
        let victim = [KeyValue(key: "token", value: "t")]

        // Act
        let rows = victim.setting("book_id", to: "42")

        // Assert
        #expect(rows.values == ["token": "t", "book_id": "42"])
    }

    @Test func updatesAndReenablesAnExistingRow() {
        // Arrange
        let victim = [KeyValue(enabled: false, key: "book_id", value: "1")]

        // Act
        let rows = victim.setting("book_id", to: "42")

        // Assert
        #expect(rows.count == 1)
        #expect(rows.values == ["book_id": "42"])
    }
}

@MainActor
struct StoreVariableFromResponseTests {
    @Test func keepsTheValueForThisSessionOnly() {
        // Arrange
        let victim = makeStore()
        let environment = APIEnvironment(name: "API DEV")
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.setVariable("book_id", to: "42")

        // Assert
        #expect(victim.sessionVariables.values == ["book_id": "42"])
        #expect(victim.environments[0].variables.isEmpty)
        #expect(victim.globals.isEmpty)
    }

    @Test func aSessionValueWinsOverTheEnvironment() {
        // Arrange
        let victim = makeStore()
        var environment = APIEnvironment(name: "API DEV")
        environment.variables = [KeyValue(key: "book_id", value: "from-env")]
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.setVariable("book_id", to: "from-response")

        // Assert
        #expect(victim.variables["book_id"] == "from-response")
    }

    @Test func sessionValuesAreGoneAfterARestart() {
        // Arrange
        let persistence = Persistence.temporary()
        let first = Store(persistence: persistence, client: StubClient())
        first.setVariable("book_id", to: "42")
        first.globals = [KeyValue(key: "token", value: "t")]

        // Act
        let victim = Store(persistence: persistence, client: StubClient())

        // Assert
        #expect(victim.sessionVariables.isEmpty)
        #expect(victim.variables["book_id"] == nil)
    }

    @Test func aSavedValueFillsTheNextRequest() {
        // Arrange
        let victim = makeStore()
        victim.draft.url = "https://api.test/v1/books/{{book_id}}/borrow"

        // Act
        victim.setVariable("book_id", to: "42")

        // Assert
        #expect(victim.resolvedURL == "https://api.test/v1/books/42/borrow")
    }

    @Test func variablesInUseIncludeCollectionPathsAndUnfilledOnes() {
        // Arrange
        let victim = makeStore()
        var collection = APICollection(name: "Library")
        let saved = request("Get", url: "{{host}}/v1/books/{{book_id}}")
        collection.requests = [saved]
        victim.collections = [collection]
        victim.open(saved, in: collection.id)

        // Act
        let names = victim.variablesInUse

        // Assert
        #expect(Set(names) == ["host", "book_id"])
    }
}
