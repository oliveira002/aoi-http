import SwiftUI

extension View {
    // ⌘F find in the top-right corner. The caller searches whenever `query` changes and moves on `step`.
    func findBar(query: Binding<String>, summary: String, found: Bool, step: @escaping (Int) -> Void) -> some View {
        overlay(alignment: .topTrailing) {
            FindBar(query: query, summary: summary, found: found, step: step).padding(Theme.Space.s)
        }
    }
}

private struct FindBar: View {
    @Binding var query: String
    let summary: String
    let found: Bool
    let step: (Int) -> Void
    @State private var searching = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if searching { bar } else { openButton }
        }
        .background {
            Group {
                Button("Find", action: open).keyboardShortcut("f")
                Button("Find Next") { step(1) }.keyboardShortcut("g")
                Button("Find Previous") { step(-1) }.keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
    }

    private var bar: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
            TextField("Find in response", text: $query)
                .textFieldStyle(.plain)
                .focused($focused)
                .frame(width: 180)
                .onSubmit { step(1) }
                .onExitCommand(perform: close)
            if !query.isEmpty {
                Text(summary)
                    .foregroundStyle(found ? Theme.muted : Theme.bad)
                    .monospacedDigit()
                    .fixedSize()
                Button { step(-1) } label: { Image(systemName: "chevron.up").hitTarget() }
                    .help("Previous (⇧⌘G)")
                    .accessibilityLabel("Previous match")
                Button { step(1) } label: { Image(systemName: "chevron.down").hitTarget() }
                    .help("Next (Return or ⌘G)")
                    .accessibilityLabel("Next match")
            }
            Button(action: close) { Image(systemName: "xmark").hitTarget() }
                .help("Close (Esc)")
                .accessibilityLabel("Close find")
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(Theme.muted)
        .padding(Theme.Space.s)
        .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private var openButton: some View {
        Button(action: open) { Image(systemName: "magnifyingglass") }
            .buttonStyle(IconButtonStyle())
            .background(Theme.card.opacity(0.9), in: .rect(cornerRadius: Theme.Radius.control))
            .help("Find in response (⌘F)")
            .accessibilityLabel("Find in response")
    }

    private func open() {
        searching = true
        focused = true
    }

    private func close() {
        searching = false
        query = ""
    }
}
