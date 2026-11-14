import Foundation

struct HistoryEntry: Identifiable {
    var id = UUID()
    var date: Date
    var draft: RequestDraft
    var statusCode: Int?
    var collectionID: UUID?
    var requestName: String?
    var requestID: UUID?
    var error: String?
}

extension HistoryEntry {
    // The line under the name: collection and path, or the host for a request that was never saved.
    func subtitle(collection: String?) -> String {
        let parts = [collection, requestName == nil ? nil : draft.displayPath].compactMap { $0 }
        guard parts.isEmpty else { return parts.joined(separator: "  ·  ") }
        return URLComponents(string: draft.url)?.host ?? "Scratch request"
    }

    static func dayTitle(_ day: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: day)
        if start == today { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), start == yesterday { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
