import SwiftUI

struct Sidebar: View {
    @Environment(Store.self) private var store
    @State private var search = ""

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandMark(size: 26)
                Text("Aoi").font(.system(size: 16, weight: .semibold)).tracking(-0.3)
                Spacer()
                Button { store.detail = .settings } label: { Image(systemName: "gearshape") }
                    .buttonStyle(IconButtonStyle())
                    .help("Settings (⌘,)")
            }
            TabBar(tabs: SidebarTab.allCases.map { ($0, $0.rawValue) }, selection: $store.sidebarTab, spacing: 16)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Filter \(store.sidebarTab.rawValue.lowercased())", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.faint)
                }
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.raised, in: .rect(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.line))

            switch store.sidebarTab {
            case .collections: CollectionsPanel(search: search)
            case .history: HistoryPanel(search: search)
            case .environments: EnvironmentsPanel(search: search)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }
}

struct SidebarRow<Content: View>: View {
    let selected: Bool
    let indent: Int
    let action: () -> Void
    var onSettings: (() -> Void)?
    let content: Content
    @State private var hovering = false

    init(
        selected: Bool = false,
        indent: Int = 0,
        action: @escaping () -> Void,
        onSettings: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.selected = selected
        self.indent = indent
        self.action = action
        self.onSettings = onSettings
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 7) {
            content
            if let onSettings, hovering {
                Button(action: onSettings) { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.muted)
                    .help("Settings and variables")
            }
        }
        .font(.system(size: 13))
        .padding(.leading, 8 + CGFloat(indent) * 14)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Theme.accentSoft : (hovering ? Theme.raised : .clear), in: .rect(cornerRadius: 8))
        .background(alignment: .leading) {
            // Indent guides line up under the parent row's chevron.
            ForEach(0..<indent, id: \.self) { level in
                Hairline(axis: .vertical).padding(.leading, 13 + CGFloat(level) * 14)
            }
        }
        .contentShape(Rectangle())
        // A tap gesture rather than a Button, so buttons inside the row stay clickable.
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
    }
}
