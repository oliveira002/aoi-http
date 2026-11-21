import AppKit
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
        Text("\(count)").font(.subheadline).foregroundStyle(Theme.faint).monospacedDigit()
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
        VStack(spacing: Theme.Space.s) {
            if let icon {
                Image(systemName: icon).font(.title).foregroundStyle(tint)
            }
            if let title {
                Text(title).font(.title3.weight(.semibold))
            }
            Text(message)
                .font(.callout)
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
        HStack(alignment: .center, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Eyebrow(eyebrow)
                title.font(.title.weight(.semibold))
                Text(subtitle).font(.body).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: Theme.Space.xl)
            actions.fixedSize()
        }
    }
}

extension View {
    // Small glyphs still get a click area of at least 22pt, the macOS minimum for a comfortable target.
    func hitTarget() -> some View {
        frame(minWidth: 22, minHeight: 22).contentShape(Rectangle())
    }

    // The same click area grown only vertically, for glyphs that must line up with an edge beside them.
    func edgeTarget() -> some View {
        frame(minHeight: 22).contentShape(Rectangle())
    }

    // Shows a resize cursor while a drag handle is hovered or dragged: pushed once, popped once.
    func resizeCursor(_ cursor: NSCursor, active: Bool) -> some View {
        modifier(ResizeCursor(cursor: cursor, active: active))
    }

    // A menu that looks like a ControlButtonStyle button, without the disclosure arrow.
    func controlMenu() -> some View {
        menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(ControlButtonStyle())
            .fixedSize()
    }

    // The raised panel an empty state sits on; dashed when something can be dropped on it.
    func raisedPanel(dashed: Bool = false) -> some View {
        padding(Theme.Space.xl)
            .frame(maxWidth: .infinity)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.container))
            .overlay {
                if dashed {
                    RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
    }
}

private struct ResizeCursor: ViewModifier {
    let cursor: NSCursor
    let active: Bool
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onChange(of: active, initial: true) { show(active) }
            .onDisappear { show(false) }
    }

    private func show(_ wanted: Bool) {
        if wanted, !pushed {
            cursor.push()
            pushed = true
        } else if !wanted, pushed {
            NSCursor.pop()
            pushed = false
        }
    }
}
