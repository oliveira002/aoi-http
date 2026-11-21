import SwiftUI

struct ControlButtonStyle: ButtonStyle {
    var primary = false
    // The fill of a primary button.
    var tint = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        ControlButton(configuration: configuration, primary: primary, tint: tint)
    }

    private struct ControlButton: View {
        let configuration: Configuration
        let primary: Bool
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.control)
            configuration.label
                .font(primary ? .headline : .body)
                .foregroundStyle(primary ? .white : Theme.text)
                .padding(.horizontal, Theme.Space.m)
                .frame(minHeight: Theme.controlHeight)
                .background(primary ? tint : Theme.card, in: shape)
                .overlay(shape.strokeBorder(primary ? .clear : Theme.line))
                .contentShape(shape)
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
        }
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.muted)
            .contentShape(Rectangle())
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.muted)
            .frame(width: Theme.controlHeight, height: Theme.controlHeight)
            .background(configuration.isPressed ? Theme.raised : .clear, in: .rect(cornerRadius: Theme.Radius.control))
            .contentShape(Rectangle())
    }
}
