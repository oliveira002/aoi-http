import AppKit
import SwiftUI

// The Dock icon, drawn in code so the bundled .icns and the running app always match.
enum AppIcon {
    struct ExportFailed: Error {}

    static var image: NSImage {
        NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            let tile = NSBezierPath(roundedRect: rect.insetBy(dx: 50, dy: 50), xRadius: 92, yRadius: 92)
            NSGradient(starting: NSColor(Theme.brandLight), ending: NSColor(Theme.brandDark))?.draw(in: tile, angle: -90)
            let config = NSImage.SymbolConfiguration(pointSize: 200, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            if let symbol = NSImage(systemSymbolName: "water.waves", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let size = symbol.size
                symbol.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            }
            return true
        }
    }

    // A 1024px PNG, for bundle.sh to turn into the .icns.
    static func export(to url: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw ExportFailed() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ExportFailed() }
        try png.write(to: url)
    }
}
