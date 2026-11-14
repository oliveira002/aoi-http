import SwiftUI

struct TabStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(store.tabs) { tab in
                        TabChip(tab: tab, selected: tab.id == store.activeTabID && store.detail == .request)
                    }
                }
            }
            .scrollIndicators(.never)
            .fixedSize(horizontal: false, vertical: true)
            Button(action: store.newRequest) { Image(systemName: "plus") }
                .buttonStyle(IconButtonStyle())
                .help("New tab (⌘T)")
            Spacer(minLength: 0)
        }
    }
}

struct TabChip: View {
    @Environment(Store.self) private var store
    let tab: OpenTab
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            MethodTag(method: tab.draft.method)
            Text(store.title(of: tab))
                .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Theme.text : Theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
            trailing.frame(width: 16, height: 16)
        }
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .frame(maxWidth: 230)
        .background(selected ? Theme.card : hovering ? Theme.raised : .clear, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Theme.line : .clear))
        .contentShape(Rectangle())
        .onTapGesture { store.selectTab(tab.id) }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Close Tab") { store.closeTab(tab.id) }
            Button("Close Other Tabs") { store.closeOtherTabs(tab.id) }
                .disabled(store.tabs.count < 2)
            Button("Close Tabs to the Right") { store.closeTabsToRight(tab.id) }
                .disabled(store.tabs.last?.id == tab.id)
            Divider()
            Button("Close All Tabs") { store.closeAllTabs() }
        }
        .help(tab.draft.url)
    }

    // Close on hover, otherwise what the tab is doing: sending, unsaved, or nothing.
    @ViewBuilder private var trailing: some View {
        if hovering || (selected && !tab.isSending && !store.isDirty(tab)) {
            Button { store.closeTab(tab.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.faint)
            .help("Close tab (⌘W)")
        } else if tab.isSending {
            ProgressView().controlSize(.mini)
        } else if store.isDirty(tab) {
            Circle().fill(Theme.warn).frame(width: 6, height: 6).help("Unsaved changes")
        }
    }
}
