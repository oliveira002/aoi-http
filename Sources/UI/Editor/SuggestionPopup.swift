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
        var origin = NSPoint(x: caret.minX - 10, y: caret.minY - height - 4)
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
                    .padding(4)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selected) {
                    guard model.items.indices.contains(model.selected) else { return }
                    proxy.scrollTo(model.items[model.selected].id)
                }
            }
            .background(Theme.card, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
        }

        private func row(_ item: BodySuggestion, selected: Bool) -> some View {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.JSONColors.key)
                            .lineLimit(1)
                        if item.required {
                            Text("required").font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.bad)
                        }
                    }
                    if let description = item.description {
                        Text(description).font(.system(size: 11)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(item.detail).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.faint).lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: SuggestionPopup.rowHeight - 4)
            .background(selected ? Theme.accentSoft : .clear, in: .rect(cornerRadius: 7))
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { pick(item) }
        }
    }
}
