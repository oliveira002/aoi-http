import Foundation
import Testing
@testable import Aoi

struct PathTemplateTests {
    @Test func listsPathVariablesButNotHostOrQuery() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "{{baseUrl}}/v1/books/{{book_id}}/chapters/{{chapter}}?x={{q}}"

        // Act
        let names = victim.pathVariables

        // Assert
        #expect(names == ["book_id", "chapter"])
    }

    @Test func skipsAHostVariableAfterTheScheme() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "https://{{host}}/x/{{id}}"

        // Act
        let names = victim.pathVariables

        // Assert
        #expect(names == ["id"])
    }

    @Test func typingWritesIntoTheURL() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "{{host}}/v1/books/{{book_id}}"

        // Act
        victim.setPathValue("42", for: "book_id")

        // Assert
        #expect(victim.url == "{{host}}/v1/books/42")
        #expect(victim.pathVariables == ["book_id"])
    }

    @Test func clearingPutsThePlaceholderBack() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "{{host}}/v1/books/{{book_id}}"
        victim.setPathValue("42", for: "book_id")

        // Act
        victim.setPathValue("", for: "book_id")

        // Assert
        #expect(victim.url == "{{host}}/v1/books/{{book_id}}")
        #expect(victim.pathTemplate == nil)
    }

    @Test func fieldsSurviveSaving() throws {
        // Arrange
        var draft = RequestDraft()
        draft.url = "{{host}}/v1/books/{{book_id}}"
        draft.setPathValue("42", for: "book_id")

        // Act
        let victim = try JSONDecoder().decode(RequestDraft.self, from: JSONEncoder().encode(draft))

        // Assert
        #expect(victim.pathValue(for: "book_id") == "42")
    }

    @Test func aHandEditedURLBecomesTheTemplate() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "{{host}}/v1/books/{{book_id}}"
        victim.setPathValue("42", for: "book_id")

        // Act
        victim.url = "{{host}}/v1/books/42/chapters/{{chapter}}"

        // Assert
        #expect(victim.pathVariables == ["chapter"])
    }

    @Test func requestsSavedBeforePathFieldsStillDecode() throws {
        // Arrange
        let saved = #"{"method":"GET","url":"u","params":[],"headers":[],"bodyMode":"None","rawBody":"","formFields":[],"auth":{"mode":"None","token":"","username":"","password":""}}"#

        // Act
        let victim = try JSONDecoder().decode(RequestDraft.self, from: Data(saved.utf8))

        // Assert
        #expect(victim.pathValues == nil)
    }
}

struct URLRequestTests {
    @Test func appendsParamsToTheQuery() throws {
        // Arrange
        var victim = RequestDraft()
        victim.url = "https://api.test/x?a=1"
        victim.params = [KeyValue(key: "b", value: "two words")]

        // Act
        let request = try victim.urlRequest()

        // Assert
        #expect(request.url?.absoluteString == "https://api.test/x?a=1&b=two%20words")
    }

    @Test func getCarriesNoBody() throws {
        // Arrange
        var victim = RequestDraft()
        victim.url = "https://api.test/x"
        victim.bodyMode = .json
        victim.rawBody = "{}"

        // Act
        let request = try victim.urlRequest()

        // Assert
        #expect(request.httpBody == nil)
    }

    @Test func explicitHeadersWinOverAuth() throws {
        // Arrange
        var victim = RequestDraft()
        victim.url = "https://api.test/x"
        victim.auth = Auth(mode: .bearer, token: "from-auth")
        victim.headers = [KeyValue(key: "Authorization", value: "Bearer from-header")]

        // Act
        let request = try victim.urlRequest()

        // Assert
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer from-header")
    }

    @Test func rejectsAURLWithoutScheme() {
        // Arrange
        var victim = RequestDraft()
        victim.url = "{{host}}/x"

        // Act / Assert
        #expect(throws: URLError.self) { try victim.urlRequest() }
    }

    @Test(arguments: [("{{host}}/v1/books/{{id}}", "books"), ("", "New request"), ("https://api.test/x/list?q=1", "list")])
    func suggestsANameFromThePath(url: String, name: String) {
        // Arrange
        var victim = RequestDraft()
        victim.url = url

        // Act
        let suggested = victim.suggestedName

        // Assert
        #expect(suggested == name)
    }
}
