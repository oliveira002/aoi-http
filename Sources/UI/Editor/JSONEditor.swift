import AppKit
import SwiftUI

// A plain-text code editor for JSON bodies: line numbers, highlighting, auto-indent, no smart quotes.
struct JSONEditor: NSViewRepresentable {
    @Binding var text: String
    var schema: BodySchema?

    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    static let variableFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold)

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Self.font
        textView.textColor = NSColor(Theme.text)
        textView.insertionPointColor = NSColor(Theme.text)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 6, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.string = text
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let ruler = LineNumberRuler(textView: textView)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observeScrolling(of: scroll, ruler: ruler)
        Self.highlight(textView)
        return scroll
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        coordinator.popup.hide()
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.schema = schema
        guard let textView = scroll.documentView as? NSTextView, textView.string != text else { return }
        // Changed from outside, for example by Format or by switching tabs. Undo must not reach across requests.
        textView.undoManager?.removeAllActions()
        context.coordinator.popup.hide()
        textView.string = text
        Self.highlight(textView)
        scroll.verticalRulerView?.needsDisplay = true
    }

    static func highlight(_ textView: NSTextView) {
        // Restyling during IME composition would wipe its marked text.
        guard let storage = textView.textStorage, !textView.hasMarkedText() else { return }
        let text = storage.string
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(Theme.text)]
        storage.beginEditing()
        storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
        if text.utf8.count < JSONSyntax.highlightLimit {
            for token in JSONSyntax.tokens(in: text) {
                storage.addAttribute(.foregroundColor, value: NSColor(token.color), range: NSRange(token.range, in: text))
            }
            for match in text.matches(of: Variables.pattern) {
                let range = NSRange(match.range, in: text)
                storage.addAttributes([.foregroundColor: NSColor(Theme.purple), .font: variableFont], range: range)
            }
        }
        storage.endEditing()
        textView.typingAttributes = base
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var schema: BodySchema?
        let popup = SuggestionPopup()
        private var context: JSONContext?
        private var observer: NSObjectProtocol?

        init(text: Binding<String>) { self.text = text }

        deinit { observer.map(NotificationCenter.default.removeObserver) }

        func observeScrolling(of scroll: NSScrollView, ruler: NSRulerView) {
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main
            ) { [weak self] _ in
                ruler.needsDisplay = true
                MainActor.assumeIsolated { self?.popup.hide() }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            JSONEditor.highlight(textView)
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            updateSuggestions(in: textView, manual: false)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard popup.isVisible, let textView = notification.object as? NSTextView else { return }
            updateSuggestions(in: textView, manual: true)
        }

        func textDidEndEditing(_ notification: Notification) {
            popup.hide()
        }

        // Opens on its own once a key or an enum value is being typed; Esc asks for it anywhere.
        private func updateSuggestions(in textView: NSTextView, manual: Bool) {
            let selection = textView.selectedRange()
            guard let schema, !textView.hasMarkedText(), selection.length == 0,
                  let context = JSONContext.at(selection.location, in: textView.string)
            else { return popup.hide() }
            let items = schema.suggestions(for: context)
            guard manual || context.quoted || !context.partial.isEmpty, !items.isEmpty else { return popup.hide() }
            self.context = context
            popup.onPick = { [weak self, weak textView] item in
                guard let textView else { return }
                self?.accept(item, in: textView)
            }
            popup.show(items, near: textView, at: context.replace.location)
        }

        private func accept(_ item: BodySuggestion, in textView: NSTextView) {
            guard let context else { return }
            popup.hide()
            textView.insertText(item.insertion, replacementRange: context.replace)
            textView.setSelectedRange(NSRange(location: context.replace.location + item.cursorOffset, length: 0))
            // Straight on to the new object's fields or the enum's values; nothing shows when there are none.
            updateSuggestions(in: textView, manual: true)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if popup.isVisible {
                switch selector {
                case #selector(NSResponder.moveUp(_:)):
                    popup.move(-1)
                    return true
                case #selector(NSResponder.moveDown(_:)):
                    popup.move(1)
                    return true
                case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
                    guard let item = popup.selected else {
                        popup.hide()
                        break
                    }
                    accept(item, in: textView)
                    return true
                case #selector(NSResponder.cancelOperation(_:)):
                    popup.hide()
                    return true
                default:
                    break
                }
            }
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)), #selector(NSResponder.complete(_:)):
                guard schema != nil else {
                    // No fields to offer: let Esc travel on instead of opening word completion.
                    textView.nextResponder?.tryToPerform(selector, with: nil)
                    return true
                }
                updateSuggestions(in: textView, manual: true)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                apply(JSONIndent.newline(in: textView.string, replacing: textView.selectedRange()), to: textView)
                return true
            case #selector(NSResponder.insertTab(_:)):
                textView.insertText(JSONIndent.unit, replacementRange: textView.selectedRange())
                return true
            default:
                return false
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
            guard range.length == 0, let text, let edit = JSONIndent.closingBracket(text, in: textView.string, at: range.location) else { return true }
            apply(edit, to: textView)
            return false
        }

        private func apply(_ edit: JSONIndent.Edit, to textView: NSTextView) {
            textView.insertText(edit.text, replacementRange: edit.range)
            textView.setSelectedRange(NSRange(location: edit.cursor, length: 0))
        }
    }
}
