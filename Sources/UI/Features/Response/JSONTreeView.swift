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
                            .padding(.leading, CGFloat(row.depth) * JSONRowView.indent + JSONRowView.textOffset)
                            .padding(.vertical, Theme.Space.xs)
                        }
                    }
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: scrollRequest) { scroll(proxy) }
        }
        .findBar(query: $query, summary: search.summary, found: !search.matches.isEmpty, step: step)
        .onChange(of: query) { runSearch() }
    }

    // MARK: Search

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
        // A jump, not an animation: animating a lazy list across many rows stutters.
        proxy.scrollTo(path, anchor: .center)
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
