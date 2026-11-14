import Foundation
import Testing
@testable import Aoi

struct JSONSearchTests {
    let tree = Node.parseJSON(#"{"list":[{"id":"needle"},{"name":"Needle"},{"x":"needle"}]}"#)!

    @Test func blankQueryHasNoMatches() {
        // Arrange / Act
        let victim = JSONSearch("  ", in: tree)

        // Assert
        #expect(victim.matches.isEmpty)
        #expect(victim.currentMatch == nil)
    }

    @Test func stepWrapsAround() {
        // Arrange
        var victim = JSONSearch("needle", in: tree)

        // Act
        victim.step(-1)

        // Assert
        #expect(victim.current == 2)
    }

    @Test func marksTheCurrentMatchApartFromTheOthers() {
        // Arrange / Act
        let victim = JSONSearch("needle", in: tree)

        // Assert
        #expect(victim.mark("$.list[0].id") == .current)
        #expect(victim.mark("$.list[1].name") == .match)
        #expect(victim.mark("$.list") == .none)
    }

    @Test func revealOpensOnlyTheWayToTheCurrentMatch() {
        // Arrange
        var victim = JSONSearch("needle", in: tree)
        victim.step(1)
        var expanded: Set<String> = []
        var shown: [String: Int] = [:]

        // Act
        victim.reveal(expanded: &expanded, shown: &shown)

        // Assert
        #expect(expanded == ["$", "$.list", "$.list[1]"])
    }

    @Test func revealPagesFarEnoughToListTheMatch() {
        // Arrange
        let long = Node.parseJSON("[" + (0..<120).map { #"{"v":"\#($0 == 110 ? "needle" : "x")"}"# }.joined(separator: ",") + "]")!
        let victim = JSONSearch("needle", in: long)
        var expanded: Set<String> = []
        var shown: [String: Int] = [:]

        // Act
        victim.reveal(expanded: &expanded, shown: &shown)

        // Assert
        #expect(shown["$"] == 150)
    }
}

struct JSONIndentTests {
    func edit(_ marked: String) -> JSONIndent.Edit {
        let (text, offset) = cursor(marked)
        return JSONIndent.newline(in: text, replacing: NSRange(location: offset, length: 0))
    }

    @Test func keepsTheLineIndentation() {
        // Arrange / Act
        let victim = edit("{\n  \"a\": 1,|")

        // Assert
        #expect(victim.text == "\n  ")
    }

    @Test func indentsAfterAnOpeningBracket() {
        // Arrange / Act
        let victim = edit("{\n  \"a\": [|")

        // Assert
        #expect(victim.text == "\n    ")
    }

    @Test func putsTheClosingBracketOnItsOwnLine() {
        // Arrange / Act
        let victim = edit("{|}")

        // Assert
        #expect(victim.text == "\n  \n")
        #expect(victim.cursor == 4)
    }

    @Test func aClosingBracketOnABlankLineMovesBack() throws {
        // Arrange
        let (text, offset) = cursor("{\n  \"a\": 1\n  |")

        // Act
        let victim = try #require(JSONIndent.closingBracket("}", in: text, at: offset))

        // Assert
        #expect(victim.range == NSRange(location: offset - 2, length: 2))
        #expect(victim.text == "}")
    }

    @Test func aClosingBracketAfterTextGoesInAsTyped() {
        // Arrange
        let (text, offset) = cursor("{\"a\": 1|")

        // Act
        let victim = JSONIndent.closingBracket("}", in: text, at: offset)

        // Assert
        #expect(victim == nil)
    }
}

struct LabelTests {
    @Test(arguments: [(RequestSection.params, "Params 1"), (.headers, "Headers"), (.body, "Body · Raw JSON"), (.auth, "Auth")])
    func sectionTitlesCountRowsOrNameTheMode(section: RequestSection, title: String) {
        // Arrange
        var victim = RequestDraft()
        victim.params = [KeyValue(key: "page", value: "1"), KeyValue(enabled: false, key: "off")]
        victim.bodyMode = .json

        // Act
        let result = victim.title(for: section)

        // Assert
        #expect(result == title)
    }

    @Test func historyNamesTodayAndYesterday() {
        // Arrange
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        // Act
        let today = HistoryEntry.dayTitle(now.addingTimeInterval(-60), now: now, calendar: calendar)
        let yesterday = HistoryEntry.dayTitle(now.addingTimeInterval(-86_400), now: now, calendar: calendar)

        // Assert
        #expect([today, yesterday] == ["Today", "Yesterday"])
    }

    @Test func aScratchEntryShowsItsHost() {
        // Arrange
        var draft = RequestDraft()
        draft.url = "https://api.test/v1/x"
        let victim = HistoryEntry(date: .now, draft: draft)

        // Act
        let subtitle = victim.subtitle(collection: nil)

        // Assert
        #expect(subtitle == "api.test")
    }

    @Test func aSavedEntryShowsCollectionAndPath() {
        // Arrange
        var draft = RequestDraft()
        draft.url = "{{host}}/v1/books"
        let victim = HistoryEntry(date: .now, draft: draft, requestName: "List")

        // Act
        let subtitle = victim.subtitle(collection: "Library")

        // Assert
        #expect(subtitle == "Library  ·  /v1/books")
    }
}

@MainActor
struct StoreSummaryTests {
    @Test func headlineIsTheResolvedHost() {
        // Arrange
        let victim = makeStore()
        victim.globals = [KeyValue(key: "host", value: "https://api.test")]

        // Act
        victim.draft.url = "{{host}}/v1/books"

        // Assert
        #expect(victim.headline == "api.test")
    }

    @Test func breadcrumbNamesTheCollectionAndFolder() {
        // Arrange
        let victim = makeStore()
        var saved = request("Get", url: "{{host}}/x")
        saved.folder = "Books"
        var collection = APICollection(name: "Library")
        collection.requests = [saved]
        victim.collections = [collection]

        // Act
        victim.open(saved, in: collection.id)

        // Assert
        #expect(victim.breadcrumb == "Library  /  Books")
    }
}
