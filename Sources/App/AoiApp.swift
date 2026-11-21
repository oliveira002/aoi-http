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
                .focusedSceneValue(\.workspace, store)
                // Tall enough for the request card and the 200pt the response always keeps; any less and the page overflows.
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { WorkspaceCommands() }
    }
}
