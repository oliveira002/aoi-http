import SwiftUI

enum JSONViewMode: Hashable { case tree, raw }

struct JSONTreeView: View {
    @Environment(Store.self) private var store
    let root: Node
    @Binding var expanded: Set<String>
    @State private var shown: [String: Int] = [:]
    @State private var query = ""
    @State private var search = JSONSearch()
    // Bumped on every search and step, so the same match can be scrolled back into view.
    @State private var scrollRequest = 0
    @State private var searching = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        switch row.kind {
                        case .node(let node):
                            JSONRowView(row: row, node: node, isOpen: expanded.contains(row.id), mark: search.mark(row.id), actions: actions(for: row.id, node: node))
                        case .more(let parent, let remaining):
                            Button("Show \(min(remaining, JSONTree.page)) more of \(remaining)") {
                                shown[parent, default: JSONTree.page] += JSONTree.page
                            }
                            .buttonStyle(LinkButtonStyle())
                            .padding(.leading, CGFloat(row.depth) * JSONRowView.indent + 23)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: scrollRequest) { scroll(proxy) }
        }
        .overlay(alignment: .topTrailing) { searchBar.padding(10) }
        .background {
            Group {
                Button("Find") { openSearch() }.keyboardShortcut("f")
                Button("Find Next") { step(1) }.keyboardShortcut("g")
                Button("Find Previous") { step(-1) }.keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .onChange(of: query) { runSearch() }
    }

    // MARK: Search

    @ViewBuilder private var searchBar: some View {
        if searching {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Find in response", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .frame(width: 180)
                    .onSubmit { step(1) }
                    .onExitCommand(perform: closeSearch)
                if !query.isEmpty {
                    Text(search.summary)
                        .foregroundStyle(search.matches.isEmpty ? Theme.bad : Theme.muted)
                        .monospacedDigit()
                        .fixedSize()
                    Button { step(-1) } label: { Image(systemName: "chevron.up") }
                        .help("Previous (⇧⌘G)")
                    Button { step(1) } label: { Image(systemName: "chevron.down") }
                        .help("Next (Return or ⌘G)")
                }
                Button(action: closeSearch) { Image(systemName: "xmark") }
                    .help("Close (Esc)")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.card, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        } else {
            Button(action: openSearch) { Image(systemName: "magnifyingglass") }
                .buttonStyle(IconButtonStyle())
                .background(Theme.card.opacity(0.9), in: .rect(cornerRadius: 8))
                .help("Find in response (⌘F)")
        }
    }

    private func openSearch() {
        searching = true
        searchFocused = true
    }

    private func closeSearch() {
        searching = false
        query = ""
    }

    private func runSearch() {
        search = JSONSearch(query, in: root)
        search.reveal(expanded: &expanded, shown: &shown)
        scrollRequest += 1
    }

    private func step(_ offset: Int) {
        search.step(offset)
        search.reveal(expanded: &expanded, shown: &shown)
        scrollRequest += 1
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let path = search.currentMatch?.path else { return }
        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(path, anchor: .center) }
    }

    // MARK: Rows

    private var rows: [JSONTree.Row] {
        JSONTree.visibleRows(of: root, expanded: expanded, shown: shown)
    }

    private func actions(for path: String, node: Node) -> JSONRowView.Actions {
        JSONRowView.Actions(
            toggle: { expanded.toggle(path) },
            expandAll: { expanded.formUnion(JSONTree.containerPaths(node, path: path)) },
            collapseAll: { expanded = expanded.filter { !JSONTree.isPath($0, inside: path) } },
            copy: { Pasteboard.copy(node.json) },
            copyPath: { Pasteboard.copy(path) },
            variables: node.string.map { value in
                JSONRowView.VariableActions(
                    suggestions: { VariableNaming.suggestions(forPath: path, inUse: store.variablesInUse) },
                    set: { store.setVariable($0, to: value) }
                )
            }
        )
    }
}
