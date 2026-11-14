import SwiftUI

struct BodyEditor: View {
    @Binding var draft: RequestDraft
    let schema: BodySchema?

    var body: some View {
        let status = draft.bodyMode == .json ? JSONBody.status(of: draft.rawBody, schema: schema) : .empty
        let invalid = if case .invalid = status { true } else { false }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Segmented(selection: $draft.bodyMode)
                Spacer()
                if draft.bodyMode == .json {
                    statusLabel(status)
                    Button("Format", systemImage: "text.alignleft") {
                        draft.rawBody = JSONBody.format(draft.rawBody) ?? draft.rawBody
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(invalid || status == .empty)
                    .help("Pretty-print the JSON. {{variables}} are kept as they are.")
                    if let schema {
                        Menu {
                            Button("All Fields") { draft.rawBody = schema.example(requiredOnly: false).json }
                            Button("Required Only") { draft.rawBody = schema.example(requiredOnly: true).json }
                        } label: {
                            Label("Example", systemImage: "wand.and.stars")
                        }
                        .pillMenu()
                        .help("Replace the body with an example built from the spec")
                    }
                }
            }
            if draft.bodyMode != .none, !draft.method.allowsBody {
                Text("\(draft.method.rawValue) requests are sent without a body")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.warn)
            }
            switch draft.bodyMode {
            case .none:
                Text("This request has no body")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .json:
                JSONEditor(text: $draft.rawBody, schema: schema)
                    .background(Theme.raised.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(invalid ? Theme.bad.opacity(0.5) : Theme.line))
            case .form:
                KeyValueEditor(rows: $draft.formFields, noun: "field", hint: "Sent as application/x-www-form-urlencoded")
            }
        }
    }

    @ViewBuilder private func statusLabel(_ status: JSONBody.Status) -> some View {
        switch status {
        case .empty:
            EmptyView()
        case .invalid(let problem):
            Label(problem, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.bad)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(problem)
        case .missing(let fields):
            Label("Missing \(fields.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.warn)
                .lineLimit(1)
                .truncationMode(.tail)
                .help("Required by the spec: " + fields.joined(separator: ", ") + ". Press Esc in the body to see every field.")
        case .valid:
            Label("Valid JSON", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
                .help(schema == nil ? "" : "Press Esc in the body to see every field this endpoint accepts")
        }
    }
}
