import SwiftUI

// "Are you sure?" before a request goes to production. Only a click confirms; Esc or the backdrop cancels.
struct ProductionConfirm: View {
    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { store.confirmingProduction = false }
            VStack(spacing: Theme.Space.l) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.bad)
                VStack(spacing: Theme.Space.s) {
                    Text("Are you sure?").font(.title2.weight(.semibold))
                    Text("This goes to \(store.activeEnvironment?.name ?? "production"), a production environment.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: Theme.Space.s) {
                    MethodTag(method: store.draft.method)
                    Text(store.resolvedURL)
                        .font(.callout.monospaced())
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, Theme.Space.s)
                .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.container))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line))
                HStack(spacing: Theme.Space.s) {
                    Button("Cancel") { store.confirmingProduction = false }
                        .buttonStyle(ControlButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button("Send to production") { Task { await store.send() } }
                        .buttonStyle(ControlButtonStyle(primary: true, tint: Theme.bad))
                }
            }
            .padding(Theme.Space.xl)
            .frame(width: 440)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.bad.opacity(0.35)))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        }
        .transition(.opacity)
    }
}
