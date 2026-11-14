import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 270, ideal: 300, max: 400)
        } detail: {
            VStack(alignment: .leading, spacing: 14) {
                TabStrip()
                switch store.detail {
                case .request:
                    VStack(alignment: .leading, spacing: 16) {
                        HeaderView()
                        URLBar()
                        UnresolvedBanner()
                        RequestCard()
                        ResponseCard()
                    }
                case .variables(let scope):
                    VariablesEditor(scope: scope)
                case .settings:
                    SettingsPage()
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.bg)
        }
        .tint(Theme.accent)
        .onAppear(perform: store.applyAppearance)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { GlobalsButton() }
        }
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
        .overlay {
            if store.showingPalette { CommandPalette() }
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
