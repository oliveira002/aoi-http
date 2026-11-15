import SwiftUI

struct EnvironmentMenu: View {
    @Environment(Store.self) private var store

    var body: some View {
        let active = store.activeEnvironment
        Menu {
            Button {
                store.activeEnvironmentID = nil
            } label: {
                if active == nil { Label("No Environment", systemImage: "checkmark") } else { Text("No Environment") }
            }
            if !store.environments.isEmpty { Divider() }
            ForEach(store.environments) { environment in
                Button {
                    store.activeEnvironmentID = environment.id
                } label: {
                    if environment.id == active?.id {
                        Label(environment.name, systemImage: "checkmark")
                    } else {
                        Text(environment.name)
                    }
                }
            }
            Divider()
            Button("Edit Globals…") {
                store.showVariables(.globals)
            }
            Button("Manage Environments…") { store.sidebarTab = .environments }
        } label: {
            HStack(spacing: 8) {
                if active?.isProduction == true {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.bad)
                } else {
                    Circle().fill(active == nil ? Theme.faint : Theme.accent).frame(width: 7, height: 7)
                }
                Text(active?.name ?? "No Environment").lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
            }
        }
        .pillMenu()
        .help("Variables like {{baseUrl}} resolve from the active environment")
    }
}
