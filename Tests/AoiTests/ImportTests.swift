import Foundation
import Testing
@testable import Aoi

struct OpenAPIImporterTests {
    @Test func turnsPathParametersIntoVariables() throws {
        // Arrange / Act
        let victim = try Fixtures.collection()

        // Assert
        #expect(victim.requests.contains { $0.draft.url == "{{baseUrl}}/v1/books/{{book_id}}" })
    }

    @Test func keepsTheServerAsBaseURL() throws {
        // Arrange / Act
        let victim = try Fixtures.collection()

        // Assert
        #expect(victim.variables.first { $0.key == "baseUrl" }?.value == "https://library.test/api")
    }

    @Test func usesBearerAuth() throws {
        // Arrange / Act
        let victim = try Fixtures.collection()

        // Assert
        #expect(victim.requests.allSatisfy { $0.draft.auth.mode == .bearer })
    }

    @Test func keepsTheBodySchemaWithRequiredFields() throws {
        // Arrange / Act
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Assert
        #expect(victim.fields.map(\.name) == ["shelf", "copies"])
        #expect(victim.fields.filter(\.required).count == victim.fields.count)
    }

    @Test func allOfKeepsOwnPropertiesAndRequiredOnlyParts() throws {
        // Arrange / Act
        let victim = try Fixtures.requiredSchema("/v1/merged")

        // Assert
        #expect(victim.fields.map(\.name) == ["name", "id", "extra"])
        #expect(victim.fields.filter(\.required).map(\.name) == ["name", "extra"])
    }

    @Test func oneOfEnumsOfferEveryValue() throws {
        // Arrange / Act
        let victim = try Fixtures.schema("/v1/choice")

        // Assert
        #expect(victim == .value(type: "string", format: nil, choices: ["A", "B", "C"]))
    }
}

struct YAMLParserTests {
    @Test func readsAFlowMapAsAListItem() throws {
        // Arrange
        let yaml = "list:\n  - {type: string, enum: [A, B]}\n"

        // Act
        let victim = try YAMLParser.parse(yaml)

        // Assert
        #expect(victim["list"]?.items.first?["enum"]?.items.compactMap(\.string) == ["A", "B"])
    }

    @Test func resolvesAnchorsAndMerges() throws {
        // Arrange
        let yaml = "base: &base\n  a: 1\nchild:\n  <<: *base\n  b: 2\n"

        // Act
        let victim = try YAMLParser.parse(yaml)

        // Assert
        #expect(victim["child"]?.entries.map(\.key) == ["b", "a"] || victim["child"]?.entries.map(\.key) == ["a", "b"])
    }

    @Test func rejectsUnexpectedIndentation() {
        // Arrange
        let yaml = "a:\n    b: 1\n  c: 2\n"

        // Act / Assert
        #expect(throws: ImportError.self) { try YAMLParser.parse(yaml) }
    }
}

struct SpecImporterTests {
    @Test func picksOpenAPI() throws {
        // Arrange / Act
        let victim = try SpecImporter.importText(Fixtures.spec, fallbackName: "x")

        // Assert
        #expect(victim.collections.count == 1)
        #expect(victim.environments.isEmpty)
    }

    @Test func picksAPostmanCollection() throws {
        // Arrange
        let postman = #"{"info": {"name": "P"}, "item": [{"name": "Ping", "request": {"method": "GET", "url": "https://api.test/ping"}}]}"#

        // Act
        let victim = try SpecImporter.importText(postman, fallbackName: "x")

        // Assert
        #expect(victim.collections.first?.requests.map(\.name) == ["Ping"])
    }

    @Test func picksAPostmanEnvironment() throws {
        // Arrange
        let environment = #"{"name": "API PRD", "values": [{"key": "baseUrl", "value": "https://api.test", "enabled": true}]}"#

        // Act
        let victim = try SpecImporter.importText(environment, fallbackName: "x")

        // Assert
        #expect(victim.environments.first?.variables.values == ["baseUrl": "https://api.test"])
    }

    @Test func skipsPostmanGlobals() {
        // Arrange
        let globals = #"{"name": "Globals", "_postman_variable_scope": "globals", "values": []}"#

        // Act / Assert
        #expect(throws: ImportError.self) { try SpecImporter.importText(globals, fallbackName: "x") }
    }

    @Test func picksAPostmanDataExport() throws {
        // Arrange
        let export = #"{"environments": [{"name": "A", "values": []}, {"name": "B", "values": []}]}"#

        // Act
        let victim = try SpecImporter.importText(export, fallbackName: "x")

        // Assert
        #expect(victim.environments.map(\.name) == ["A", "B"])
    }
}
