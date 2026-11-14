import Foundation
import Testing
@testable import Aoi

struct VariablesTests {
    @Test func resolvesNestedVariables() {
        // Arrange
        let vars = ["baseUrl": "{{host}}/v1", "host": "https://api.test"]

        // Act
        let resolved = Variables.resolve("{{baseUrl}}/books", vars)

        // Assert
        #expect(resolved == "https://api.test/v1/books")
    }

    @Test func stopsOnCycles() {
        // Arrange
        let vars = ["a": "{{b}}", "b": "{{a}}"]

        // Act
        let resolved = Variables.resolve("{{a}}", vars)

        // Assert
        #expect(resolved == "{{a}}" || resolved == "{{b}}")
    }

    @Test func reportsUnresolvedNames() {
        // Arrange
        let vars = ["host": "https://api.test"]

        // Act
        let missing = Variables.unresolved(in: "{{host}}/{{book_id}}", vars)

        // Assert
        #expect(missing == ["book_id"])
    }

    @Test func emptyAndDisabledRowsCountAsUnset() {
        // Arrange
        let victim = [KeyValue(key: "token", value: "  "), KeyValue(enabled: false, key: "off", value: "x"), KeyValue(key: "id", value: " 42\n")]

        // Act
        let values = victim.values

        // Assert
        #expect(values == ["id": "42"])
    }
}

struct TextInputTests {
    @Test func pasteIsTrimmedAndJoined() {
        // Arrange
        let pasted = "  abc\ndef  "

        // Act
        let cleaned = pasted.cleanedInput(previous: "")

        // Assert
        #expect(cleaned == "abcdef")
    }

    @Test func typedSpaceIsKept() {
        // Arrange
        let typed = "a "

        // Act
        let cleaned = typed.cleanedInput(previous: "a")

        // Assert
        #expect(cleaned == "a ")
    }

    @Test func pastedSecretDropsBearerPrefix() {
        // Arrange
        let pasted = "Bearer eyJabc.def.ghi \n"

        // Act
        let secret = pasted.pastedSecret

        // Assert
        #expect(secret == "eyJabc.def.ghi")
    }
}

struct JWTTests {
    @Test func readsExpiry() {
        // Arrange
        let payload = Data(#"{"exp": 2000000000}"#.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let token = "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"

        // Act
        let expiry = JWT.expiry(of: token)

        // Assert
        #expect(expiry == Date(timeIntervalSince1970: 2_000_000_000))
    }

    @Test func ignoresNonTokens() {
        // Arrange
        let text = "not-a-token"

        // Act
        let expiry = JWT.expiry(of: text)

        // Assert
        #expect(expiry == nil)
    }
}

struct TokenStateTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test(arguments: [("", TokenState.missing), ("opaque-api-key", .notJWT)])
    func readsTokensThatCannotExpire(token: String, state: TokenState) {
        // Arrange / Act
        let victim = TokenState(token: token, now: now)

        // Assert
        #expect(victim == state)
    }

    @Test func pastExpiryIsExpired() {
        // Arrange / Act
        let victim = TokenState(expiry: now.addingTimeInterval(-1), now: now)

        // Assert
        #expect(victim == .expired)
    }

    @Test func underFiveMinutesExpiresSoon() {
        // Arrange / Act
        let victim = TokenState(expiry: now.addingTimeInterval(299), now: now)

        // Assert
        #expect(victim.expiresSoon)
    }

    @Test(arguments: [(30.0, "<1m"), (90, "1m"), (7200, "2h"), (172_800, "2d")])
    func shortensTheTimeLeft(seconds: TimeInterval, text: String) {
        // Arrange / Act
        let short = TokenState.short(seconds)

        // Assert
        #expect(short == text)
    }
}
