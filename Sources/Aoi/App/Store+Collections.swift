import Foundation

// Collections, the requests saved in them, and importing specs.
extension Store {
    @discardableResult
    func createCollection() -> UUID {
        let collection = APICollection(name: "New Collection")
        collections.append(collection)
        expanded.insert(collection.id.uuidString)
        return collection.id
    }

    func deleteCollection(_ id: UUID) {
        collections.removeAll { $0.id == id }
        for index in tabs.indices where tabs[index].collectionID == id {
            tabs[index].collectionID = nil
            tabs[index].requestID = nil
        }
        if detail == .variables(.collection(id)) { detail = .request }
    }

    func delete(_ deletion: Deletion) {
        switch deletion {
        case .collection(let id): deleteCollection(id)
        case .environment(let id): deleteEnvironment(id)
        }
        pendingDeletion = nil
    }

    func importSpecs(_ urls: [URL]) {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let result = try SpecImporter.importFile(url)
                collections += result.collections
                environments += result.environments
                expanded.formUnion(result.collections.map(\.id.uuidString))
                sidebarTab = result.collections.isEmpty ? .environments : .collections
            } catch {
                importError = "\(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    func saveOpenRequest() {
        guard let at = location(of: openRequestID, in: openCollectionID) else { return }
        collections[at.collection].requests[at.request].draft = draft
    }

    func renameOpenRequest(_ name: String) {
        guard let at = location(of: openRequestID, in: openCollectionID) else { return }
        collections[at.collection].requests[at.request].name = name
    }

    func saveDraft(to collectionID: UUID) {
        guard let c = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        let request = SavedRequest(name: draft.suggestedName, draft: draft)
        collections[c].requests.append(request)
        expanded.insert(collectionID.uuidString)
        openCollectionID = collectionID
        openRequestID = request.id
    }

    func saveDraftToNewCollection() {
        saveDraft(to: createCollection())
    }

    func duplicate(_ requestID: UUID, in collectionID: UUID) {
        guard let at = location(of: requestID, in: collectionID) else { return }
        var copy = collections[at.collection].requests[at.request]
        copy.id = UUID()
        copy.name += " copy"
        collections[at.collection].requests.insert(copy, at: at.request + 1)
    }

    // Tabs showing it stay open as unsaved requests.
    func deleteRequest(_ requestID: UUID, in collectionID: UUID) {
        guard let at = location(of: requestID, in: collectionID) else { return }
        collections[at.collection].requests.remove(at: at.request)
        for index in tabs.indices where tabs[index].requestID == requestID { tabs[index].requestID = nil }
    }
}
