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
                    Text(HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized)
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
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.muted)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }
}
