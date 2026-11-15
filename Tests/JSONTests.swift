import AppKit
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

    @Test(arguments: [("name", "$.name"), ("_id$2", "$._id$2"), ("first-name", #"$["first-name"]"#), ("1st", #"$["1st"]"#), ("", #"$[""]"#)])
    func pathsUseDotsOnlyForIdentifierKeys(key: String, path: String) {
        // Arrange / Act
        let result = "$" + JSONTree.component(key)

        // Assert
        #expect(result == path)
    }

    @Test func aQuotedQueryFindsExactStrings() {
        // Arrange
        let tree = Node.parseJSON(#"{"a": "active", "b": "inactive"}"#)!

        // Act
        let matches = JSONTree.search(tree, for: #""active""#)

        // Assert
        #expect(matches.map(\.path) == ["$.a"])
    }

    @Test func searchMatchesNull() {
        // Arrange
        let tree = Node.parseJSON(#"{"a": null, "b": 1}"#)!

        // Act
        let matches = JSONTree.search(tree, for: "NULL")

        // Assert
        #expect(matches.map(\.path) == ["$.a"])
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

struct JSONSyntaxTests {
    // Read through NSTextStorage, as the body editor does. Unlike a native string, a long one traps on
    // any index past its end, which is how a stray last quote once crashed the editor.
    func tokens(_ native: String) -> [String] {
        let text = NSTextStorage(string: native).string
        return JSONSyntax.tokens(in: text).map { token in
            let kind = switch token.color {
            case Theme.JSONColors.key: "key"
            case Theme.JSONColors.string: "string"
            case Theme.JSONColors.number: "number"
            case Theme.JSONColors.boolean: "boolean"
            default: "null"
            }
            return "\(kind) \(text[token.range])"
        }
    }

    @Test func colorsEveryKindOfToken() {
        // Arrange / Act
        let result = tokens(#"{"id": "x", "n": -1.5e3, "ok": true, "z": null}"#)

        // Assert
        #expect(result == [#"key "id""#, #"string "x""#, #"key "n""#, "number -1.5e3", #"key "ok""#, "boolean true", #"key "z""#, "null null"])
    }

    @Test func escapedQuotesStayInsideTheString() {
        // Arrange / Act
        let result = tokens(#"{"a": "say \"hi\""}"#)

        // Assert
        #expect(result == [#"key "a""#, #"string "say \"hi\"""#])
    }

    @Test func aKeyMayHaveSpaceBeforeItsColon() {
        // Arrange / Act
        let result = tokens("{\"a\" \n : 1}")

        // Assert
        #expect(result == [#"key "a""#, "number 1"])
    }

    @Test func keywordsNeedWholeWords() {
        // Arrange / Act
        let result = tokens("[truex, nullable, xtrue, false]")

        // Assert
        #expect(result == ["boolean false"])
    }

    @Test func anUnterminatedStringIsLeftPlain() {
        // Arrange / Act
        let result = tokens(#"{"a": "ab 12"#)

        // Assert
        #expect(result == [#"key "a""#, "number 12"])
    }

    @Test func aQuoteJustTypedAtTheEndIsLeftPlain() {
        // Arrange / Act
        let result = tokens("{\n  \"shelf\": \"X\",\n  \"")

        // Assert
        #expect(result == [#"key "shelf""#, #"string "X""#])
    }

    @Test func escapedQuotesAfterAnUnclosedStringStayPlain() {
        // Arrange / Act
        let result = tokens(#"{"a": "x \"b\": 1, \"c\": true"#)

        // Assert
        #expect(result == [#"key "a""#, "number 1", "boolean true"])
    }

    @Test func numbersNeedADigitAfterEachPart() {
        // Arrange / Act
        let result = tokens("[-, 1., 2e, 3.5E+2]")

        // Assert
        #expect(result == ["number 1", "number 2", "number 3.5E+2"])
    }
}
