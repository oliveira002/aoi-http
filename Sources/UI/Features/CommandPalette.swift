import SwiftUI

// ⌘K: type to find a request, an environment or an action. Arrows move, Return runs, Esc closes.
struct CommandPalette: View {
    static let width: CGFloat = 640

    @Environment(Store.self) private var store
    // From the window's top edge, so the palette opens right over the title bar search.
    var top: CGFloat = 0
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
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                    TextField("Go to a request, environment or action", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($focused)
                        .onKeyPress(.upArrow) { move(-1, in: results) }
                        .onKeyPress(.downArrow) { move(1, in: results) }
                        .onKeyPress(.return) { run(results) }
                        .onKeyPress(.escape) {
                            store.showingPalette = false
                            return .handled
                        }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.m)
                Hairline()
                if results.isEmpty {
                    EmptyState(message: "Nothing matches “\(query)”").padding(Theme.Space.xl)
                } else {
                    list(results)
                }
            }
            .frame(width: Self.width)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.2), radius: 28, y: 10)
            .padding(.top, top)
        }
        .onAppear { focused = true }
        .onChange(of: query) { selected = 0 }
    }

    private func list(_ results: [PaletteItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Space.xs) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        row(item, selected: index == selected)
                            .id(item.id)
                            .onTapGesture { store.perform(item.action) }
                    }
                }
                .padding(Theme.Space.s)
            }
            .frame(maxHeight: 380)
            .onChange(of: selected) {
                guard results.indices.contains(selected) else { return }
                proxy.scrollTo(results[selected].id)
            }
        }
    }

    private func row(_ item: PaletteItem, selected: Bool) -> some View {
        HStack(spacing: Theme.Space.s) {
            if let method = item.method {
                MethodTag(method: method)
            } else {
                Image(systemName: item.icon)
                    .font(.body)
                    .foregroundStyle(item.icon == "shield.lefthalf.filled" ? Theme.bad : Theme.muted)
                    .frame(width: 40)
            }
            Text(item.title).font(.body.weight(.medium)).lineLimit(1)
            Spacer(minLength: Theme.Space.m)
            Text(item.subtitle).font(.callout).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
        }
        .padding(Theme.Space.s)
        .background(selected ? Theme.accentSoft : .clear, in: .rect(cornerRadius: Theme.Radius.control))
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

// Sits centered in the title bar and opens the palette in the same place, the same as ⌘K.
struct PaletteSearchButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        Button(action: store.togglePalette) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "magnifyingglass").font(.callout)
                Text("Search").font(.body).lineLimit(1)
                Spacer(minLength: Theme.Space.s)
                Text("⌘K").font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, Theme.Space.m)
            .frame(maxWidth: CommandPalette.width, minHeight: Theme.controlHeight, maxHeight: Theme.controlHeight)
            // A tint rather than Theme.raised, so it shows on the title bar band in both light and dark.
            .background(Theme.text.opacity(0.06), in: .rect(cornerRadius: Theme.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.text.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Go to a request, environment or action (⌘K)")
    }
}
