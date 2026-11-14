import SwiftUI

// ⌘K: type to find a request, an environment or an action. Arrows move, Return runs, Esc closes.
struct CommandPalette: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var selected = 0
    @FocusState private var focused: Bool

    var body: some View {
        let results = store.paletteResults(for: query)
        ZStack(alignment: .top) {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { store.showingPalette = false }
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                    TextField("Go to a request, environment or action", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($focused)
                        .onKeyPress(.upArrow) { move(-1, in: results) }
                        .onKeyPress(.downArrow) { move(1, in: results) }
                        .onKeyPress(.return) { run(results) }
                        .onKeyPress(.escape) {
                            store.showingPalette = false
                            return .handled
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                Hairline()
                if results.isEmpty {
                    EmptyState(message: "Nothing matches “\(query)”").padding(24)
                } else {
                    list(results)
                }
            }
            .frame(width: 600)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.2), radius: 28, y: 10)
            .padding(.top, 70)
        }
        .onAppear { focused = true }
        .onChange(of: query) { selected = 0 }
    }

    private func list(_ results: [PaletteItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == selected)
                            .id(item.id)
                            .onTapGesture { store.perform(item.action) }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 380)
            .onChange(of: selected) {
                guard results.indices.contains(selected) else { return }
                proxy.scrollTo(results[selected].id)
            }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: 10) {
            if let method = item.method {
                MethodTag(method: method)
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(item.icon == "shield.lefthalf.filled" ? Theme.bad : Theme.muted)
                    .frame(width: 40)
            }
            Text(item.title).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
            Spacer(minLength: 12)
            Text(item.subtitle).font(.system(size: 12)).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? Theme.accentSoft : .clear, in: .rect(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func move(_ offset: Int, in results: [PaletteItem]) -> KeyPress.Result {
        guard !results.isEmpty else { return .handled }
        selected = (selected + offset + results.count) % results.count
        return .handled
    }

    private func run(_ results: [PaletteItem]) -> KeyPress.Result {
        guard results.indices.contains(selected) else { return .handled }
        store.perform(results[selected].action)
        return .handled
    }
}
