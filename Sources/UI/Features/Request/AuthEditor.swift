import SwiftUI

struct AuthEditor: View {
    @Binding var auth: Auth

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Segmented(selection: $auth.mode)
            switch auth.mode {
            case .none:
                Text("No Authorization header is added")
                    .font(.body)
                    .foregroundStyle(Theme.muted)
            case .bearer:
                labeled("Token") { VariableField(title: "{{token}}", text: Binding(get: { auth.token }, set: { auth.token = $0.pastedSecret }), font: Theme.mono) }
            case .basic:
                HStack(spacing: Theme.Space.m) {
                    labeled("Username") { VariableField(title: "username", text: $auth.username) }
                    labeled("Password") {
                        SecureField("password", text: Binding(get: { auth.password }, set: { auth.password = $0.cleanedInput(previous: auth.password) }))
                            .themedField()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func labeled(_ title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Eyebrow(title)
            field()
        }
    }
}
