import Foundation
import Testing
@testable import Aoi

struct CurlParseTests {
    @Test func readsMethodURLHeadersAndJSONBody() throws {
        // Arrange
        let command = """
        curl -X POST 'https://api.test/v1/books?page=2' \\
          -H 'Content-Type: application/json' \\
          -H "X-Trace: abc" \\
          --data-raw '{"author_id":"a1"}'
        """

        // Act
        let victim = try #require(Curl.parse(command))

        // Assert
        #expect(victim.method == .POST)
        #expect(victim.url == "https://api.test/v1/books")
        #expect(victim.params.values == ["page": "2"])
        #expect(victim.headers.values == ["X-Trace": "abc"])
        #expect(victim.bodyMode == .json)
        #expect(JSONBody.status(of: victim.rawBody, schema: nil) == .valid)
    }

    @Test func aBearerHeaderBecomesTheAuth() throws {
        // Arrange
        let command = "curl https://api.test/x -H 'Authorization: Bearer eyJabc'"

        // Act
        let victim = try #require(Curl.parse(command))

        // Assert
        #expect(victim.auth == Auth(mode: .bearer, token: "eyJabc"))
        #expect(victim.headers.isEmpty)
    }

    @Test func dataWithoutAMethodIsAPost() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl https://api.test/x -d '{}'"))

        // Assert
        #expect(victim.method == .POST)
    }

    @Test func formDataBecomesFormFields() throws {
        // Arrange
        let command = "curl https://api.test/x -H 'Content-Type: application/x-www-form-urlencoded' -d 'a=1&b=two+words'"

        // Act
        let victim = try #require(Curl.parse(command))

        // Assert
        #expect(victim.bodyMode == .form)
        #expect(victim.formFields.values == ["a": "1", "b": "two words"])
    }

    @Test func userBecomesBasicAuth() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl -u reader:s3cret https://api.test"))

        // Assert
        #expect(victim.auth == Auth(mode: .basic, username: "reader", password: "s3cret"))
    }

    @Test func ignoresFlagsItDoesNotNeed() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse("curl -sSL --compressed -o /dev/null --max-time 5 https://api.test/x"))

        // Assert
        #expect(victim.url == "https://api.test/x")
    }

    @Test func readsChromeStyleDollarQuotes() throws {
        // Arrange / Act
        let victim = try #require(Curl.parse(#"curl 'https://api.test' --data-raw $'{"note":"it\'s"}'"#))

        // Assert
        #expect(victim.rawBody.contains("it's"))
    }

    @Test(arguments: ["curl", "echo hi", "curl -H 'X: 1'"])
    func rejectsTextThatIsNotARequest(text: String) {
        // Arrange / Act
        let victim = Curl.parse(text)

        // Assert
        #expect(victim == nil)
    }
}

struct CurlCommandTests {
    func draft() -> RequestDraft {
        var draft = RequestDraft()
        draft.method = .POST
        draft.url = "https://api.test/x"
        draft.auth = Auth(mode: .bearer, token: "eyJsecret")
        draft.bodyMode = .json
        draft.rawBody = #"{"it's": 1}"#
        return draft
    }

    @Test func roundTripsThroughTheParser() throws {
        // Arrange
        let command = try Curl.command(for: draft(), hidingSecrets: false)

        // Act
        let victim = try #require(Curl.parse(command))

        // Assert
        #expect(victim.method == .POST)
        #expect(victim.url == "https://api.test/x")
        #expect(victim.auth.token == "eyJsecret")
        #expect(victim.rawBody.contains("it's"))
    }

    @Test func hidingSecretsMasksTheTokenButKeepsTheScheme() throws {
        // Arrange / Act
        let command = try Curl.command(for: draft(), hidingSecrets: true)

        // Assert
        #expect(!command.contains("eyJsecret"))
        #expect(try #require(Curl.parse(command)).auth.mode == .bearer)
    }

    @Test(arguments: [("Authorization", true), ("x-api-key", true), ("X-Auth-Token", true), ("Content-Type", false)])
    func knowsWhichHeadersAreSecret(header: String, secret: Bool) {
        // Arrange / Act
        let result = Curl.isSecret(header)

        // Assert
        #expect(result == secret)
    }
}

@MainActor
struct StoreCurlTests {
    @Test func pastingACurlReplacesTheRequest() {
        // Arrange
        let victim = makeStore()

        // Act
        let handled = victim.applyCurl("curl -X DELETE https://api.test/v1/books/1")

        // Assert
        #expect(handled)
        #expect(victim.draft.method == .DELETE)
    }

    @Test func copyingFillsInVariables() throws {
        // Arrange
        let victim = makeStore()
        victim.globals = [KeyValue(key: "host", value: "https://api.test")]
        victim.draft.url = "{{host}}/v1/books"

        // Act
        let command = try #require(victim.curlCommand(hidingSecrets: false))

        // Assert
        #expect(command.contains("'https://api.test/v1/books'"))
    }
}
