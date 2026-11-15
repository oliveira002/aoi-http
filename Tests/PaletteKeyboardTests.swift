import AppKit
import SwiftUI
import Testing
@testable import Aoi

// Real key events into a window that hosts the palette, the same path a keypress takes.
@MainActor
struct PaletteKeyboardTests {
    func window(for store: Store) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CommandPalette(bar: CGRect(x: 0, y: 70, width: 800, height: 0)).environment(store))
        // Off-screen, so running the tests does not flash windows on the desktop.
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.makeKeyAndOrderFront(nil)
        settle()
        return window
    }

    func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.25)) }

    func key(_ characters: String, code: UInt16, in window: NSWindow) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
            window.sendEvent(event)
        }
        settle()
    }

    func typeText(_ text: String, in window: NSWindow) {
        for char in text { key(String(char), code: 0, in: window) }
    }

    @Test func typingAndReturnRunsTheBestMatch() {
        // Arrange
        let victim = makeStore()
        victim.environments = [APIEnvironment(name: "Staging"), APIEnvironment(name: "Production")]
        victim.showingPalette = true
        let window = window(for: victim)

        // Act
        typeText("prod", in: window)
        key("\r", code: 36, in: window)

        // Assert
        #expect(victim.activeEnvironmentID == victim.environments[1].id)
        #expect(!victim.showingPalette)
        window.close()
    }

    @Test func downArrowMovesToTheNextResult() {
        // Arrange
        let victim = makeStore()
        victim.environments = [APIEnvironment(name: "Staging one"), APIEnvironment(name: "Staging two")]
        victim.showingPalette = true
        let window = window(for: victim)
        typeText("staging", in: window)

        // Act
        key(String(UnicodeScalar(NSDownArrowFunctionKey)!), code: 125, in: window)
        key("\r", code: 36, in: window)

        // Assert
        #expect(victim.activeEnvironmentID == victim.environments[1].id)
        window.close()
    }

    @Test func escapeCloses() {
        // Arrange
        let victim = makeStore()
        victim.showingPalette = true
        let window = window(for: victim)

        // Act
        key("\u{1b}", code: 53, in: window)

        // Assert
        #expect(!victim.showingPalette)
        window.close()
    }
}
