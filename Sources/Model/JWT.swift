import Foundation

enum JWT {
    // The "exp" claim of a JWT, or nil when the value is not a JWT or has no expiry.
    static func expiry(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = claims["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

// How the token in the toolbar stands right now.
enum TokenState: Equatable {
    case missing
    case notJWT
    case expired
    case valid(remaining: TimeInterval)

    init(token: String, now: Date) {
        guard !token.isEmpty else {
            self = .missing
            return
        }
        guard let expiry = JWT.expiry(of: token) else {
            self = .notJWT
            return
        }
        self.init(expiry: expiry, now: now)
    }

    init(expiry: Date, now: Date) {
        let remaining = expiry.timeIntervalSince(now)
        self = remaining > 0 ? .valid(remaining: remaining) : .expired
    }

    var expiresSoon: Bool {
        if case .valid(let remaining) = self { return remaining < 300 }
        return false
    }

    var label: String {
        switch self {
        case .missing: "Set auth"
        case .notJWT: "Auth"
        case .expired: "Auth expired"
        case .valid(let remaining): "Auth · \(Self.short(remaining)) left"
        }
    }

    static func short(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "<1m" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
    }
}
