import SwiftUI

struct ResponseSummary: View {
    let response: ResponseResult

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Beacon(color: Theme.status(response.statusCode))
            Text("\(response.statusCode) \(Format.reason(response.statusCode))")
                .font(.headline)
                .foregroundStyle(Theme.status(response.statusCode))
                .lineLimit(1)
            Group {
                Text("·")
                Text(Format.duration(response.duration))
                Text("·")
                Text(ByteCountFormatter.string(fromByteCount: Int64(response.size), countStyle: .file))
            }
            .foregroundStyle(Theme.muted)
        }
        .font(.body)
        .monospacedDigit()
    }
}

struct ResponseHeadersList: View {
    let headers: [ResponseHeader]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Space.l) {
                        Text(header.name)
                            .font(.callout.monospaced().weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 220, alignment: .leading)
                        Text(header.value).font(Theme.mono).textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Theme.Space.s)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.s)
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
                    .padding(Theme.Space.l)
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
