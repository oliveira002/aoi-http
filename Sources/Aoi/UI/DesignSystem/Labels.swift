import SwiftUI

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(Theme.faint)
    }
}

struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .background(color.opacity(0.13), in: Capsule())
    }
}

struct Beacon: View {
    let color: Color
    var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .background {
                if pulsing {
                    Circle()
                        .fill(color.opacity(0.45))
                        .phaseAnimator([false, true]) { circle, expanded in
                            circle.scaleEffect(expanded ? 2.8 : 1).opacity(expanded ? 0 : 1)
                        } animation: { expanded in
                            expanded ? .easeOut(duration: 1.6) : nil
                        }
                }
            }
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
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.method(method))
            .frame(width: 40, height: 17)
            .background(Theme.method(method).opacity(0.12), in: .rect(cornerRadius: 5))
    }
}

struct Chevron: View {
    let open: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.faint)
            .rotationEffect(.degrees(open ? 90 : 0))
            .frame(width: 10)
    }
}
