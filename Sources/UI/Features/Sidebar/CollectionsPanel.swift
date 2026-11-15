import SwiftUI

struct CollectionsPanel: View {
    @Environment(Store.self) private var store
    let search: String
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
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
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(store.collections) { collection in
                            CollectionTree(collection: collection, search: search).padding(.bottom, 6)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            store.importSpecs(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .background(Theme.accentSoft.opacity(0.85), in: .rect(cornerRadius: 12))
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
                .buttonStyle(PillButtonStyle(primary: true))
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
                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent).font(.system(size: 12))
                Text(collection.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(collection.requests.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Theme.raised, in: Capsule())
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
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .padding(.leading, 36)
                        .padding(.vertical, 4)
                }
                ForEach(groups, id: \.name) { group in
                    if let folder = group.name {
                        let folderKey = "\(key)/\(folder)"
                        let folderOpen = store.expanded.contains(folderKey) || !search.isEmpty
                        SidebarRow(indent: 1, action: { toggle(folderKey) }) {
                            Chevron(open: folderOpen)
                            Image(systemName: folderOpen ? "folder" : "folder.fill").foregroundStyle(Theme.faint).font(.system(size: 11))
                            Text(folder).font(.system(size: 12.5, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 4)
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
            Color.clear.frame(width: 10, height: 1)
            MethodTag(method: request.draft.method)
            Text(request.name).font(.system(size: 12.5)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
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
