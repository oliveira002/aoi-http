import AppKit
import SwiftUI

final class LineNumberRuler: NSRulerView {
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 38
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(Theme.raised).setFill()
        bounds.fill()
        NSColor(Theme.line).setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layout = textView.layoutManager,
              let container = textView.textContainer
        else { return }
        let string = textView.string as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: Theme.monoSize, weight: .regular),
            .foregroundColor: NSColor(Theme.faint),
        ]
        let visible = layout.glyphRange(forBoundingRect: textView.visibleRect, in: container)
        let firstChar = layout.characterRange(forGlyphRange: visible, actualGlyphRange: nil).location
        var number = string.substring(to: firstChar).utf16.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
        var index = string.lineRange(for: NSRange(location: firstChar, length: 0)).location

        func label(_ number: Int, atY y: CGFloat) {
            let text = "\(number)" as NSString
            let size = text.size(withAttributes: attributes)
            let point = convert(NSPoint(x: 0, y: y), from: textView)
            text.draw(at: NSPoint(x: ruleThickness - size.width - Theme.Space.s, y: point.y + 1), withAttributes: attributes)
        }

        while index < string.length, index <= NSMaxRange(layout.characterRange(forGlyphRange: visible, actualGlyphRange: nil)) {
            let line = string.lineRange(for: NSRange(location: index, length: 0))
            let fragment = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: line.location), effectiveRange: nil)
            label(number, atY: fragment.minY + textView.textContainerInset.height)
            number += 1
            index = NSMaxRange(line)
        }
        // The empty last line after a trailing newline, or the only line of an empty body.
        if string.length == 0 || string.hasSuffix("\n") {
            let fragment = layout.extraLineFragmentRect
            label(number, atY: fragment.minY + textView.textContainerInset.height)
        }
    }
}
