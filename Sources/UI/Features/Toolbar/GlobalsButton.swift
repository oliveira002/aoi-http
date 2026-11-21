import AppKit
import SwiftUI

// Always on the tab row, so the token can be refreshed from anywhere.
struct GlobalsButton: View {
    @Environment(Store.self) private var store
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                // The token requests actually use, after collection and environment overrides.
                let state = TokenState(token: store.variables["token"] ?? "", now: context.date)
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: "key.fill").font(.subheadline)
                    Circle().fill(state.color).frame(width: 7, height: 7)
                    Text(state.label).font(.callout).monospacedDigit()
                }
            }
        }
        .buttonStyle(ControlButtonStyle())
        .help("Globals: the token and other values every request uses")
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            GlobalsPopover(close: { showing = false })
        }
    }
}

extension TokenState {
    var color: Color {
        switch self {
        case .missing: Theme.warn
        case .expired: Theme.bad
        case .notJWT, .valid: expiresSoon ? Theme.warn : Theme.accent
        }
    }
}

struct GlobalsPopover: View {
    @Environment(Store.self) private var store
    let close: () -> Void

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Eyebrow("Globals")
                Text("Every request uses these. Paste a new token whenever it expires.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
            }
            if store.globals.isEmpty {
                Text("No globals yet.").font(.callout).foregroundStyle(Theme.muted)
            }
            ForEach(store.globals) { row in
                globalRow($store.globals.element(row))
            }
            HStack {
                Button("Add variable", systemImage: "plus") { store.globals.append(KeyValue()) }
                    .buttonStyle(LinkButtonStyle())
                Spacer()
                Button("Open Globals") {
                    store.showVariables(.globals)
                    close()
                }
                .buttonStyle(LinkButtonStyle())
            }
        }
        .padding(Theme.Space.l)
        .frame(width: 420)
        .background(Theme.bg)
    }

    private func globalRow(_ row: Binding<KeyValue>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                TextField("name", text: row.key)
                    .textFieldStyle(.plain)
                    .font(.callout.monospaced().weight(.semibold))
                    .foregroundStyle(Theme.JSONColors.key)
                Spacer()
                if let expiry = JWT.expiry(of: row.wrappedValue.value) {
                    let state = TokenState(expiry: expiry, now: .now)
                    Badge(text: state == .expired ? "expired" : "expires \(expiry.formatted(.relative(presentation: .named)))", color: state.color)
                        .help(expiry.formatted(date: .abbreviated, time: .standard))
                }
            }
            HStack(spacing: Theme.Space.s) {
                VariableField(title: "value", text: row.value, highlightsVariables: false, font: Theme.mono)
                Button("Paste") {
                    if let text = NSPasteboard.general.string(forType: .string) { row.wrappedValue.value = text.pastedSecret }
                }
                .buttonStyle(ControlButtonStyle(primary: true))
                .help("Replace with the clipboard, trimmed and without \"Bearer \"")
                Button {
                    row.wrappedValue.value = ""
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconButtonStyle())
                .help("Clear")
                .accessibilityLabel("Clear value")
            }
        }
    }
}
