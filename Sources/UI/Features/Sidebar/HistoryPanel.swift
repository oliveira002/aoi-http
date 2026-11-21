import SwiftUI

struct HistoryPanel: View {
    @Environment(Store.self) private var store
    let search: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if store.history.isEmpty {
                EmptyState(message: "Requests you send show up here. Click one to load it back into the builder.")
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Space.l)
                Spacer()
            } else {
                HStack {
                    Text(Format.count(store.history.count, "request")).font(.callout).foregroundStyle(Theme.faint)
                    Spacer()
                    ConfirmedButton(title: "Clear", question: "Clear all history?") { store.history.removeAll() }
                        .buttonStyle(LinkButtonStyle())
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(days, id: \.day) { group in
                            Eyebrow(HistoryEntry.dayTitle(group.day))
                                .padding(.horizontal, Theme.Space.s)
                                .padding(.top, Theme.Space.m)
                                .padding(.bottom, Theme.Space.xs)
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry, collection: store.collection(entry.collectionID)?.name)
                                    .contextMenu {
                                        Button("Delete", role: .destructive) { store.deleteHistory(entry.id) }
                                    }
                            }
                        }
                    }
                    .padding(.bottom, Theme.Space.m)
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
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(entry.requestName ?? entry.draft.displayPath)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.subtitle(collection: collection))
                    .font(.subheadline)
                    .foregroundStyle(Theme.faint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: Theme.Space.s)
            VStack(alignment: .trailing, spacing: Theme.Space.xs) {
                Text(entry.statusCode.map(String.init) ?? "Failed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.status(entry.statusCode))
                    .monospacedDigit()
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.faint)
                    .monospacedDigit()
            }
        }
        .help(entry.draft.url)
    }
}
