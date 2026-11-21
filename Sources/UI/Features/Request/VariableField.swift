import SwiftUI

struct VariableField: View {
    @Environment(Store.self) private var store
    let title: String
    @Binding var text: String
    var highlightsVariables = true
    var font: Font = .body
    // Gets pasted text first; returning true means it was handled, so the field keeps its text.
    var onPaste: ((String) -> Bool)?

    var body: some View {
        let missing = highlightsVariables ? Variables.unresolved(in: text, store.variables) : []
        TextField(title, text: Binding(get: { text }, set: { newValue in
            if !newValue.isSingleEdit(from: text), onPaste?(newValue.insertion(from: text)) == true { return }
            text = newValue.cleanedInput(previous: text)
        }))
            .autocorrectionDisabled()
            .themedField(highlighted: !missing.isEmpty, font: font)
            .help(missing.isEmpty ? "" : "No value yet: " + missing.joined(separator: ", "))
    }
}
