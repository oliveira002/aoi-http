import SwiftUI

// A page in the main window (⌘,), laid out like the other pages.
struct SettingsPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                PageHeader(eyebrow: "Aoi", subtitle: "Changes apply right away.") {
                    Text("Settings")
                } actions: {
                    EmptyView()
                }

                section("Production") {
                    row("Ask before sending to production", "Applies to environments marked with the shield. Mark them from the Environments tab.") {
                        EmptyView()
                    }
                    divider
                    VStack(spacing: Theme.Space.xs) {
                        guardOption(.all, "Every request", "Asks before anything goes out, reads included.", icon: "shield.fill")
                        guardOption(.writes, "Only changes", "Asks before POST, PUT, PATCH and DELETE. Reads send right away.", icon: "shield.lefthalf.filled")
                        guardOption(.off, "Never ask", "Production requests send right away, like any other.", icon: "shield.slash")
                    }
                    .padding(Theme.Space.s)
                }

                section("Requests") {
                    row("Timeout", "How long to wait for a response before giving up.") {
                        Segmented(options: [(15, "15s"), (30, "30s"), (60, "1m"), (120, "2m"), (300, "5m")], selection: $store.settings.timeout)
                    }
                    divider
                    row("History", "Kept while Aoi is open and cleared when you quit. Older requests drop off the end.") {
                        Segmented(options: [(100, "100"), (500, "500"), (1000, "1,000"), (5000, "5,000")], selection: $store.settings.historyLimit)
                    }
                }

                section("Responses") {
                    row("JSON opens at", "Levels of a response tree that start expanded.") {
                        Segmented(options: [(0, "Collapsed"), (1, "1 level"), (2, "2 levels"), (3, "3 levels")], selection: $store.settings.jsonExpandLevels)
                    }
                }

                section("Appearance") {
                    row("Theme", nil) {
                        Segmented(options: [(.system, "System"), (.light, "Light"), (.dark, "Dark")], selection: $store.settings.appearance)
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .onExitCommand { store.detail = .request }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Eyebrow(title)
            VStack(spacing: 0, content: content).card()
        }
    }

    private func guardOption(_ mode: AppSettings.Guard, _ title: String, _ detail: String, icon: String) -> some View {
        let selected = store.settings.productionGuard == mode
        var rule = AppSettings()
        rule.productionGuard = mode
        return Button { store.settings.productionGuard = mode } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.faint)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(mode == .off ? Theme.muted : Theme.bad)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: Theme.Space.s) {
                        Text(title).font(.body.weight(.medium))
                        if mode == AppSettings().productionGuard { Badge(text: "Default", color: Theme.muted) }
                    }
                    Text(detail).font(.callout).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: Theme.Space.m)
                HStack(spacing: Theme.Space.xs) {
                    ForEach([HTTPMethod.GET, .POST, .PUT, .PATCH, .DELETE], id: \.self) { method in
                        MethodTag(method: method).opacity(rule.asksBeforeSending(method) ? 1 : 0.22)
                    }
                }
                .help("Bright methods ask first. Faded ones send right away.")
            }
            .padding(Theme.Space.s)
            .background(selected ? Theme.accentSoft.opacity(0.6) : .clear, in: .rect(cornerRadius: Theme.Radius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ title: String, _ detail: String?, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title).font(.body.weight(.medium))
                if let detail { Text(detail).font(.callout).foregroundStyle(Theme.muted) }
            }
            Spacer(minLength: Theme.Space.m)
            control()
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
    }

    private var divider: some View {
        Hairline().padding(.horizontal, Theme.Space.l)
    }
}
