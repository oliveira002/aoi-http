import SwiftUI

struct TabBar<T: Hashable>: View {
    let tabs: [(T, String)]
    @Binding var selection: T
    var underline = Theme.accent
    var spacing: CGFloat = Theme.Space.xl

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(tabs, id: \.0) { tab in
                let selected = selection == tab.0
                Button { selection = tab.0 } label: {
                    Text(tab.1)
                        .font(.body.weight(.medium))
                        .foregroundStyle(selected ? Theme.text : Theme.muted)
                        .padding(.vertical, Theme.Space.s)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(selected ? underline : .clear).frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { Hairline() }
    }
}

struct Segmented<T: Hashable>: View {
    // The gap between the track and the selected segment; the segment's radius shrinks by it so the corners nest.
    static var inset: CGFloat { 2 }
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                let selected = selection == option.0
                Button { selection = option.0 } label: {
                    Text(option.1)
                        .font(.callout)
                        .foregroundStyle(selected ? Theme.text : Theme.muted)
                        .padding(.horizontal, Theme.Space.m)
                        .frame(height: Theme.controlHeight - 2 * Segmented.inset)
                        .background(selected ? Theme.card : .clear, in: .rect(cornerRadius: Theme.Radius.control - Segmented.inset))
                        .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 1, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Segmented.inset)
        .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.line))
        .fixedSize()
    }
}

extension Segmented where T: CaseIterable, T: RawRepresentable, T.RawValue == String {
    // One segment per case, labelled with its raw value.
    init(selection: Binding<T>) {
        self.init(options: T.allCases.map { ($0, $0.rawValue) }, selection: selection)
    }
}

// A button that asks first, for actions that cannot be undone.
struct ConfirmedButton: View {
    let title: String
    let question: String
    let action: () -> Void
    @State private var asking = false

    var body: some View {
        Button(title) { asking = true }
            .confirmationDialog(question, isPresented: $asking) {
                Button(title, role: .destructive, action: action)
            } message: {
                Text("This cannot be undone.")
            }
    }
}
