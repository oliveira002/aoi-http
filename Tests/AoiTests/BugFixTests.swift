import Foundation
import SwiftUI
import Testing
@testable import Aoi

struct YAMLEscapeTests {
    @Test func anEscapedQuoteDoesNotEndTheString() throws {
        // Arrange
        let yaml = #"k: "a \" # b""# + "\n"

        // Act
        let victim = try YAMLParser.parse(yaml)

        // Assert
        #expect(victim["k"]?.string == #"a " # b"#)
    }

    @Test func aDoubledSingleQuoteDoesNotEndTheString() throws {
        // Arrange
        let yaml = "k: 'it''s # here'\n"

        // Act
        let victim = try YAMLParser.parse(yaml)

        // Assert
        #expect(victim["k"]?.string == "it's # here")
    }

    @Test func aRealCommentIsStillDropped() throws {
        // Arrange
        let yaml = "k: value # note\n"

        // Act
        let victim = try YAMLParser.parse(yaml)

        // Assert
        #expect(victim["k"]?.string == "value")
    }
}

struct PostmanAuthTests {
    func importOne(_ request: String, collectionAuth: String = "null") throws -> RequestDraft {
        let json = #"{"info": {"name": "P"}, "auth": \#(collectionAuth), "item": [{"name": "R", "request": \#(request)}]}"#
        return try #require(try SpecImporter.importText(json, fallbackName: "x").collections.first?.requests.first?.draft)
    }

    @Test func anAPIKeyBecomesAHeader() throws {
        // Arrange
        let request = #"{"method": "POST", "url": "https://library.test", "auth": {"type": "apikey", "apikey": [{"key": "key", "value": "x-api-key"}, {"key": "value", "value": "{{apiKey}}"}]}}"#

        // Act
        let victim = try importOne(request)

        // Assert
        #expect(victim.headers.values == ["x-api-key": "{{apiKey}}"])
        #expect(victim.auth.mode == .none)
    }

    @Test func anAPIKeyCanGoInTheQuery() throws {
        // Arrange
        let request = #"{"url": "https://library.test", "auth": {"type": "apikey", "apikey": [{"key": "key", "value": "k"}, {"key": "value", "value": "v"}, {"key": "in", "value": "query"}]}}"#

        // Act
        let victim = try importOne(request)

        // Assert
        #expect(victim.params.values == ["k": "v"])
    }

    @Test func version2ObjectAuthKeepsTheToken() throws {
        // Arrange
        let request = #"{"url": "https://api.test", "auth": {"type": "bearer", "bearer": {"token": "abc"}}}"#

        // Act
        let victim = try importOne(request)

        // Assert
        #expect(victim.auth == Auth(mode: .bearer, token: "abc"))
    }

    @Test func anUnsupportedTypeDoesNotInheritTheParent() throws {
        // Arrange
        let request = #"{"url": "https://api.test", "auth": {"type": "oauth2"}}"#
        let parent = #"{"type": "bearer", "bearer": [{"key": "token", "value": "parent"}]}"#

        // Act
        let victim = try importOne(request, collectionAuth: parent)

        // Assert
        #expect(victim.auth.mode == .none)
    }

    @Test func noAuthInheritsTheParent() throws {
        // Arrange
        let request = #"{"url": "https://api.test"}"#
        let parent = #"{"type": "bearer", "bearer": [{"key": "token", "value": "parent"}]}"#

        // Act
        let victim = try importOne(request, collectionAuth: parent)

        // Assert
        #expect(victim.auth == Auth(mode: .bearer, token: "parent"))
    }

    @Test func aRawXMLBodyKeepsItsContentType() throws {
        // Arrange
        let request = #"{"method": "POST", "url": "https://api.test", "body": {"mode": "raw", "raw": "<a/>", "options": {"raw": {"language": "xml"}}}}"#

        // Act
        let victim = try importOne(request)

        // Assert
        #expect(victim.headers.values == ["Content-Type": "application/xml"])
    }

    @Test func disabledRowsAndEnvironmentValuesImportSwitchedOff() throws {
        // Arrange
        let environment = #"{"name": "E", "values": [{"key": "a", "value": "1", "enabled": false}, {"key": "b", "value": "2"}]}"#

        // Act
        let victim = try #require(try SpecImporter.importText(environment, fallbackName: "x").environments.first)

        // Assert
        #expect(victim.variables.map(\.enabled) == [false, true])
    }
}

struct PresentingBindingTests {
    final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    @Test func dismissingClearsTheState() {
        // Arrange
        let box = Box<UUID?>(UUID())
        let victim = Binding(presenting: Binding(get: { box.value }, set: { box.value = $0 }))

        // Act
        victim.wrappedValue = false

        // Assert
        #expect(box.value == nil)
    }

    @Test func dismissingClearsAList() {
        // Arrange
        let box = Box([UUID()])
        let victim = Binding(presenting: Binding(get: { box.value }, set: { box.value = $0 }))

        // Act
        victim.wrappedValue = false

        // Assert
        #expect(box.value.isEmpty)
    }
}
