import SwiftUI

struct EnvironmentsPanel: View {
    @Environment(Store.self) private var store
    let search: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Button("Import", systemImage: "square.and.arrow.down") { store.showingImporter = true }
                    .help("Import a Postman environment or a Postman data export")
                Button("New", systemImage: "plus") { store.addEnvironment() }
                Spacer()
            }
            .buttonStyle(LinkButtonStyle())
            if store.environments.isEmpty {
                globalsRow
                EmptyState(
                    icon: "square.stack",
                    title: "Environments",
                    message: "Keep values like baseUrl or token for dev, staging and prod, and switch between them in one click."
                ) {
                    Button("New Environment") { store.addEnvironment() }.buttonStyle(PillButtonStyle(primary: true))
                    Button("or import from Postman") { store.showingImporter = true }.buttonStyle(LinkButtonStyle())
                }
                .raisedPanel()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        globalsRow
                        sessionRow
                        Hairline().padding(.vertical, 6)
                        ForEach(filtered) { row($0) }
                    }
                }
                Text("Click the circle to make an environment active.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.bottom, 10)
            }
        }
    }

    private var globalsRow: some View {
        SidebarRow(selected: store.detail == .variables(.globals), action: { store.showVariables(.globals) }) {
            Image(systemName: "globe").foregroundStyle(Theme.accent)
            Text("Globals").fontWeight(.semibold)
            Spacer(minLength: 4)
            CountLabel(count: store.globals.active.count)
        }
        .help("Values every request uses, such as token")
    }

    // Only while there are values from responses, so it stays out of the way otherwise.
    @ViewBuilder private var sessionRow: some View {
        if !store.sessionVariables.isEmpty {
            SidebarRow(selected: store.detail == .variables(.session), action: { store.showVariables(.session) }) {
                Image(systemName: "clock").foregroundStyle(Theme.warn)
                Text("This Session").fontWeight(.semibold)
                Spacer(minLength: 4)
                CountLabel(count: store.sessionVariables.active.count)
            }
            .help("Values taken from responses. Gone when you quit Aoi.")
        }
    }

    private func row(_ environment: APIEnvironment) -> some View {
        let active = environment.id == store.activeEnvironmentID
        return SidebarRow(selected: store.detail == .variables(.environment(environment.id)), action: { store.detail = .variables(.environment(environment.id)) }) {
            Button {
                store.toggleActive(environment.id)
            } label: {
                Image(systemName: active ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(active ? Theme.accent : Theme.faint)
            }
            .buttonStyle(.plain)
            .help(active ? "Active. Click to turn off." : "Make active")
            Text(environment.name).lineLimit(1).fontWeight(active ? .semibold : .regular)
            Spacer(minLength: 4)
            Button {
                store.toggleProduction(environment.id)
            } label: {
                Image(systemName: environment.isProduction ? "shield.lefthalf.filled" : "shield")
                    .font(.system(size: 11.5))
                    .foregroundStyle(environment.isProduction ? Theme.bad : Theme.faint.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help(environment.isProduction ? "Production: asks before sending. Click to remove." : "Mark as production")
        }
        .help(environment.baseURL.isEmpty ? "No base URL yet" : environment.baseURL)
        .contextMenu {
            Button(active ? "Turn Off" : "Make Active") { store.toggleActive(environment.id) }
            Button(environment.isProduction ? "Remove Production Guard" : "Mark as Production") {
                store.toggleProduction(environment.id)
            }
            Button("Duplicate") { store.duplicateEnvironment(environment.id) }
            Divider()
            Button("Delete", role: .destructive) { store.pendingDeletion = .environment(environment.id) }
        }
    }

    private var filtered: [APIEnvironment] {
        store.environments.matching(SearchQuery(search))
    }
}
