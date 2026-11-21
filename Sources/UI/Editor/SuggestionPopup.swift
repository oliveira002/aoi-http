import AppKit
import SwiftUI

// The autocomplete list, in a borderless child window so the editor's card never clips it.
@MainActor
final class SuggestionPopup {
    final class Model: ObservableObject {
        @Published var items: [BodySuggestion] = []
        @Published var selected = 0
    }

    var onPick: ((BodySuggestion) -> Void)?
    private let model = Model()
    private static let rowHeight: CGFloat = 40
    // The list's padding plus a row's, so a suggestion's text starts right under the caret.
    private static let textInset = Theme.Space.xs + Theme.Space.s
    private static let width: CGFloat = 380

    private lazy var panel: NSPanel = {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = NSHostingView(rootView: SuggestionList(model: model) { [weak self] in self?.onPick?($0) })
        return panel
    }()

    var isVisible: Bool { panel.isVisible }
    var selected: BodySuggestion? { model.items.indices.contains(model.selected) ? model.items[model.selected] : nil }

    func show(_ items: [BodySuggestion], near textView: NSTextView, at location: Int) {
        let keep = selected.flatMap { current in items.firstIndex { $0.id == current.id } }
        model.items = items
        model.selected = keep ?? 0
        let caret = textView.firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil)
        let height = CGFloat(min(items.count, 7)) * Self.rowHeight + 8
        var origin = NSPoint(x: caret.minX - Self.textInset, y: caret.minY - height - 4)
        if let screen = textView.window?.screen?.visibleFrame, origin.y < screen.minY {
            origin.y = caret.maxY + 4
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: Self.width, height: height)), display: true)
        if panel.parent == nil { textView.window?.addChildWindow(panel, ordered: .above) }
        panel.orderFront(nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    func move(_ offset: Int) {
        guard !model.items.isEmpty else { return }
        model.selected = (model.selected + offset + model.items.count) % model.items.count
    }

    private struct SuggestionList: View {
        @ObservedObject var model: Model
        let pick: (BodySuggestion) -> Void

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                            row(item, selected: index == model.selected).id(item.id)
                        }
                    }
                    .padding(Theme.Space.xs)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selected) {
                    guard model.items.indices.contains(model.selected) else { return }
                    proxy.scrollTo(model.items[model.selected].id)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.container))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.container).strokeBorder(Theme.line))
        }

        private func row(_ item: BodySuggestion, selected: Bool) -> some View {
            HStack(alignment: .center, spacing: Theme.Space.s) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: Theme.Space.s) {
                        Text(item.label)
                            .font(.callout.monospaced().weight(.semibold))
                            .foregroundStyle(Theme.JSONColors.key)
                            .lineLimit(1)
                        if item.required {
                            Text("required").font(.caption.weight(.medium)).foregroundStyle(Theme.bad)
                        }
                    }
                    if let description = item.description {
                        Text(description).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: Theme.Space.s)
                Text(item.detail).font(.subheadline.monospaced()).foregroundStyle(Theme.faint).lineLimit(1)
            }
            .padding(.horizontal, Theme.Space.s)
            .frame(height: SuggestionPopup.rowHeight - 4)
            .background(selected ? Theme.accentSoft : .clear, in: .rect(cornerRadius: Theme.Radius.control))
            .padding(.vertical, Theme.Space.xs / 2)
            .contentShape(Rectangle())
            .onTapGesture { pick(item) }
        }
    }
}
