import SwiftUI

// ⌘K: type to find a request, an environment or an action. Arrows move, Return runs, Esc closes.
struct CommandPalette: View {
    static let width: CGFloat = 560

    @Environment(Store.self) private var store
    @Environment(\.openSettings) private var openSettings
    // Where the search bar sits, so the palette opens right on top of it.
    let bar: CGRect
    @State private var query = ""
    @State private var selected = 0
    @FocusState private var focused: Bool

    var body: some View {
        let results = store.paletteResults(for: query)
        ZStack(alignment: .topLeading) {
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
            .frame(width: Self.width)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.2), radius: 28, y: 10)
            .offset(x: bar.midX - Self.width / 2, y: bar.minY)
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
                            .onTapGesture { perform(item.action) }
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
            Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            Spacer(minLength: 12)
            Text(item.subtitle).font(.system(size: 12)).foregroundStyle(Theme.faint).lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(selected ? Theme.accentSoft : .clear, in: .rect(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func perform(_ action: PaletteAction) {
        if action == .settings { openSettings() }
        store.perform(action)
    }

    private func move(_ offset: Int, in results: [PaletteItem]) -> KeyPress.Result {
        guard !results.isEmpty else { return .handled }
        selected = (selected + offset + results.count) % results.count
        return .handled
    }

    private func run(_ results: [PaletteItem]) -> KeyPress.Result {
        guard results.indices.contains(selected) else { return .handled }
        perform(results[selected].action)
        return .handled
    }
}

// Sits centered above the tabs and opens the palette, the same as ⌘K.
struct PaletteSearchButton: View {
    struct Bounds: PreferenceKey {
        static let defaultValue: Anchor<CGRect>? = nil
        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) { value = value ?? nextValue() }
    }

    @Environment(Store.self) private var store

    var body: some View {
        Button(action: store.togglePalette) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12))
                Text("Search").font(.system(size: 12.5)).lineLimit(1)
                Spacer(minLength: 8)
                Text("⌘K").font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .frame(maxWidth: CommandPalette.width, minHeight: Theme.controlHeight, maxHeight: Theme.controlHeight)
            .background(Theme.raised, in: .rect(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .anchorPreference(key: Bounds.self, value: .bounds) { $0 }
        .help("Go to a request, environment or action (⌘K)")
    }
}
