import AppKit
import SwiftUI
import Testing
@testable import Aoi

// Drives the real AppKit body editor the way the keyboard does: typed text goes through insertText,
// and Return, Tab, Esc and the arrows go through doCommand, so the editor's own handling runs.
@MainActor
final class EditorHarness {
    final class Box { var text: String; init(_ text: String) { self.text = text } }

    let box: Box
    let window: NSWindow
    let textView: NSTextView

    init(_ text: String, schema: BodySchema?) throws {
        let box = Box(text)
        self.box = box
        let editor = JSONEditor(text: Binding(get: { box.text }, set: { box.text = $0 }), schema: schema)
        let host = NSHostingView(rootView: editor.frame(width: 600, height: 400))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        textView = try #require(Self.find(NSTextView.self, in: host))
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
    }

    func type(_ text: String) { textView.insertText(text, replacementRange: textView.selectedRange()) }
    func press(_ command: Selector) { textView.doCommand(by: command) }
    func put(cursorAt offset: Int) { textView.setSelectedRange(NSRange(location: offset, length: 0)) }

    var popupIsVisible: Bool { window.childWindows?.contains { $0.isVisible } ?? false }

    private static func find<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for child in view.subviews { if let match = find(type, in: child) { return match } }
        return nil
    }
}

@MainActor
struct EditorInteractionTests {
    let schema: BodySchema

    init() throws { schema = try Fixtures.requiredSchema("/v1/books") }

    @Test func typingAQuoteOpensTheFieldList() throws {
        // Arrange
        let victim = try EditorHarness("{\n  ", schema: schema)

        // Act
        victim.type("\"")

        // Assert
        #expect(victim.popupIsVisible)
    }

    @Test func returnInsertsTheFieldAndOpensItsValues() throws {
        // Arrange
        let victim = try EditorHarness("{\n  ", schema: schema)
        victim.type("\"")

        // Act
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Assert
        #expect(victim.box.text == "{\n  \"shelf\": \"\"")
        #expect(victim.popupIsVisible)
    }

    @Test func pickingAnEnumValueFinishesTheField() throws {
        // Arrange
        let victim = try EditorHarness("{\n  ", schema: schema)
        victim.type("\"")
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Act
        victim.press(#selector(NSResponder.moveDown(_:)))
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Assert
        #expect(victim.box.text == "{\n  \"shelf\": \"SOUTH_WING\"")
        #expect(!victim.popupIsVisible)
    }

    @Test func aListOfObjectsOpensItsFirstItemWithItsFields() throws {
        // Arrange
        let victim = try EditorHarness("{\n  \"shelf\": \"X\",\n  ", schema: schema)
        victim.type("\"")

        // Act
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Assert
        #expect(victim.box.text.hasSuffix("\"copies\": [{}]"))
        #expect(victim.popupIsVisible)
    }

    @Test func escapeOpensAndClosesTheList() throws {
        // Arrange
        let victim = try EditorHarness("{\n  ", schema: schema)

        // Act
        victim.press(#selector(NSResponder.cancelOperation(_:)))
        let opened = victim.popupIsVisible
        victim.press(#selector(NSResponder.cancelOperation(_:)))

        // Assert
        #expect(opened)
        #expect(!victim.popupIsVisible)
    }

    @Test func typingFiltersTheList() throws {
        // Arrange
        let victim = try EditorHarness("{\n  ", schema: schema)
        victim.type("\"")

        // Act
        victim.type("co")
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Assert
        #expect(victim.box.text.hasSuffix("\"copies\": [{}]"))
    }

    @Test func returnWithoutAListIndents() throws {
        // Arrange
        let victim = try EditorHarness("{", schema: nil)

        // Act
        victim.press(#selector(NSResponder.insertNewline(_:)))

        // Assert
        #expect(victim.box.text == "{\n  ")
    }

    @Test func tabInsertsTwoSpaces() throws {
        // Arrange
        let victim = try EditorHarness("{", schema: nil)

        // Act
        victim.press(#selector(NSResponder.insertTab(_:)))

        // Assert
        #expect(victim.box.text == "{  ")
    }

    @Test func aClosingBraceOnABlankLineMovesBack() throws {
        // Arrange
        let victim = try EditorHarness("{\n  \"a\": 1\n  ", schema: nil)

        // Act
        victim.type("}")

        // Assert
        #expect(victim.box.text == "{\n  \"a\": 1\n}")
    }

    @Test func typedQuotesStayStraight() throws {
        // Arrange
        let victim = try EditorHarness("", schema: nil)

        // Act
        victim.type("\"a\"")

        // Assert
        #expect(victim.box.text == "\"a\"")
    }
}

@MainActor
struct ImportFileTests {
    @Test func importingASpecFileAddsItsCollection() throws {
        // Arrange
        let victim = makeStore()
        let file = FileManager.default.temporaryDirectory.appending(path: "aoi-\(UUID().uuidString).yaml")
        try Fixtures.spec.write(to: file, atomically: true, encoding: .utf8)

        // Act
        victim.importSpecs([file])

        // Assert
        #expect(victim.collections.map(\.name) == ["Library"])
        #expect(victim.sidebarTab == .collections)
    }

    @Test func aFileThatIsNotASpecReportsAnError() throws {
        // Arrange
        let victim = makeStore()
        let file = FileManager.default.temporaryDirectory.appending(path: "aoi-\(UUID().uuidString).json")
        try #"{"hello": "world"}"#.write(to: file, atomically: true, encoding: .utf8)

        // Act
        victim.importSpecs([file])

        // Assert
        #expect(victim.collections.isEmpty)
        #expect(victim.importError != nil)
    }
}
