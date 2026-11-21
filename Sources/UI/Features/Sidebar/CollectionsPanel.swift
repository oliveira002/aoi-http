import SwiftUI

struct CollectionsPanel: View {
    @Environment(Store.self) private var store
    let search: String
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.m) {
                Button("Import", systemImage: "square.and.arrow.down") { store.showingImporter = true }
                    .help("Import an OpenAPI, Swagger or Postman file (⌘O)")
                Button("New", systemImage: "plus") { store.createCollection() }
                    .help("New empty collection")
                Spacer()
            }
            .buttonStyle(LinkButtonStyle())

            if store.collections.isEmpty {
                ImportDropZone()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(store.collections) { collection in
                            CollectionTree(collection: collection, search: search).padding(.bottom, Theme.Space.s)
                        }
                    }
                    .padding(.bottom, Theme.Space.m)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.importSpecs(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: Theme.Radius.container)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .background(Theme.accentSoft, in: .rect(cornerRadius: Theme.Radius.container))
                    .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
                    .overlay { Label("Drop to import", systemImage: "square.and.arrow.down").foregroundStyle(Theme.accent) }
            }
        }
    }
}

struct ImportDropZone: View {
    @Environment(Store.self) private var store

    var body: some View {
        EmptyState(
            icon: "doc.badge.plus",
            title: "Import an API spec",
            message: "OpenAPI 3, Swagger 2 or a Postman collection or environment, as YAML or JSON. You can also drop the file here."
        ) {
            Button("Choose File…") { store.showingImporter = true }
                .buttonStyle(ControlButtonStyle(primary: true))
            Button("or start an empty collection") { store.createCollection() }
                .buttonStyle(LinkButtonStyle())
        }
        .raisedPanel(dashed: true)
    }
}

struct CollectionTree: View {
    @Environment(Store.self) private var store
    let collection: APICollection
    let search: String

    var body: some View {
        let key = collection.id.uuidString
        let groups = filteredGroups
        let open = store.expanded.contains(key) || !search.isEmpty
        if search.isEmpty || !groups.isEmpty {
            SidebarRow(
                selected: store.detail == .variables(.collection(collection.id)),
                action: { toggle(key) },
                onSettings: { store.showVariables(.collection(collection.id)) }
            ) {
                Chevron(open: open)
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent).font(.callout)
                Text(collection.name).font(.headline).lineLimit(1)
                Spacer(minLength: Theme.Space.xs)
                CountLabel(count: collection.requests.count)
            }
            .contextMenu {
                Button("Settings and Variables") { store.showVariables(.collection(collection.id)) }
                Button("Save Current Request Here") { store.saveDraft(to: collection.id) }
                Divider()
                Button("Delete Collection", role: .destructive) { store.pendingDeletion = .collection(collection.id) }
            }

            if open {
                if collection.requests.isEmpty {
                    Text("Empty. Use Save to… on a request to add it here.")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                        .padding(.leading, SidebarIndent.leading(1) + Chevron.width + Theme.Space.s)
                        .padding(.vertical, Theme.Space.xs)
                }
                ForEach(groups, id: \.name) { group in
                    if let folder = group.name {
                        let folderKey = "\(key)/\(folder)"
                        let folderOpen = store.expanded.contains(folderKey) || !search.isEmpty
                        SidebarRow(indent: 1, action: { toggle(folderKey) }) {
                            Chevron(open: folderOpen)
                            Image(systemName: folderOpen ? "folder" : "folder.fill").foregroundStyle(Theme.faint).font(.subheadline)
                            Text(folder).font(.callout.weight(.medium)).lineLimit(1)
                            Spacer(minLength: Theme.Space.xs)
                            CountLabel(count: group.requests.count)
                        }
                        if folderOpen {
                            ForEach(group.requests) { requestRow($0, indent: 2) }
                        }
                    } else {
                        ForEach(group.requests) { requestRow($0, indent: 1) }
                    }
                }
            }
        }
    }

    private func requestRow(_ request: SavedRequest, indent: Int) -> some View {
        SidebarRow(
            selected: store.openRequestID == request.id && store.detail == .request,
            indent: indent,
            action: { store.open(request, in: collection.id) }
        ) {
            Color.clear.frame(width: Chevron.width, height: 1)
            MethodTag(method: request.draft.method)
            Text(request.name).font(.callout).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: Theme.Space.xs)
            if let last = store.lastEntry(for: request.id) {
                Circle()
                    .fill(Theme.status(last.statusCode))
                    .frame(width: 6, height: 6)
                    .help("Last sent \(last.date.formatted(.relative(presentation: .named))): \(last.statusCode.map(String.init) ?? "failed")")
            }
        }
        .help(request.draft.url)
        .contextMenu {
            Button("Duplicate") { store.duplicate(request.id, in: collection.id) }
            Button("Delete", role: .destructive) { store.deleteRequest(request.id, in: collection.id) }
        }
    }

    private var filteredGroups: [(name: String?, requests: [SavedRequest])] {
        collection.folders(matching: SearchQuery(search))
    }

    private func toggle(_ key: String) {
        store.expanded.toggle(key)
    }
}
