import Foundation

// The sidebar filter. Matching ignores case, and a blank query matches everything.
struct SearchQuery {
    let text: String

    init(_ raw: String) {
        text = raw.trimmingCharacters(in: .whitespaces)
    }

    var isEmpty: Bool { text.isEmpty }

    func matches(_ fields: String?...) -> Bool {
        isEmpty || fields.contains { $0?.localizedCaseInsensitiveContains(text) == true }
    }
}

extension APICollection {
    // Folders with only the requests that match, leaving out folders with none.
    func folders(matching query: SearchQuery) -> [(name: String?, requests: [SavedRequest])] {
        guard !query.isEmpty else { return folders }
        return folders.compactMap { folder in
            let requests = folder.requests.filter { query.matches($0.name, $0.draft.url) }
            return requests.isEmpty ? nil : (folder.name, requests)
        }
    }
}

extension [APIEnvironment] {
    func matching(_ query: SearchQuery) -> [APIEnvironment] {
        filter { query.matches($0.name) }
    }
}

extension [HistoryEntry] {
    // Matching entries grouped by calendar day, keeping their order (newest first).
    func days(matching query: SearchQuery, calendar: Calendar = .current) -> [(day: Date, entries: [HistoryEntry])] {
        var days: [(day: Date, entries: [HistoryEntry])] = []
        for entry in self where query.matches(entry.draft.url, entry.draft.method.rawValue, entry.requestName) {
            let day = calendar.startOfDay(for: entry.date)
            if days.last?.day == day {
                days[days.count - 1].entries.append(entry)
            } else {
                days.append((day, [entry]))
            }
        }
        return days
    }
}
