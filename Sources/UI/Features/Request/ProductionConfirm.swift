import SwiftUI

// "Are you sure?" before a request goes to production. Only a click confirms; Esc or the backdrop cancels.
struct ProductionConfirm: View {
    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { store.confirmingProduction = false }
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.bad)
                VStack(spacing: 6) {
                    Text("Are you sure?").font(.system(size: 18, weight: .semibold))
                    Text("This goes to \(store.activeEnvironment?.name ?? "production"), a production environment.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    MethodTag(method: store.draft.method)
                    Text(store.resolvedURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.raised, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                HStack(spacing: 10) {
                    Button("Cancel") { store.confirmingProduction = false }
                        .buttonStyle(PillButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Button("Send to production") { Task { await store.send() } }
                        .buttonStyle(PillButtonStyle(primary: true, tint: Theme.bad))
                }
            }
            .padding(24)
            .frame(width: 440)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.bad.opacity(0.35)))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
        }
        .transition(.opacity)
    }
}
