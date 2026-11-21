import AppKit
import SwiftUI

// Colour tokens, each with a light and a dark value, plus the shared font and status colours.
enum Theme {
    static let bg = dynamic(0xf7f7f5, 0x121211)
    static let card = dynamic(0xffffff, 0x1b1b1a)
    static let raised = dynamic(0xfbfbfa, 0x222220)
    static let text = dynamic(0x1c1c1a, 0xedede9)
    static let muted = dynamic(0x75756f, 0x9b9b95)
    static let faint = dynamic(0x8a8a83, 0x85857f)
    static let line = dynamic(0xebebe6, 0x2a2a28)
    static let warn = dynamic(0xb0611f, 0xe7a46e)
    static let bad = dynamic(0xc0362c, 0xf08a80)
    // The app's green, from the icon; it stays the same whatever accent the user picked in System Settings.
    static let accent = dynamic(0x2f7a55, 0x74c69b)
    static let accentSoft = dynamic(0xe6f2eb, 0x1e3227)
    static let ocean = dynamic(0x2468a8, 0x82b8ec)
    static let purple = dynamic(0x7a4fb5, 0xb79cf0)

    // One palette for JSON everywhere: blue keys, green strings, orange numbers, purple true/false, grey null.
    enum JSONColors {
        static let key = ocean
        static let string = accent
        static let number = warn
        static let boolean = purple
        static let null = faint
    }
    static let monoSize: CGFloat = 12
    static let mono = Font.system(size: monoSize, design: .monospaced)
    // The one custom size: method names in tags only a little wider than the name.
    static let tagFont = Font.system(size: 9, weight: .bold, design: .monospaced)
    // Buttons, fields, segmented controls, tabs and sidebar rows share the macOS large control height.
    static let controlHeight: CGFloat = 28

    // A 4pt grid: every padding and stack spacing in the app is one of these.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let tag: CGFloat = 4
        static let control: CGFloat = 6
        static let container: CGFloat = 10
        // A mark on a single line of code, such as the current find match.
        static let mark: CGFloat = 2
    }
    // Ao: the blue-green of the sea, from teal down to the app's deep green.
    static let brandLight = Color(red: 0.22, green: 0.62, blue: 0.64)
    static let brandDark = Color(red: 0.12, green: 0.40, blue: 0.33)

    static func status(_ code: Int?) -> Color {
        switch code ?? 0 {
        case 200..<300: accent
        case 300..<400: warn
        default: bad
        }
    }

    static func method(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: accent
        case .POST: ocean
        case .PUT, .PATCH: warn
        case .DELETE: bad
        case .HEAD, .OPTIONS: muted
        }
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat(hex >> 16 & 0xff) / 255,
                green: CGFloat(hex >> 8 & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255,
                alpha: 1
            )
        })
    }
}
