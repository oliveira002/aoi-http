import SwiftUI

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line))
    }
}

extension View {
    func card() -> some View { modifier(Card()) }

    func themedField(highlighted: Bool = false, font: Font = .body) -> some View {
        textFieldStyle(.plain)
            .font(font)
            .padding(.horizontal, Theme.Space.s)
            .frame(minHeight: Theme.controlHeight)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(highlighted ? Theme.warn : Theme.line, lineWidth: highlighted ? 1.5 : 1)
            )
    }
}
