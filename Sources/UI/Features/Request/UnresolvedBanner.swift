import SwiftUI

struct UnresolvedBanner: View {
    @Environment(Store.self) private var store

    var body: some View {
        let missing = store.draft.unresolvedVariables(store.variables)
        if !missing.isEmpty {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(missing.map { "{{\($0)}}" }.joined(separator: ", "))
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(missing.joined(separator: ", "))
                Text(missing.count == 1 ? "has no value yet" : "have no value yet")
                    .fixedSize()
                Spacer()
                if let environment = store.environmentDefining(missing) {
                    Button("Switch to \(environment.name)") { store.activeEnvironmentID = environment.id }
                        .buttonStyle(LinkButtonStyle())
                        .foregroundStyle(Theme.accent)
                }
                Menu("Set value in…") {
                    Button("Globals") { store.addMissing(missing, to: .globals) }
                    if let collection = store.openCollection {
                        Button("Collection \(collection.name)") { store.addMissing(missing, to: .collection(collection.id)) }
                    }
                    if let environment = store.activeEnvironment {
                        Button("Environment \(environment.name)") { store.addMissing(missing, to: .environment(environment.id)) }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .font(.callout)
            .foregroundStyle(Theme.warn)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.s)
            .background(Theme.warn.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.container))
        }
    }
}
