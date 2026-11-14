import AppKit
import SwiftUI

@main
struct AoiApp: App {
    @State private var store: Store

    init() {
        Self.exportIconIfAsked()
        _store = State(initialValue: Store(persistence: .live, client: URLSessionClient()))
        // Needed so a SwiftPM executable gets a Dock icon and keyboard focus.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = AppIcon.image
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // bundle.sh runs the binary with --export-icon <path>; this exits before any app data is loaded.
    private static func exportIconIfAsked() {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--export-icon"), index + 1 < arguments.count else { return }
        do {
            try AppIcon.export(to: URL(filePath: arguments[index + 1]))
            exit(0)
        } catch {
            print("Could not export the icon: \(error)")
            exit(1)
        }
    }

    var body: some Scene {
        Window("Aoi", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 1000, minHeight: 660)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { store.newRequest() }
                    .keyboardShortcut("t")
                Button("New Request") { store.newRequest() }
                    .keyboardShortcut("n")
                Button("Import API Spec…") { store.showingImporter = true }
                    .keyboardShortcut("o")
                Button("Go to…") { store.togglePalette() }
                    .keyboardShortcut("k")
            }
            CommandGroup(after: .newItem) {
                Button("Close Tab") { store.closeTab(store.activeTabID) }
                    .keyboardShortcut("w")
                Button("Close Other Tabs") { store.closeOtherTabs(store.activeTabID) }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                    .disabled(store.tabs.count < 2)
                Button("Close All Tabs") { store.closeAllTabs() }
                Button("Next Tab") { store.selectAdjacentTab(1) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Tab") { store.selectAdjacentTab(-1) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy as cURL") { store.curlCommand(hidingSecrets: false).map(Pasteboard.copy) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Copy as cURL, Secrets Hidden") { store.curlCommand(hidingSecrets: true).map(Pasteboard.copy) }
                    .keyboardShortcut("c", modifiers: [.command, .option, .shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Request") { store.saveOpenRequest() }
                    .keyboardShortcut("s")
                    .disabled(store.openRequest == nil)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { store.detail = .settings }
                    .keyboardShortcut(",")
            }
        }
    }
}
