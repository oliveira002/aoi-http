import SwiftUI

struct CodeText: View {
    // The id of a marker on the current match, for a ScrollViewReader to scroll to.
    static let currentMatchID = "current-match"

    // Everything that only depends on the text, worked out once per text and off the main thread:
    // colouring a big body takes hundreds of milliseconds, too slow to redo on every find step.
    struct Layout {
        let id = UUID()
        let styled: AttributedString
        let lineNumbers: String
        let lineCount: Int
        let longestLine: Int

        init(_ text: String, isJSON: Bool) {
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            styled = isJSON ? Self.highlighted(text) : AttributedString(text)
            lineNumbers = (1...lines.count).map(String.init).joined(separator: "\n")
            lineCount = lines.count
            longestLine = max(lines.map(\.count).max() ?? 1, 1)
        }

        private static func highlighted(_ text: String) -> AttributedString {
            var result = AttributedString(text)
            guard text.utf8.count < JSONSyntax.highlightLimit else { return result }
            for token in JSONSyntax.tokens(in: text) {
                guard let range = Range(token.range, in: result) else { continue }
                result[range].foregroundColor = token.color
            }
            return result
        }
    }

    let text: String
    let isJSON: Bool
    var highlights: [Range<String.Index>] = []
    var current: Range<String.Index>?
    @State private var layout: Layout?

    var body: some View {
        Group {
            if let layout {
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    // Same font and no wrapping on either side, so numbers stay level with their lines.
                    Text(layout.lineNumbers)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.faint.opacity(0.8))
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, Theme.Space.s)
                        .overlay(alignment: .trailing) { Hairline(axis: .vertical) }
                    MarkedText(layout: layout, highlights: highlights)
                        .equatable()
                        .overlay(alignment: .topLeading) { currentMatchMarker(layout) }
                }
                .fixedSize()
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: text) {
            let (text, isJSON) = (text, isJSON)
            layout = await Task.detached(priority: .userInitiated) { Layout(text, isJSON: isJSON) }.value
        }
    }

    // The current match's stronger wash. Line height and character width come from the drawn text, not the font, so it
    // lands on the match however long the body is. The font is monospaced, so every character is as wide.
    @ViewBuilder private func currentMatchMarker(_ layout: Layout) -> some View {
        if let current {
            GeometryReader { proxy in
                let position = text.position(of: current.lowerBound)
                let lineHeight = proxy.size.height / CGFloat(layout.lineCount)
                let charWidth = proxy.size.width / CGFloat(layout.longestLine)
                let width = charWidth * CGFloat(text[current].count)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.warn.opacity(0.22))
                    .frame(width: width, height: lineHeight)
                    .allowsHitTesting(false)
                    .position(x: (CGFloat(position.column) * charWidth) + width / 2, y: (CGFloat(position.line) + 0.5) * lineHeight)
                    .id(Self.currentMatchID)
            }
        }
    }
}

// The body with every find match washed amber. It only changes with the query, never on a step:
// re-laying out a big body is the slow part, so stepping just moves the current-match marker on top.
private struct MarkedText: View, Equatable {
    let layout: CodeText.Layout
    let highlights: [Range<String.Index>]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.layout.id == rhs.layout.id && lhs.highlights == rhs.highlights
    }

    var body: some View {
        Text(marked)
            .font(Theme.mono)
            .foregroundStyle(Theme.text)
            .lineSpacing(0)
            .textSelection(.enabled)
    }

    private var marked: AttributedString {
        var result = layout.styled
        for match in highlights {
            guard let range = Range(match, in: result) else { continue }
            result[range].backgroundColor = Theme.warn.opacity(0.13)
        }
        return result
    }
}
