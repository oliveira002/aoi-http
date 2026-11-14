import SwiftUI

struct JSONRowView: View {
    struct Actions {
        let toggle: () -> Void
        let expandAll: () -> Void
        let collapseAll: () -> Void
        let copy: () -> Void
        let copyPath: () -> Void
        // Present for values that can become a variable.
        var variables: VariableActions?
    }

    struct VariableActions {
        let suggestions: () -> VariableNaming.Suggestions
        let set: (String) -> Void
    }

    static let indent: CGFloat = 18

    let row: JSONTree.Row
    let node: Node
    let isOpen: Bool
    let mark: JSONSearch.Mark
    let actions: Actions
    @State private var hovering = false
    @State private var copied = false
    @State private var setName: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if node.isScalar {
                Color.clear.frame(width: 10, height: 1)
            } else {
                Chevron(open: isOpen)
            }
            label
            value
            Spacer(minLength: 8)
            if let setName {
                Text("{{\(setName)}} set").font(.system(size: 11)).foregroundStyle(Theme.accent)
            }
            if hovering {
                Button {
                    actions.copy()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 10.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(copied ? Theme.accent : Theme.faint)
                .help("Copy value")
            }
        }
        .font(Theme.mono)
        .padding(.leading, CGFloat(row.depth) * Self.indent + 6)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(background, in: .rect(cornerRadius: 6))
        .background(alignment: .leading) {
            // Guides line up under each ancestor's chevron.
            ForEach(0..<row.depth, id: \.self) { level in
                Hairline(axis: .vertical).padding(.leading, 11 + CGFloat(level) * Self.indent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !node.isScalar { actions.toggle() } }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Value", action: actions.copy)
            Button("Copy Path", action: actions.copyPath)
            if let variables = actions.variables {
                Divider()
                variableMenu(variables)
            }
            if !node.isScalar {
                Divider()
                Button("Expand All Below", action: actions.expandAll)
                Button("Collapse All Below", action: actions.collapseAll)
            }
        }
        .help(row.id)
    }

    private var background: Color {
        switch mark {
        case .current: Theme.warn.opacity(0.32)
        case .match: Theme.warn.opacity(0.13)
        case .none: hovering ? Theme.raised : .clear
        }
    }

    @ViewBuilder private var label: some View {
        if let label = row.label {
            if row.isIndex {
                Text(label)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .background(Theme.raised, in: .rect(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.line))
            } else {
                (Text(label).foregroundColor(Theme.JSONColors.key).fontWeight(.medium) + Text(":").foregroundColor(Theme.faint))
            }
        }
    }

    @ViewBuilder private var value: some View {
        if node.isScalar {
            let text = Text(node.json)
                .foregroundStyle(JSONTree.color(node))
                .italic(node.json == "null")
            if let url = JSONTree.link(node) {
                Link(destination: url) { text.underline() }
                    .help("Open \(url.absoluteString)")
            } else {
                text
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(spacing: 6) {
                badge
                if !isOpen {
                    Text(JSONTree.preview(node)).foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.tail)
                }
            }
        }
    }

    // "{} 3" or "[] 12", so the shape and size of a container read at a glance.
    private var badge: some View {
        let isList: Bool = { if case .list = node { return true }; return false }()
        return HStack(spacing: 3) {
            Text(isList ? "[ ]" : "{ }").foregroundStyle(Theme.faint)
            Text("\(node.count ?? 0)").foregroundStyle(Theme.muted).monospacedDigit()
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Theme.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
        .help(isList ? "\(node.count ?? 0) items" : "\(node.count ?? 0) keys")
    }

    // One click keeps the value for this session; it is gone when the app quits.
    @ViewBuilder private func variableMenu(_ variables: VariableActions) -> some View {
        let suggestions = variables.suggestions()
        ForEach(suggestions.fromKey, id: \.self) { name in
            Button("Set {{\(name)}} for This Session") { set(name, with: variables) }
        }
        if !suggestions.inUse.isEmpty {
            Menu("Set as Another Variable") {
                ForEach(suggestions.inUse, id: \.self) { name in
                    Button("{{\(name)}}") { set(name, with: variables) }
                }
            }
        }
    }

    private func set(_ name: String, with variables: VariableActions) {
        variables.set(name)
        setName = name
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            setName = nil
        }
    }
}
