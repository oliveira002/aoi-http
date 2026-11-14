import SwiftUI

struct UnresolvedBanner: View {
    @Environment(Store.self) private var store

    var body: some View {
        let missing = store.draft.unresolvedVariables(store.variables)
        if !missing.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(missing.map { "{{\($0)}}" }.joined(separator: ", "))
                    .font(.system(size: 12.5, design: .monospaced))
                Text("have no value yet")
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
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.warn)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.warn.opacity(0.1), in: .rect(cornerRadius: 10))
        }
    }
}
