import SwiftUI

struct TabStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.xs) {
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
                .accessibilityLabel("New tab")
            Spacer(minLength: 0)
            GlobalsButton()
        }
    }
}

struct TabChip: View {
    @Environment(Store.self) private var store
    let tab: OpenTab
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            MethodTag(method: tab.draft.method)
            // Sized by the medium-weight title, so selecting a tab never changes its width or squeezes the text.
            Text(store.title(of: tab))
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .hidden()
                .overlay(alignment: .leading) {
                    Text(store.title(of: tab))
                        .font(.callout.weight(selected ? .medium : .regular))
                        .foregroundStyle(selected ? Theme.text : Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            trailing.frame(width: 22, height: 22)
        }
        .padding(.leading, Theme.Space.s)
        .padding(.trailing, Theme.Space.xs)
        .frame(height: Theme.controlHeight)
        .frame(maxWidth: 230)
        .background(selected ? Theme.card : hovering ? Theme.raised : .clear, in: .rect(cornerRadius: Theme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control).strokeBorder(selected ? Theme.line : .clear))
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
                Image(systemName: "xmark").font(.caption.weight(.bold)).hitTarget()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.faint)
            .help("Close tab (⌘W)")
            .accessibilityLabel("Close tab")
        } else if tab.isSending {
            ProgressView().controlSize(.mini)
        } else if store.isDirty(tab) {
            Circle().fill(Theme.warn).frame(width: 6, height: 6).help("Unsaved changes")
        }
    }
}
