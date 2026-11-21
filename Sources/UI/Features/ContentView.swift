import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var sidebarWidth = Sidebar.defaultWidth
    @FocusState private var windowFocused: Bool

    var body: some View {
        @Bindable var store = store
        // The sidebar never goes away: collapsed, it narrows to a strip of icons.
        HStack(spacing: 0) {
            Sidebar(width: sidebarWidth)
                .frame(width: store.sidebarCollapsed ? Sidebar.railWidth : sidebarWidth, alignment: .leading)
                .clipped()
            // Above the main panel, so both halves of its drag area catch the pointer.
            SidebarDivider(width: $sidebarWidth, resizable: !store.sidebarCollapsed)
                .zIndex(1)
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                // Settings is about the app, not a request, so it shows without the tabs.
                if store.detail != .settings {
                    TabStrip()
                }
                switch store.detail {
                case .request:
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        HeaderView()
                        URLBar()
                        UnresolvedBanner()
                        // The request card gives way first, so the response always keeps room to show something.
                        RequestCard().layoutPriority(1)
                        ResponseCard().frame(minHeight: 200)
                    }
                case .variables(let scope):
                    VariablesEditor(scope: scope)
                case .settings:
                    SettingsPage()
                }
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.l)
            .padding(.bottom, Theme.Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.bg)
        }
        .animation(.smooth(duration: 0.25), value: store.sidebarCollapsed)
        .titleBarHeight()
        // Starts focus on the window, not its first text field (the request name), so typing never renames.
        .focusable()
        .focusEffectDisabled()
        .focused($windowFocused)
        .defaultFocus($windowFocused, true)
        // While the palette or the production popup is open, keys and clicks go only to it.
        .disabled(store.showingPalette || store.confirmingProduction)
        .tint(Theme.accent)
        .onAppear(perform: store.applyAppearance)
        .fileImporter(isPresented: $store.showingImporter, allowedContentTypes: UTType.apiSpecs, allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { store.importSpecs(urls) }
        }
        .confirmationDialog(
            store.openRequest.map { "Save changes to \($0.name)?" } ?? "Close without saving?",
            isPresented: Binding(presenting: $store.pendingClose),
            presenting: store.pendingClose
        ) { id in
            if store.openRequest != nil {
                Button("Save") { store.finishClose(id, saving: true) }
            }
            Button("Discard Changes", role: .destructive) { store.finishClose(id, saving: false) }
            Button("Cancel", role: .cancel) { store.pendingClose = nil }
        } message: { _ in
            Text(store.openRequest == nil ? "This request is not in a collection, so closing the tab loses your edits." : "You edited this request since it was last saved.")
        }
        .confirmationDialog(
            store.pendingTabClose.count == 1 ? "Close a tab with unsaved changes?" : "Close \(store.pendingTabClose.count) tabs with unsaved changes?",
            isPresented: Binding(presenting: $store.pendingTabClose),
            presenting: store.pendingTabClose
        ) { ids in
            Button("Discard Changes", role: .destructive) { store.discardTabs(ids) }
            Button("Cancel", role: .cancel) { store.pendingTabClose = [] }
        } message: { _ in
            Text("The other tabs are already closed. These keep their edits if you cancel.")
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(presenting: $store.pendingDeletion),
            presenting: store.pendingDeletion
        ) { deletion in
            Button("Delete", role: .destructive) { store.delete(deletion) }
            Button("Cancel", role: .cancel) { store.pendingDeletion = nil }
        } message: { _ in
            Text(deletionMessage)
        }
        .overlay {
            if store.confirmingProduction { ProductionConfirm() }
        }
        .overlay(alignment: .top) { TitleBar() }
        .overlay {
            if store.showingPalette {
                GeometryReader { proxy in
                    CommandPalette(top: (proxy.safeAreaInsets.top - Theme.controlHeight) / 2).ignoresSafeArea()
                }
            }
        }
        .alert("Import failed", isPresented: Binding(presenting: $store.importError)) {
            Button("OK") { store.importError = nil }
        } message: {
            Text(store.importError ?? "")
        }
    }

    private var deletionTitle: String {
        switch store.pendingDeletion {
        case .collection(let id): "Delete \(store.collection(id)?.name ?? "collection")?"
        case .environment(let id): "Delete \(store.environment(id)?.name ?? "environment")?"
        case nil: ""
        }
    }

    private var deletionMessage: String {
        switch store.pendingDeletion {
        case .collection(let id): "Its \(store.collection(id)?.requests.count ?? 0) saved requests are removed too."
        case .environment: "Its variables are removed too."
        case nil: ""
        }
    }
}
