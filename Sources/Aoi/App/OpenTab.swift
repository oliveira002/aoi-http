import Foundation

// One open request. The store forwards draft, response and the rest to the active tab.
struct OpenTab: Identifiable {
    var id = UUID()
    var draft = RequestDraft()
    // What the tab opened with, so edits to a request that is not saved in a collection still count.
    var original = RequestDraft()
    var response: ResponseResult?
    var error: String?
    var isSending = false
    var collectionID: UUID?
    var requestID: UUID?
    var historyID: UUID?

    // Untouched, so opening something else may take its place.
    var isBlank: Bool {
        requestID == nil && historyID == nil && draft == RequestDraft() && !isSending && response == nil && error == nil
    }
}
