import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var primary = false
    // The fill of a primary pill.
    var tint = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        PillButton(configuration: configuration, primary: primary, tint: tint)
    }

    private struct PillButton: View {
        let configuration: Configuration
        let primary: Bool
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? Theme.card : Theme.text)
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.controlHeight)
                .background(primary ? tint : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(primary ? .clear : Theme.line))
                .contentShape(Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
        }
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5))
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.muted)
            .contentShape(Rectangle())
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.muted)
            .frame(width: Theme.controlHeight, height: Theme.controlHeight)
            .background(configuration.isPressed ? Theme.raised : .clear, in: .rect(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}
