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
                    .buttonStyle(PillButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Color.clear.frame(width: 28, height: 1)
                    Eyebrow("Key").frame(maxWidth: .infinity, alignment: .leading)
                    Eyebrow("Value").frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(width: 22, height: 1)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(rows) { current in
                            let row = $rows.element(current)
                            HStack(spacing: 10) {
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
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).hitTarget()
                                }
                                .buttonStyle(LinkButtonStyle())
                                .help("Remove")
                            }
                        }
                    }
                }
                Button("Add \(noun)", systemImage: "plus") { rows.append(KeyValue()) }
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }
}
