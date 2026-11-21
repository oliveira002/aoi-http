import SwiftUI

struct URLBar: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if !store.draft.pathVariables.isEmpty {
                Hairline()
                PathFields().padding(.horizontal, Theme.Space.l).padding(.vertical, Theme.Space.s)
            }
        }
        .card()
    }

    private var mainRow: some View {
        @Bindable var store = store
        return HStack(spacing: Theme.Space.s) {
            Menu {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Button(method.rawValue) { store.draft.method = method }
                }
            } label: {
                HStack(spacing: Theme.Space.s) {
                    Text(store.draft.method.rawValue)
                        .font(.headline.monospaced())
                        .foregroundStyle(Theme.method(store.draft.method))
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                }
                .frame(width: 84)
            }
            .controlMenu()

            VariableField(
                title: "Enter a URL, for example {{baseUrl}}/books",
                text: $store.draft.url,
                font: .title3.monospaced(),
                onPaste: store.applyCurl
            )

            Menu {
                Button("Copy as cURL") { store.curlCommand(hidingSecrets: false).map(Pasteboard.copy) }
                Button("Copy as cURL, Secrets Hidden") { store.curlCommand(hidingSecrets: true).map(Pasteboard.copy) }
            } label: {
                Image(systemName: "terminal")
            }
            .controlMenu()
            .disabled(store.draft.url.isEmpty)
            .help("Copy this request as a curl command. Paste a curl into the URL field to load one.")
            .accessibilityLabel("Copy as cURL")

            Button(action: send) {
                HStack(spacing: Theme.Space.s) {
                    if store.isSending {
                        ProgressView().controlSize(.small).tint(Theme.card)
                    } else {
                        Image(systemName: store.sendNeedsConfirmation ? "shield.lefthalf.filled" : "paperplane.fill")
                    }
                    Text("Send")
                }
                .frame(minWidth: 64)
            }
            .buttonStyle(ControlButtonStyle(primary: true))
            // ⌘Return, never plain Return, so typing in a field cannot send by accident.
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(store.isSending || store.draft.url.isEmpty)
            .help(store.sendNeedsConfirmation ? "Send (⌘Return). Production: asks before sending" : "Send (⌘Return)")
        }
        // Same side inset as the cards below, so the method lines up with their contents.
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.s)
    }

    private func send() {
        store.requestSend()
    }

}

// One field per {{variable}} in the URL path. Typing writes the value into the URL; clearing it puts {{name}} back.
struct PathFields: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            Eyebrow("Path")
            ForEach(store.draft.pathVariables, id: \.self) { name in
                HStack(spacing: Theme.Space.s) {
                    Text(name)
                        .font(.callout.monospaced().weight(.medium))
                        .foregroundStyle(Theme.JSONColors.key)
                    TextField(store.variables[name] ?? "value", text: value(for: name))
                        .themedField(highlighted: store.draft.pathValue(for: name).isEmpty && store.variables[name] == nil, font: .callout.monospaced())
                        .frame(minWidth: 110, maxWidth: 240)
                        .help(store.variables[name].map { "Empty uses \($0) from your variables" } ?? "No value yet")
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func value(for name: String) -> Binding<String> {
        Binding(
            get: { store.draft.pathValue(for: name) },
            set: { store.draft.setPathValue($0.cleanedInput(previous: store.draft.pathValue(for: name)), for: name) }
        )
    }
}
