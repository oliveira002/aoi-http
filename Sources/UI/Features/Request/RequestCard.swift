import SwiftUI


struct RequestCard: View {
    @Environment(Store.self) private var store
    @State private var tab = RequestSection.params
    // What the user dragged to. The card can be shorter when the window is too small for it.
    @State private var height: CGFloat = 280
    @State private var renderedHeight: CGFloat = 280
    @State private var dragStart: CGFloat?
    @State private var hoveringHandle = false

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 0) {
            TabBar(tabs: RequestSection.allCases.map { ($0, store.draft.title(for: $0)) }, selection: $tab)
                .padding(.horizontal, Theme.Space.l)
            Group {
                switch tab {
                case .params:
                    KeyValueEditor(rows: $store.draft.params, noun: "query param", hint: "Added to the URL as ?key=value")
                case .headers:
                    KeyValueEditor(rows: $store.draft.headers, noun: "header", hint: "Override any header set by Body or Auth")
                case .body:
                    BodyEditor(draft: $store.draft, schema: store.activeBodySchema)
                case .auth:
                    AuthEditor(auth: $store.draft.auth)
                }
            }
            .padding(Theme.Space.l)
        }
        .frame(minHeight: 180, maxHeight: height)
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: proxy.size.height, initial: true) { renderedHeight = $1 }
            }
        }
        .card()
        .overlay(alignment: .bottom) { resizeHandle }
    }

    // Drag the bottom edge to give the body more room or the response more room.
    private var resizeHandle: some View {
        Capsule()
            .fill(Theme.faint.opacity(0.5))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity, minHeight: 14)
            .contentShape(Rectangle())
            .offset(y: 10)
            .onHover { hoveringHandle = $0 }
            .onDisappear {
                hoveringHandle = false
                dragStart = nil
            }
            .gesture(
                // Global, because the handle itself moves as the card grows.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStart ?? renderedHeight
                        dragStart = start
                        height = min(max(start + value.translation.height, 180), 640)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .resizeCursor(.resizeUpDown, active: hoveringHandle || dragStart != nil)
            .help("Drag to resize")
    }

}
