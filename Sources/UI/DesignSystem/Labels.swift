import SwiftUI

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.muted)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Space.s)
            .padding(.vertical, Theme.Space.xs / 2)
            .background(color.opacity(0.13), in: .rect(cornerRadius: Theme.Radius.tag))
    }
}

struct Beacon: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

struct BrandMark: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .fill(LinearGradient(colors: [Theme.brandLight, Theme.brandDark], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "water.waves")
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

struct MethodTag: View {
    let method: HTTPMethod

    var body: some View {
        Text(method == .DELETE ? "DEL" : method == .OPTIONS ? "OPT" : method.rawValue)
            .font(Theme.tagFont)
            .foregroundStyle(Theme.method(method))
            .frame(width: 40, height: 17)
            .background(Theme.method(method).opacity(0.12), in: .rect(cornerRadius: Theme.Radius.tag))
    }
}

struct Chevron: View {
    static let width: CGFloat = 10
    let open: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.faint)
            .rotationEffect(.degrees(open ? 90 : 0))
            .frame(width: Self.width)
    }
}
