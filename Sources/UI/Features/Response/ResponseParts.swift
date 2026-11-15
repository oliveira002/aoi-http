import SwiftUI

// Status, time and size, large and side by side.
struct ResponseSummary: View {
    let response: ResponseResult

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            figure("Status") {
                HStack(spacing: 8) {
                    Circle().fill(Theme.status(response.statusCode)).frame(width: 8, height: 8)
                    Text("\(response.statusCode)")
                    Text(Format.reason(response.statusCode))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            divider
            figure("Time") { Text(Format.duration(response.duration)) }
            divider
            figure("Size") { Text(ByteCountFormatter.string(fromByteCount: Int64(response.size), countStyle: .file)) }
        }
    }

    private func figure(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value()
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.trailing, 20)
    }

    private var divider: some View {
        Hairline(axis: .vertical).frame(height: 36).padding(.trailing, 20)
    }
}

struct ResponseHeadersList: View {
    let headers: [ResponseHeader]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(header.name)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 220, alignment: .leading)
                        Text(header.value).font(Theme.mono).textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }
}

// The body as text, with ⌘F find that marks every match and scrolls to the current one.
struct RawBodyView: View {
    let text: String
    let isJSON: Bool
    @State private var query = ""
    @State private var search = TextSearch()
    @State private var scrollRequest = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                CodeText(text: text.isEmpty ? "(empty body)" : text, isJSON: isJSON, highlights: search.matches, current: search.currentMatch)
                    .padding(18)
            }
            // A jump, not an animation: animating across a long body redraws all of it on every frame.
            .onChange(of: scrollRequest) { proxy.scrollTo(CodeText.currentMatchID, anchor: .center) }
        }
        .findBar(query: $query, summary: search.summary, found: !search.matches.isEmpty) { offset in
            search.step(offset)
            scrollRequest += 1
        }
        .onChange(of: query) {
            search = TextSearch(query, in: text)
            scrollRequest += 1
        }
    }
}
