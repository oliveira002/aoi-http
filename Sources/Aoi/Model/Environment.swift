import Foundation

struct APIEnvironment: Codable, Equatable, Identifiable {
    var id = UUID()
    // Only ever switches the guard on, so a rename cannot silently drop it.
    var name: String { didSet { if Self.looksLikeProduction(name) { isProduction = true } } }
    var variables: [KeyValue] = []
    var isProduction: Bool

    init(name: String, variables: [KeyValue] = []) {
        self.name = name
        self.variables = variables
        isProduction = Self.looksLikeProduction(name)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        variables = try container.decode([KeyValue].self, forKey: .variables)
        isProduction = try container.decodeIfPresent(Bool.self, forKey: .isProduction) ?? Self.looksLikeProduction(name)
    }

    static let baseURLKey = "baseUrl"

    // Where this environment's requests go; requests use it as {{baseUrl}}.
    var baseURL: String {
        get { variables.last { $0.key == Self.baseURLKey }?.value ?? "" }
        set { variables = variables.setting(Self.baseURLKey, to: newValue) }
    }

    // Every variable except the base URL, which has its own field.
    var otherVariables: [KeyValue] {
        get { variables.filter { $0.key != Self.baseURLKey } }
        set { variables = variables.filter { $0.key == Self.baseURLKey } + newValue }
    }

    static func looksLikeProduction(_ name: String) -> Bool {
        name.uppercased().split { !$0.isLetter }.contains { ["PRD", "PROD", "PRODUCTION", "LIVE"].contains($0) }
    }
}

struct SavedEnvironments: Codable {
    var environments: [APIEnvironment]
    var activeEnvironmentID: UUID?
}
