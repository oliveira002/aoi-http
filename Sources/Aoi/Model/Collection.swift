import Foundation

struct SavedRequest: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var folder: String?
    var draft: RequestDraft
    // From the spec, for body autocomplete. Optional so requests saved before it still decode.
    var bodySchema: BodySchema?
}

struct APICollection: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var variables: [KeyValue] = []
    var requests: [SavedRequest] = []

    // Folders in the order they first appear, with requests outside any folder under nil.
    var folders: [(name: String?, requests: [SavedRequest])] {
        var order: [String?] = []
        var groups: [String?: [SavedRequest]] = [:]
        for request in requests {
            if groups[request.folder] == nil { order.append(request.folder) }
            groups[request.folder, default: []].append(request)
        }
        let ordered = order.filter { $0 == nil } + order.filter { $0 != nil }
        return ordered.map { ($0, groups[$0] ?? []) }
    }
}
