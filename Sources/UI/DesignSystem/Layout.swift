import SwiftUI

// A one-point divider in the line colour.
struct Hairline: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
    }
}

// A small number beside a sidebar row, such as how many variables or requests it holds.
struct CountLabel: View {
    let count: Int

    var body: some View {
        Text("\(count)").font(.system(size: 11)).foregroundStyle(Theme.faint).monospacedDigit()
    }
}

// An icon, a title, a line of help and optional actions, for a panel with nothing in it yet.
struct EmptyState<Actions: View>: View {
    var icon: String?
    var tint = Theme.accent
    var title: String?
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 10) {
            if let icon {
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(tint)
            }
            if let title {
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            Text(message)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            actions
        }
    }
}

extension EmptyState where Actions == EmptyView {
    init(icon: String? = nil, tint: Color = Theme.accent, title: String? = nil, message: String) {
        self.init(icon: icon, tint: tint, title: title, message: message) { EmptyView() }
    }
}

// The top of a page: an eyebrow, the large title, a subtitle, and actions on the right.
struct PageHeader<Title: View, Actions: View>: View {
    let eyebrow: String
    let subtitle: String
    @ViewBuilder var title: Title
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(eyebrow)
                title
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.4)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 24)
            actions.fixedSize()
        }
    }
}

extension View {
    // Small glyphs still get a click area of at least 22pt, the macOS minimum for a comfortable target.
    func hitTarget() -> some View {
        frame(minWidth: 22, minHeight: 22).contentShape(Rectangle())
    }

    // A menu that looks like a pill button, without the disclosure arrow.
    func pillMenu() -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(PillButtonStyle())
            .fixedSize()
    }

    // The raised panel an empty state sits on; dashed when something can be dropped on it.
    func raisedPanel(dashed: Bool = false) -> some View {
        padding(20)
            .frame(maxWidth: .infinity)
            .background(Theme.raised, in: .rect(cornerRadius: 12))
            .overlay {
                if dashed {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
    }
}
