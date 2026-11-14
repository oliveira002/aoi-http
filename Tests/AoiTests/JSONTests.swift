import Foundation
import Testing
@testable import Aoi

struct JSONBodyTests {
    @Test(arguments: ["", #"{"a": 1}"#, #"{"count": {{n}}, "id": "{{id}}"}"#, #"{"a": "x,}"}"#])
    func acceptsValidBodies(body: String) {
        // Arrange / Act
        let problem = JSONBody.problem(in: body)

        // Assert
        #expect(problem == nil)
    }

    @Test(arguments: ["{oops", "{\n  \"a\": [1,\n  ]\n}", "{\r\n  \"a\": 1,\r\n}"])
    func flagsInvalidBodies(body: String) {
        // Arrange / Act
        let problem = JSONBody.problem(in: body)

        // Assert
        #expect(problem != nil)
    }

    @Test func formatKeepsVariables() throws {
        // Arrange
        let body = #"{"count":{{n}},"id":"{{id}}","again":{{n}}}"#

        // Act
        let formatted = try #require(JSONBody.format(body))

        // Assert
        #expect(JSONBody.problem(in: formatted) == nil)
        #expect(formatted.contains(#""count": {{n}}"#) && formatted.contains(#""id": "{{id}}""#) && formatted.contains(#""again": {{n}}"#))
    }

    @Test func formatLeavesExistingBigNumbersAlone() throws {
        // Arrange
        let body = #"{"big": 19182736400001, "v": {{a}}}"#

        // Act
        let formatted = try #require(JSONBody.format(body))

        // Assert
        #expect(formatted.contains("19182736400001"))
    }
}

struct JSONContextTests {
    @Test func newKeyAfterASibling() throws {
        // Arrange / Act
        let victim = try requiredContext(#"{"shelf": "X", "|"#)

        // Assert
        #expect(victim.kind == .key)
        #expect(victim.siblings == ["shelf"])
        #expect(victim.path.isEmpty)
    }

    @Test func followsNestedObjectsAndLists() throws {
        // Arrange / Act
        let victim = try requiredContext(#"{"items": [{"a": {"b|"#)

        // Assert
        #expect(victim.path == [.key("items"), .index, .key("a")])
        #expect(victim.partial == "b")
    }

    @Test func aValueBeingTyped() throws {
        // Arrange / Act
        let victim = try requiredContext(#"{"shelf": "NO|"#)

        // Assert
        #expect(victim.kind == .value(key: "shelf"))
        #expect(victim.partial == "NO")
    }

    @Test func editingAKeyThatHasItsColon() throws {
        // Arrange / Act
        let victim = try requiredContext(#"{"wa|": 1}"#)

        // Assert
        #expect(victim.hasColon)
        #expect(victim.replace == NSRange(location: 1, length: 4))
    }

    @Test func anUnclosedQuoteEndsAtItsLine() throws {
        // Arrange / Act
        let victim = try requiredContext("{\n  \"na|\n  \"other\": 1\n}")

        // Assert
        #expect(victim.replace == NSRange(location: 4, length: 3))
        #expect(victim.siblings == ["other"])
    }

    @Test func keysAfterTheCursorCountAsSiblings() throws {
        // Arrange / Act
        let victim = try requiredContext(#"{"|", "x": 1}"#)

        // Assert
        #expect(victim.siblings == ["x"])
    }

    @Test(arguments: [#"|{"a": 1}"#, #"{"color": "red"|}"#, #"{"list": [{"a": 1}|]}"#])
    func offersNothingWhereNothingGoes(marked: String) {
        // Arrange / Act
        let victim = context(marked)

        // Assert
        #expect(victim == nil)
    }
}

struct BodySchemaTests {
    @Test func suggestsMissingKeysRequiredFirst() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let suggestions = victim.suggestions(for: try requiredContext(#"{"shelf": "X", "|"#))

        // Assert
        #expect(suggestions.map(\.label) == ["copies"])
    }

    @Test func completesAKeyWithATypedTemplate() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let first = try #require(victim.suggestions(for: try requiredContext(#"{"|"#)).first)

        // Assert
        #expect(first.insertion == #""shelf": """#)
        #expect(first.cursorOffset == (first.insertion as NSString).length - 1)
    }

    @Test func suggestsKeysInsideNestedLists() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let suggestions = victim.suggestions(for: try requiredContext(#"{"copies": [{"|"#))

        // Assert
        #expect(suggestions.map(\.label) == ["barcode", "lent"])
    }

    @Test func filtersEnumValuesByWhatIsTyped() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let suggestions = victim.suggestions(for: try requiredContext(#"{"shelf": "SO|"#))

        // Assert
        #expect(suggestions.map(\.insertion) == [#""SOUTH_WING""#])
    }

    @Test func reportsMissingRequiredFields() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")
        let body = try #require(Node.parseJSON(#"{"copies": [{}]}"#))

        // Act
        let missing = victim.missingFields(in: body)

        // Assert
        #expect(missing == ["shelf", "copies[0].barcode"])
    }

    @Test func requiredOnlyExampleIsComplete() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let example = victim.example(requiredOnly: true)

        // Assert
        #expect(victim.missingFields(in: example).isEmpty)
        #expect(example["copies"]?.items.first?["lent"] == nil)
    }

    @Test func fullExampleUsesTheFirstEnumValue() throws {
        // Arrange
        let victim = try Fixtures.requiredSchema("/v1/books")

        // Act
        let example = victim.example(requiredOnly: false)

        // Assert
        #expect(example["shelf"]?.string == "NORTH_WING")
    }
}

struct JSONTreeTests {
    let tree = Node.parseJSON(#"{"a":1,"a":{"id":"x"},"list":[{"id":"needle"},{"name":"Needle"}]}"#)!

    @Test func repeatedKeysGetTheirOwnPaths() {
        // Arrange / Act
        let children = JSONTree.children(of: tree, path: "$")

        // Assert
        #expect(children.map(\.path) == ["$.a", "$.a#1", "$.list"])
    }

    @Test func searchMatchesValuesIgnoringCase() {
        // Arrange / Act
        let matches = JSONTree.search(tree, for: "needle")

        // Assert
        #expect(matches.map(\.path) == ["$.list[0].id", "$.list[1].name"])
    }

    @Test func searchMatchesKeysButNotListIndexes() {
        // Arrange / Act
        let byKey = JSONTree.search(tree, for: "name")
        let byIndex = JSONTree.search(tree, for: "0")

        // Assert
        #expect(byKey.map(\.path) == ["$.list[1].name"])
        #expect(byIndex.isEmpty)
    }

    @Test func matchesKnowHowToRevealThemselves() {
        // Arrange / Act
        let match = JSONTree.search(tree, for: "needle")[1]

        // Assert
        #expect(match.ancestors.map(\.path) == ["$", "$.list", "$.list[1]"])
        #expect(match.ancestors.map(\.index) == [2, 1, 0])
    }
}

struct JSONBodyStatusTests {
    @Test func blankIsEmpty() {
        // Arrange / Act
        let status = JSONBody.status(of: "  \n", schema: nil)

        // Assert
        #expect(status == .empty)
    }

    @Test func brokenJSONIsInvalid() {
        // Arrange / Act
        let status = JSONBody.status(of: "{oops", schema: nil)

        // Assert
        let invalid = if case .invalid = status { true } else { false }
        #expect(invalid)
    }

    @Test func listsRequiredFieldsStillMissing() throws {
        // Arrange
        let schema = try Fixtures.requiredSchema("/v1/books")

        // Act
        let status = JSONBody.status(of: #"{"copies": []}"#, schema: schema)

        // Assert
        #expect(status == .missing(["shelf"]))
    }

    @Test func completeBodyIsValid() throws {
        // Arrange
        let schema = try Fixtures.requiredSchema("/v1/books")

        // Act
        let status = JSONBody.status(of: #"{"shelf": "{{shelf}}", "copies": []}"#, schema: schema)

        // Assert
        #expect(status == .valid)
    }
}

struct JSONTreeRowsTests {
    let list = Node.parseJSON("[" + (0..<120).map { #"{"v":\#($0)}"# }.joined(separator: ",") + "]")!

    @Test func collapsedRootIsOneRow() {
        // Arrange / Act
        let rows = JSONTree.visibleRows(of: list, expanded: [], shown: [:])

        // Assert
        #expect(rows.map(\.id) == ["$"])
    }

    @Test func anOpenListShowsOnePageAndAMoreRow() {
        // Arrange / Act
        let rows = JSONTree.visibleRows(of: list, expanded: ["$"], shown: [:])

        // Assert
        #expect(rows.count == 1 + JSONTree.page + 1)
        #expect(rows.last?.id == "$#more")
    }

    @Test func showingMoreListsEverything() {
        // Arrange / Act
        let rows = JSONTree.visibleRows(of: list, expanded: ["$"], shown: ["$": 150])

        // Assert
        #expect(rows.count == 121)
    }
}
