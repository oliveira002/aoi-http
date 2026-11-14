import SwiftUI

// The colour of each JSON token, shared by the response view and the body editor.
enum JSONSyntax {
    // Colouring a bigger body would stall typing and scrolling.
    static let highlightLimit = 300_000

    static func tokens(in text: String) -> [(range: Range<String.Index>, color: Color)] {
        let token = #/("(?:[^"\\]|\\.)*")(\s*:)?|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/#
        return text.matches(of: token).map { match in
            let (whole, string, colon) = (match.output.0, match.output.1, match.output.2)
            let span = string ?? whole
            let color: Color
            if string != nil {
                color = colon == nil ? Theme.JSONColors.string : Theme.JSONColors.key
            } else if whole == "null" {
                color = Theme.JSONColors.null
            } else if whole == "true" || whole == "false" {
                color = Theme.JSONColors.boolean
            } else {
                color = Theme.JSONColors.number
            }
            return (span.startIndex..<span.endIndex, color)
        }
    }
}
