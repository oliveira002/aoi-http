import SwiftUI

struct HistoryPanel: View {
    @Environment(Store.self) private var store
    let search: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.history.isEmpty {
                EmptyState(message: "Requests you send show up here. Click one to load it back into the builder.")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                Spacer()
            } else {
                HStack {
                    Text("\(store.history.count) requests").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    Spacer()
                    Button("Clear") { store.history.removeAll() }.buttonStyle(LinkButtonStyle())
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(days, id: \.day) { group in
                            Eyebrow(HistoryEntry.dayTitle(group.day))
                                .padding(.horizontal, 8)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry, collection: store.collection(entry.collectionID)?.name)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { store.deleteHistory(entry.id) }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var days: [(day: Date, entries: [HistoryEntry])] {
        store.history.days(matching: SearchQuery(search))
    }
}

struct HistoryRow: View {
    @Environment(Store.self) private var store
    let entry: HistoryEntry
    let collection: String?

    var body: some View {
        SidebarRow(selected: store.loadedHistoryID == entry.id, action: { store.load(entry) }) {
            MethodTag(method: entry.draft.method)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.requestName ?? entry.draft.displayPath)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.subtitle(collection: collection))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.statusCode.map(String.init) ?? "Failed")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.status(entry.statusCode))
                    .monospacedDigit()
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .monospacedDigit()
            }
        }
        .help(entry.draft.url)
    }
}
