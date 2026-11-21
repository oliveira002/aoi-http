import SwiftUI

struct Sidebar: View {
    static let defaultWidth: CGFloat = 300
    static let widths: ClosedRange<CGFloat> = 270...400
    // Collapsed, the sidebar keeps a strip this wide for its icons.
    static let railWidth: CGFloat = 52
    static let brandSize: CGFloat = 26

    // The open width, kept while collapsing so the content fades out instead of re-wrapping as it narrows.
    let width: CGFloat
    @Environment(Store.self) private var store
    @State private var search = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if store.sidebarCollapsed {
                rail.frame(width: Self.railWidth).transition(.opacity)
            } else {
                full.frame(width: width).transition(.opacity)
            }
        }
        // Same as the main panel, so the brand row and the request tabs share a line.
        .padding(.top, Theme.Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.card)
    }

    private var rail: some View {
        VStack(spacing: Theme.Space.l) {
            BrandMark(size: Self.brandSize)
            SidebarToggle()
            Hairline().frame(width: Theme.Space.l)
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                SidebarIconButton(icon: tab.icon, label: tab.rawValue, highlighted: store.sidebarTab == tab) {
                    store.sidebarTab = tab
                    store.sidebarCollapsed = false
                }
            }
            Spacer()
            SettingsButton()
        }
        .padding(.bottom, Theme.Space.xl)
    }

    private var full: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                BrandMark(size: Self.brandSize)
                Text("Aoi").font(.title3.weight(.semibold)).tracking(-0.3)
                Spacer()
                SettingsButton()
                SidebarToggle()
            }
            TabBar(tabs: SidebarTab.allCases.map { ($0, $0.rawValue) }, selection: $store.sidebarTab, spacing: Theme.Space.l)

            HStack(spacing: Theme.Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                TextField("Filter \(store.sidebarTab.rawValue.lowercased())", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").hitTarget() }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.faint)
                }
            }
            .font(.callout)
            .padding(.horizontal, Theme.Space.s)
            .frame(height: Theme.controlHeight)
            .background(Theme.raised, in: .rect(cornerRadius: Theme.Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(Theme.line))

            switch store.sidebarTab {
            case .collections: CollectionsPanel(search: search)
            case .history: HistoryPanel(search: search)
            case .environments: EnvironmentsPanel(search: search)
            }
        }
        .padding(.horizontal, Theme.Space.m)
    }
}

extension SidebarTab {
    var icon: String {
        switch self {
        case .collections: "square.stack.3d.up"
        case .history: "clock"
        case .environments: "globe"
        }
    }
}

// A muted glyph whose click area is as wide as the glyph, so it lines up with the sidebar's edges.
struct SidebarIconButton: View {
    let icon: String
    let label: String
    var help: String?
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: icon).edgeTarget() }
            .buttonStyle(.plain)
            .foregroundStyle(highlighted ? Theme.accent : Theme.muted)
            .help(help ?? label)
            .accessibilityLabel(label)
    }
}

struct SettingsButton: View {
    @Environment(Store.self) private var store

    var body: some View {
        SidebarIconButton(icon: "gearshape", label: "Settings", help: "Settings (⌘,)") {
            store.detail = store.detail == .settings ? .request : .settings
        }
    }
}

// The line between the sidebar and the main panel; drag it to resize the sidebar while it is open.
struct SidebarDivider: View {
    @Binding var width: CGFloat
    let resizable: Bool
    @State private var dragStart: CGFloat?
    @State private var hovering = false

    var body: some View {
        Hairline(axis: .vertical)
            .overlay {
                if resizable {
                    Color.clear
                        .frame(width: Theme.Space.s)
                        .contentShape(Rectangle())
                        .onHover { hovering = $0 }
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                .onChanged { value in
                                    let start = dragStart ?? width
                                    dragStart = start
                                    width = min(max(start + value.translation.width, Sidebar.widths.lowerBound), Sidebar.widths.upperBound)
                                }
                                .onEnded { _ in dragStart = nil }
                        )
                }
            }
            // On the line itself, which stays while the drag area comes and goes with collapsing.
            .resizeCursor(.resizeLeftRight, active: resizable && (hovering || dragStart != nil))
    }
}

// Narrows the sidebar to its strip of icons, or opens it again.
struct SidebarToggle: View {
    @Environment(Store.self) private var store

    var body: some View {
        let label = store.sidebarCollapsed ? "Show sidebar" : "Hide sidebar"
        SidebarIconButton(icon: "sidebar.left", label: label, help: "\(label) (⌃⌘S)") {
            store.sidebarCollapsed.toggle()
        }
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
        HStack(spacing: Theme.Space.s) {
            content
        }
        .font(.body)
        .padding(.leading, SidebarIndent.leading(indent))
        .padding(.trailing, Theme.Space.s)
        // Shown on hover over the row's trailing detail, so rows with and without it line up.
        .overlay(alignment: .trailing) {
            if let onSettings, hovering {
                Button(action: onSettings) { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.muted)
                    .help("Settings and variables")
                    .padding(.horizontal, Theme.Space.s)
                    .frame(maxHeight: .infinity)
                    .background(
                        selected ? Theme.accentSoft : Theme.raised,
                        in: UnevenRoundedRectangle(bottomTrailingRadius: Theme.Radius.control, topTrailingRadius: Theme.Radius.control)
                    )
            }
        }
        .padding(.vertical, Theme.Space.xs)
        .frame(maxWidth: .infinity, minHeight: Theme.controlHeight, alignment: .leading)
        .background(selected ? Theme.accentSoft : (hovering ? Theme.raised : .clear), in: .rect(cornerRadius: Theme.Radius.control))
        .background {
            // Indent guides line up under each ancestor row's chevron.
            ZStack(alignment: .topLeading) {
                ForEach(0..<indent, id: \.self) { level in
                    Hairline(axis: .vertical).offset(x: SidebarIndent.leading(level) + Chevron.width / 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        // A tap gesture rather than a Button, so buttons inside the row stay clickable.
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
    }

}

enum SidebarIndent {
    // Where a row's content starts at a given depth in the tree.
    static func leading(_ indent: Int) -> CGFloat {
        Theme.Space.s + CGFloat(indent) * Theme.Space.l
    }
}
