import SwiftUI

// The standard Settings window (⌘,). Changes apply right away, as on any Mac.
struct SettingsPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 22) {
            section("Production") {
                row("Ask before sending to production", "Applies to environments marked with the shield. Mark them from the Environments tab.") {
                    EmptyView()
                }
                divider
                VStack(spacing: 2) {
                    guardOption(.all, "Every request", "Asks before anything goes out, reads included.", icon: "shield.fill")
                    guardOption(.writes, "Only changes", "Asks before POST, PUT, PATCH and DELETE. Reads send right away.", icon: "shield.lefthalf.filled")
                    guardOption(.off, "Never ask", "Production requests send right away, like any other.", icon: "shield.slash")
                }
                .padding(8)
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
        .padding(24)
        .frame(width: 680)
        .background(Theme.bg)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            VStack(spacing: 0, content: content).card()
        }
    }

    private func guardOption(_ mode: AppSettings.Guard, _ title: String, _ detail: String, icon: String) -> some View {
        let selected = store.settings.productionGuard == mode
        var rule = AppSettings()
        rule.productionGuard = mode
        return Button { store.settings.productionGuard = mode } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? Theme.accent : Theme.faint)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(mode == .off ? Theme.muted : Theme.bad)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.system(size: 13, weight: .medium))
                        if mode == AppSettings().productionGuard { Pill(text: "Default", color: Theme.muted) }
                    }
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    ForEach([HTTPMethod.GET, .POST, .PUT, .PATCH, .DELETE], id: \.self) { method in
                        MethodTag(method: method).opacity(rule.asksBeforeSending(method) ? 1 : 0.22)
                    }
                }
                .help("Bright methods ask first. Faded ones send right away.")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(selected ? Theme.accentSoft.opacity(0.6) : .clear, in: .rect(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ title: String, _ detail: String?, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let detail { Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Hairline().padding(.horizontal, 18)
    }
}
