import SwiftUI

struct TabBar<T: Hashable>: View {
    let tabs: [(T, String)]
    @Binding var selection: T
    var underline = Theme.accent
    var spacing: CGFloat = 22

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(tabs, id: \.0) { tab in
                let selected = selection == tab.0
                Button { selection = tab.0 } label: {
                    Text(tab.1)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? Theme.text : Theme.muted)
                        .padding(.vertical, 9)
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
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                let selected = selection == option.0
                Button { selection = option.0 } label: {
                    Text(option.1)
                        .font(.system(size: 12))
                        .foregroundStyle(selected ? Theme.text : Theme.muted)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(selected ? Theme.card : .clear, in: .rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 1, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.raised, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        .fixedSize()
    }
}

extension Segmented where T: CaseIterable, T: RawRepresentable, T.RawValue == String {
    // One segment per case, labelled with its raw value.
    init(selection: Binding<T>) {
        self.init(options: T.allCases.map { ($0, $0.rawValue) }, selection: selection)
    }
}
