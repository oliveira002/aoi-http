import SwiftUI

struct SettingsPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(eyebrow: "Aoi", subtitle: "Changes apply right away.") {
                    Text("Settings")
                } actions: {
                    EmptyView()
                }

                section("Production") {
                    row("Ask before sending", "On environments marked Production. Mark them from the Environments tab.") {
                        Segmented(options: [(.all, "Every request"), (.writes, "Changes only"), (.off, "Never")], selection: $store.settings.productionGuard)
                    }
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
            .frame(maxWidth: 760, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            VStack(spacing: 0, content: content).card()
        }
    }

    private func row(_ title: String, _ detail: String?, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13.5, weight: .medium))
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
