import Foundation

enum HTTPMethod: String, CaseIterable, Codable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS

    // URLSession fails GET and HEAD requests that carry a body.
    var allowsBody: Bool { self != .GET && self != .HEAD }
}

struct KeyValue: Codable, Equatable, Identifiable {
    var id = UUID()
    var enabled = true
    var key = ""
    var value = ""
}

enum BodyMode: String, CaseIterable, Codable {
    case none = "None", json = "Raw JSON", form = "Form"
}

enum AuthMode: String, CaseIterable, Codable {
    case none = "None", bearer = "Bearer Token", basic = "Basic"
}

struct Auth: Codable, Equatable {
    var mode: AuthMode = .none
    var token = ""
    var username = ""
    var password = ""
}

struct RequestDraft: Codable, Equatable {
    var method: HTTPMethod = .GET
    var url: String = ""
    var params: [KeyValue] = []
    var headers: [KeyValue] = []
    var bodyMode: BodyMode = .none
    var rawBody = ""
    var formFields: [KeyValue] = []
    // The path fields write their values into `url`; the template keeps the {{placeholders}} they came from.
    // Optional so requests saved before them still decode.
    var pathValues: [String: String]?
    var pathTemplate: String?
    var auth = Auth()

    // A name for a request that has none yet: the last path segment that is not a {{variable}}.
    var suggestedName: String {
        let segments = url.split(separator: "?").first?.split(separator: "/") ?? []
        return segments.last { !$0.hasPrefix("{{") }.map(String.init) ?? "New request"
    }
}

// The parts of a request the editor shows as tabs.
enum RequestSection: String, CaseIterable {
    case params = "Params", headers = "Headers", body = "Body", auth = "Auth"
}

extension RequestDraft {
    // The tab title, with a count of active rows or the chosen mode.
    func title(for section: RequestSection) -> String {
        switch section {
        case .params: Self.counted(section, params.active.count)
        case .headers: Self.counted(section, headers.active.count)
        case .body: bodyMode == .none ? section.rawValue : "\(section.rawValue) · \(bodyMode.rawValue)"
        case .auth: auth.mode == .none ? section.rawValue : "\(section.rawValue) · \(auth.mode.rawValue)"
        }
    }

    private static func counted(_ section: RequestSection, _ count: Int) -> String {
        count == 0 ? section.rawValue : "\(section.rawValue) \(count)"
    }
}
