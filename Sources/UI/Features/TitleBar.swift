import SwiftUI

// One band across the top of the window with search centered on it, where the palette opens.
struct TitleBar: View {
    // Clears the window buttons on the left, and the same on the right, so search stays centered on the window.
    static let sideInset: CGFloat = 112

    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if store.detail != .settings {
                    PaletteSearchButton().padding(.horizontal, Self.sideInset)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: proxy.safeAreaInsets.top)
            // Draws the band without taking clicks, so the window still drags by its title bar.
            .background {
                Theme.card
                    .overlay(alignment: .bottom) { Hairline() }
                    .allowsHitTesting(false)
            }
            .offset(y: -proxy.safeAreaInsets.top)
        }
    }
}

extension View {
    // An empty window toolbar: it only makes the title bar taller, with the window buttons centered in it.
    func titleBarHeight() -> some View {
        let spacer = Color.clear.frame(width: 1, height: 1)
        return toolbar {
            if #available(macOS 26, *) {
                ToolbarItem(placement: .navigation) { spacer }.sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigation) { spacer }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
    }
}
