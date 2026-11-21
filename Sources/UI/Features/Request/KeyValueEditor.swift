import SwiftUI

struct KeyValueEditor: View {
    @Binding var rows: [KeyValue]
    var noun = "row"
    var hint = ""
    var highlightsVariables = true

    var body: some View {
        if rows.isEmpty {
            EmptyState(message: hint.isEmpty ? "Nothing here yet" : hint) {
                Button("Add \(noun)", systemImage: "plus") { rows.append(KeyValue()) }
                    .buttonStyle(ControlButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: Theme.Space.s) {
                    Color.clear.frame(width: 28, height: 1)
                    Eyebrow("Key").frame(maxWidth: .infinity, alignment: .leading)
                    Eyebrow("Value").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 22, height: 1)
                }
                ScrollView {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(rows) { current in
                            let row = $rows.element(current)
                            HStack(spacing: Theme.Space.s) {
                                Toggle("", isOn: row.enabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                    .frame(width: 28)
                                    .help(current.enabled ? "Included" : "Skipped")
                                Group {
                                    VariableField(title: "key", text: row.key, highlightsVariables: highlightsVariables)
                                    VariableField(title: "value", text: row.value, highlightsVariables: highlightsVariables)
                                }
                                .opacity(current.enabled ? 1 : 0.45)
                                Button {
                                    rows.removeAll { $0.id == current.id }
                                } label: {
                                    Image(systemName: "xmark").font(.subheadline.weight(.semibold)).hitTarget()
                                }
                                .buttonStyle(LinkButtonStyle())
                                .help("Remove")
                            }
                        }
                        Button("Add \(noun)", systemImage: "plus") { rows.append(KeyValue()) }
                            .buttonStyle(LinkButtonStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
