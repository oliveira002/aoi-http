import AppKit
import SwiftUI

// The main window publishes its store while it is in front, so the menus act on the window being looked at.
struct WorkspaceKey: FocusedValueKey {
    typealias Value = Store
}

extension FocusedValues {
    var workspace: Store? {
        get { self[WorkspaceKey.self] }
        set { self[WorkspaceKey.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    @FocusedValue(\.workspace) private var store

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button(store?.sidebarCollapsed == true ? "Show Sidebar" : "Hide Sidebar") { store.map { $0.sidebarCollapsed.toggle() } }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .disabled(store == nil)
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { store?.detail = .settings }
                .keyboardShortcut(",")
                .disabled(store == nil)
        }
        CommandGroup(replacing: .newItem) {
            Group {
                Button("New Tab") { store?.newRequest() }
                    .keyboardShortcut("t")
                Button("New Collection") { store?.newCollection() }
                    .keyboardShortcut("n")
                Button("Import API Spec…") { store?.showingImporter = true }
                    .keyboardShortcut("o")
                Button("Go to…") { store?.togglePalette() }
                    .keyboardShortcut("k")
            }
            .disabled(store == nil)
        }
        CommandGroup(after: .newItem) {
            // ⌘W closes a tab in the main window, and any other window, such as an open panel, as usual.
            Button(store == nil ? "Close" : "Close Tab") {
                guard let store else { return closeWindow() }
                store.closeTab(store.activeTabID)
            }
            .keyboardShortcut("w")
            Group {
                Button("Close Other Tabs") { store.map { $0.closeOtherTabs($0.activeTabID) } }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                    .disabled((store?.tabs.count ?? 0) < 2)
                Button("Close All Tabs") { store?.closeAllTabs() }
            }
            .disabled(store == nil)
            Button("Close Window", action: closeWindow)
                .keyboardShortcut("w", modifiers: [.command, .shift])
            Group {
                Button("Next Tab") { store?.selectAdjacentTab(1) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Tab") { store?.selectAdjacentTab(-1) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
            }
            .disabled(store == nil)
        }
        CommandGroup(after: .pasteboard) {
            Group {
                Button("Copy as cURL") { store?.curlCommand(hidingSecrets: false).map(Pasteboard.copy) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Copy as cURL, Secrets Hidden") { store?.curlCommand(hidingSecrets: true).map(Pasteboard.copy) }
                    .keyboardShortcut("c", modifiers: [.command, .option, .shift])
            }
            .disabled(store == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Request") { store?.saveOpenRequest() }
                .keyboardShortcut("s")
                .disabled(store?.openRequest == nil)
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.performClose(nil)
    }
}
