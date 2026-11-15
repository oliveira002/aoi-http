import SwiftUI

struct HeaderView: View {
    @Environment(Store.self) private var store

    var body: some View {
        PageHeader(eyebrow: store.breadcrumb, subtitle: store.statusLine) {
            HStack(spacing: 12) {
                Beacon(color: beaconColor, pulsing: store.isSending)
                if let request = store.openRequest {
                    // A hidden copy of the name sets the width: it hugs short names, so the Unsaved pill sits
                    // right next to them, and gives way on long ones instead of pushing the buttons out.
                    Text(request.name.isEmpty ? "Request name" : request.name)
                        .lineLimit(1)
                        .padding(.trailing, 2)
                        .hidden()
                        .overlay {
                            TextField("Request name", text: Binding(get: { request.name }, set: store.renameOpenRequest))
                                .textFieldStyle(.plain)
                        }
                        .help("Click to rename")
                } else {
                    Text(store.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if store.isDirty {
                    Pill(text: "Unsaved", color: Theme.warn)
                }
                Spacer(minLength: 0)
            }
        } actions: {
            SaveButton()
            EnvironmentMenu()
        }
    }

    private var beaconColor: Color {
        if store.isSending { return Theme.accent }
        if let response = store.response { return Theme.status(response.statusCode) }
        return store.error == nil ? Theme.faint : Theme.bad
    }
}

struct SaveButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.openRequest != nil {
            Button("Save", systemImage: "checkmark") { store.saveOpenRequest() }
                .buttonStyle(PillButtonStyle())
                .disabled(!store.isDirty)
                .help("Save changes to the collection (⌘S)")
        } else {
            Menu {
                ForEach(store.collections) { collection in
                    Button(collection.name) { store.saveDraft(to: collection.id) }
                }
                if !store.collections.isEmpty { Divider() }
                Button("New Collection") { store.saveDraftToNewCollection() }
            } label: {
                Label("Save to…", systemImage: "tray.and.arrow.down")
            }
            .pillMenu()
            .help("Save this request into a collection")
        }
    }
}
