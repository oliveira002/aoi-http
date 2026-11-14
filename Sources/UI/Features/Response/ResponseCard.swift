import SwiftUI

enum ResponseTab: Hashable { case body, headers }

struct ResponseCard: View {
    @Environment(Store.self) private var store
    @State private var tab = ResponseTab.body
    @State private var copied = false
    @State private var jsonMode = JSONViewMode.tree
    @State private var jsonExpanded: Set<String> = []

    var body: some View {
        Group {
            if store.isSending {
                placeholder {
                    ProgressView().controlSize(.small)
                    Text("Waiting for the response…").foregroundStyle(Theme.muted)
                }
            } else if let error = store.error {
                placeholder {
                    EmptyState(icon: "bolt.horizontal.circle", tint: Theme.bad, title: "Could not send the request", message: error)
                }
            } else if let response = store.response {
                loaded(response)
            } else {
                placeholder {
                    EmptyState(icon: "paperplane", tint: Theme.faint, title: "No response yet", message: "Click Send to see the response here")
                }
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
        .onChange(of: store.response?.id, initial: true) {
            jsonExpanded = store.response?.tree.map { JSONTree.defaultExpanded($0, levels: store.settings.jsonExpandLevels) } ?? []
        }
    }

    private func loaded(_ response: ResponseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                ResponseSummary(response: response)
                Spacer(minLength: 16)
                Segmented(
                    options: [(.body, "Body"), (.headers, "Headers \(response.headers.count)")],
                    selection: $tab
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Hairline()

            switch tab {
            case .body:
                bodyToolbar(response)
                if let tree = response.tree, jsonMode == .tree {
                    JSONTreeView(root: tree, expanded: $jsonExpanded)
                        .id(response.id)
                } else {
                    ScrollView([.vertical, .horizontal]) {
                        CodeText(text: response.body.isEmpty ? "(empty body)" : response.body, isJSON: response.isJSON)
                            .padding(18)
                    }
                }
            case .headers:
                ResponseHeadersList(headers: response.headers)
            }
        }
    }

    private func bodyToolbar(_ response: ResponseResult) -> some View {
        HStack(spacing: 14) {
            if let tree = response.tree {
                Segmented(options: [(.tree, "Tree"), (.raw, "Raw")], selection: $jsonMode)
                if jsonMode == .tree, !tree.isScalar {
                    Button("Expand all") { jsonExpanded = JSONTree.containerPaths(tree, path: "$") }
                        .buttonStyle(LinkButtonStyle())
                    Button("Collapse all") { jsonExpanded = ["$"] }
                        .buttonStyle(LinkButtonStyle())
                }
            }
            Spacer()
            Text("Received \(response.receivedAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.faint)
                .help(response.receivedAt.formatted(date: .abbreviated, time: .standard))
            Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                Pasteboard.copy(response.body)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private func placeholder(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 8, content: content)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
