import AppKit
import SwiftUI

// The main window publishes its store while it is in front. With Settings in front it is nil,
// so the menus never reach a window the user is not looking at.
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
        SidebarCommands()
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
            // ⌘W closes a tab in the main window and closes any other window, such as Settings, like on any Mac.
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
