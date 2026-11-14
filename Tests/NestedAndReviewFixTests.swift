import Foundation
import Testing
@testable import Aoi

struct NestedCompletionTests {
    @Test func aListOfObjectsOpensItsFirstItem() throws {
        // Arrange
        let schema = try Fixtures.requiredSchema("/v1/books")
        let copies = try #require(schema.suggestions(for: try requiredContext(#"{"shelf": "X", "|"#)).first)

        // Act
        let prefix = #"{"shelf": "X", "#
        let (text, offset) = (prefix + copies.insertion + "}", (prefix as NSString).length + copies.cursorOffset)
        let next = schema.suggestions(for: try #require(JSONContext.at(offset, in: text)))

        // Assert
        #expect(copies.insertion == #""copies": [{}]"#)
        #expect(next.map(\.label) == ["barcode", "lent"])
    }

    @Test func aListOfEnumStringsOpensAQuotedValue() {
        // Arrange
        let victim = BodySchema.array(.value(type: "string", format: nil, choices: ["A", "B"]))

        // Act
        let template = victim.template

        // Assert
        #expect(template.0 == #"[""]"#)
        #expect(template.1 == 2)
    }
}

@MainActor
struct ActiveBodySchemaTests {
    func store() -> Store {
        let store = makeStore()
        var collection = APICollection(name: "Catalogue")
        var confirm = request("Return", url: "{{baseUrl}}/v1/books/{{book_id}}/return", method: .POST)
        confirm.bodySchema = .object([.init(name: "barcodes", schema: .array(.value(type: "string", format: nil, choices: [])), required: true)])
        var create = request("Create", url: "{{baseUrl}}/v1/books", method: .POST)
        create.bodySchema = .object([.init(name: "title", schema: .value(type: "string", format: nil, choices: []), required: true)])
        collection.requests = [confirm, create]
        store.collections = [collection]
        return store
    }

    @Test func aPastedURLFindsTheSavedRequestsSchema() {
        // Arrange
        let victim = store()

        // Act
        _ = victim.applyCurl("curl -X POST https://api.test/v1/books/123/return -d '{}'")

        // Assert
        #expect(victim.activeBodySchema?.fields.map(\.name) == ["barcodes"])
    }

    @Test func theMethodMustMatchToo() {
        // Arrange
        let victim = store()

        // Act
        victim.draft.url = "https://api.test/v1/books"

        // Assert
        #expect(victim.activeBodySchema == nil)
    }
}

struct CurlReviewFixTests {
    @Test(arguments: ["curl ''", "curl --url ''", "curl '?'", "curl --url"])
    func emptyURLsDoNotCrash(command: String) {
        // Arrange / Act
        let victim = Curl.parse(command)

        // Assert
        #expect(victim == nil)
    }

    @Test func plainDataIsAForm() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl https://api.test -d 'a=1&b=2'"))

        // Assert
        #expect(victim.bodyMode == .form)
        #expect(victim.formFields.values == ["a": "1", "b": "2"])
    }

    @Test func chromeUnicodeEscapes() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse(#"curl https://api.test --data-raw $'{"note":"hi!"}'"#))

        // Assert
        #expect(victim.rawBody.contains("hi!"))
    }

    @Test func joinedShortOptions() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl -sXPOST -H'X-Trace: 1' -ureader:pw https://api.test"))

        // Assert
        #expect(victim.method == .POST)
        #expect(victim.headers.values == ["X-Trace": "1"])
        #expect(victim.auth.username == "reader")
    }

    @Test func optionValuesAreNotTakenForTheURL() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl -c jar.txt -D headers.txt https://api.test/x"))

        // Assert
        #expect(victim.url == "https://api.test/x")
    }

    @Test func fragmentsAreDropped() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl 'https://api.test/x?q=1#top'"))

        // Assert
        #expect(victim.params.values == ["q": "1"])
    }

    @Test func hidingSecretsCoversQueryKeys() throws {
        // Arrange
        var draft = RequestDraft()
        draft.url = "https://api.test/x"
        draft.params = [KeyValue(key: "api_key", value: "abc123"), KeyValue(key: "page", value: "2")]

        // Act
        let command = try Curl.command(for: draft, hidingSecrets: true)

        // Assert
        #expect(!command.contains("abc123"))
        #expect(command.contains("page=2"))
    }
}

struct PasteTests {
    @Test(arguments: [("https://old", "https://oldcurl x", "curl x"), ("abc", "aXYZc", "XYZ"), ("same", "same", "")])
    func findsWhatWasInserted(previous: String, current: String, inserted: String) {
        // Arrange / Act
        let result = current.insertion(from: previous)

        // Assert
        #expect(result == inserted)
    }
}

@MainActor
struct VariableTargetTests {
    @Test func aRepeatedNameUpdatesTheRowThatWins() {
        // Arrange
        let victim = [KeyValue(key: "a", value: "1"), KeyValue(key: "a", value: "2")]

        // Act
        let rows = victim.setting("a", to: "3")

        // Assert
        #expect(rows.values == ["a": "3"])
    }

    @Test(arguments: [("userID", "user_id"), ("ID", "id"), ("URLPath", "url_path"), ("@type", "type"), ("isbnNumber", "isbn_number"), ("v2Id", "v2_id")])
    func snakeCaseHandlesAcronymsAndSymbols(key: String, name: String) {
        // Arrange / Act
        let result = VariableNaming.snakeCase(key)

        // Assert
        #expect(result == name)
    }
}

@MainActor
struct PaletteKeyTests {
    @Test func openingThePaletteClosesTheProductionPopup() {
        // Arrange
        let victim = makeStore()
        victim.confirmingProduction = true

        // Act
        victim.togglePalette()

        // Assert
        #expect(victim.showingPalette)
        #expect(!victim.confirmingProduction)
    }
}
