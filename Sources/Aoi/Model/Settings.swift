import Foundation

struct AppSettings: Codable, Equatable {
    enum Guard: String, Codable, CaseIterable {
        case off, writes, all
    }

    enum Appearance: String, Codable, CaseIterable {
        case system, light, dark
    }

    var productionGuard = Guard.all
    var timeout: Double = 60
    var historyLimit = 500
    var jsonExpandLevels = 2
    var appearance = Appearance.system

    static let timeouts: [Double] = [15, 30, 60, 120, 300]
    static let historyLimits = [100, 500, 1000, 5000]
    static let jsonLevels = [0, 1, 2, 3]

    init() {}

    // Missing keys fall back to defaults, so adding a setting never breaks an older settings file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        productionGuard = try container.decodeIfPresent(Guard.self, forKey: .productionGuard) ?? defaults.productionGuard
        timeout = (try container.decodeIfPresent(Double.self, forKey: .timeout) ?? defaults.timeout).nearest(in: Self.timeouts)
        historyLimit = (try container.decodeIfPresent(Int.self, forKey: .historyLimit) ?? defaults.historyLimit).nearest(in: Self.historyLimits)
        jsonExpandLevels = (try container.decodeIfPresent(Int.self, forKey: .jsonExpandLevels) ?? defaults.jsonExpandLevels).nearest(in: Self.jsonLevels)
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? defaults.appearance
    }

    func asksBeforeSending(_ method: HTTPMethod) -> Bool {
        switch productionGuard {
        case .off: false
        case .writes: ![.GET, .HEAD, .OPTIONS].contains(method)
        case .all: true
        }
    }
}

// Snaps a saved value to the closest choice the settings page offers.
extension Numeric where Self: Comparable {
    func nearest(in choices: [Self]) -> Self {
        choices.min { distance($0) < distance($1) } ?? self
    }

    private func distance(_ other: Self) -> Self { self > other ? self - other : other - self }
}
