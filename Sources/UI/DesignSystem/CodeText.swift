import SwiftUI

struct CodeText: View {
    let text: String
    let isJSON: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Same font and no wrapping on either side, so numbers stay level with their lines.
            Text(lineNumbers)
                .font(Theme.mono)
                .foregroundStyle(Theme.faint.opacity(0.8))
                .multilineTextAlignment(.trailing)
                .padding(.trailing, 10)
                .overlay(alignment: .trailing) { Hairline(axis: .vertical) }
            Text(isJSON ? Self.highlighted(text) : AttributedString(text))
                .font(Theme.mono)
                .foregroundStyle(Theme.text)
                .lineSpacing(0)
                .textSelection(.enabled)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lineNumbers: String {
        let count = text.reduce(into: 1) { if $1 == "\n" { $0 += 1 } }
        return (1...count).map(String.init).joined(separator: "\n")
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
