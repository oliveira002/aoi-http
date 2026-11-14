import SwiftUI

struct Card: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 8, y: 2)
    }
}

extension View {
    func card() -> some View { modifier(Card()) }

    func themedField(highlighted: Bool = false, font: Font = .system(size: 13)) -> some View {
        textFieldStyle(.plain)
            .font(font)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.raised, in: .rect(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(highlighted ? Theme.warn : Theme.line, lineWidth: highlighted ? 1.5 : 1)
            )
    }
}
