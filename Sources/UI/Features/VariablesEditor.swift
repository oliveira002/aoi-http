import SwiftUI

// One editor for globals, a collection or an environment; only the header differs.
struct VariablesEditor: View {
    @Environment(Store.self) private var store
    let scope: VariableScope

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            switch scope {
            case .globals:
                header(eyebrow: "Globals", name: nil, subtitle: "Every request uses these. A collection or environment with the same name overrides them.") {
                    EmptyView()
                }
            case .session:
                header(eyebrow: "This Session", name: nil, subtitle: "Values taken from responses. They override everything else and are gone when you quit Aoi.") {
                    ConfirmedButton(title: "Clear", question: "Clear all session values?") { store.sessionVariables = [] }
                        .buttonStyle(ControlButtonStyle())
                }
            case .collection(let id):
                if let collection = store.collection(id) {
                    header(
                        eyebrow: "Collection",
                        name: $store.collections.element(collection).name,
                        subtitle: "\(Format.count(collection.requests.count, "request")). These override globals for requests in this collection."
                    ) {
                        Button("Delete") { store.pendingDeletion = .collection(id) }.buttonStyle(ControlButtonStyle())
                    }
                }
            case .environment(let id):
                if let environment = store.environment(id) {
                    let active = store.activeEnvironmentID == id
                    header(
                        eyebrow: "Environment",
                        name: $store.environments.element(environment).name,
                        subtitle: active ? "Active. Requests go to its base URL." : "Not active. Turn it on to send requests here."
                    ) {
                        Toggle("Production", isOn: Binding(get: { environment.isProduction }, set: { store.setProduction($0, for: id) }))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .font(.body)
                            .help("Ask before sending while this environment is active")
                        Toggle("Active", isOn: Binding(get: { active }, set: { store.activeEnvironmentID = $0 ? id : nil }))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .font(.body)
                        Button("Duplicate") { store.duplicateEnvironment(id) }.buttonStyle(ControlButtonStyle())
                        Button("Delete") { store.pendingDeletion = .environment(id) }.buttonStyle(ControlButtonStyle())
                    }
                }
            }
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                if case .environment(let id) = scope, let environment = store.environment(id) {
                    Eyebrow("Base URL")
                    VariableField(
                        title: "https://api.example.com",
                        text: $store.environments.element(environment).baseURL,
                        highlightsVariables: false,
                        font: .title3.monospaced()
                    )
                    Text("Requests use it as {{baseUrl}}.").font(.callout).foregroundStyle(Theme.faint)
                    Eyebrow("Other variables").padding(.top, Theme.Space.m)
                    KeyValueEditor(
                        rows: $store.environments.element(environment).otherVariables,
                        noun: "variable",
                        hint: "Values only this environment needs, used as {{name}}",
                        highlightsVariables: false
                    )
                } else {
                    Eyebrow("Variables")
                    KeyValueEditor(
                        rows: Binding(get: { store.rows(in: scope) }, set: { store.setRows($0, in: scope) }),
                        noun: "variable",
                        hint: "Add a value such as token, then use it as {{token}} in any request",
                        highlightsVariables: false
                    )
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card()
        }
        .id(scope)
    }

    private func header(eyebrow: String, name: Binding<String>?, subtitle: String, @ViewBuilder actions: () -> some View) -> some View {
        PageHeader(eyebrow: eyebrow, subtitle: subtitle) {
            if let name {
                TextField("Name", text: name).textFieldStyle(.plain).help("Click to rename")
            } else {
                Text(eyebrow)
            }
        } actions: {
            actions()
        }
    }
}
