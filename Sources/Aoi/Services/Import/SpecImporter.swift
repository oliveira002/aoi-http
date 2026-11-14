import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case unsupported
    case syntax(line: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "This file is not an OpenAPI 3, Swagger 2, Postman collection or Postman environment."
        case .syntax(let line, let reason):
            "Could not read the file at line \(line): \(reason)."
        }
    }
}

struct ImportResult {
    var collections: [APICollection] = []
    var environments: [APIEnvironment] = []
}

// A file format Aoi can import. Support another one by adding a type to `SpecImporter.formats`.
protocol ImportFormat {
    static func matches(_ root: Node) -> Bool
    static func read(_ root: Node, fallbackName: String) -> ImportResult
}

enum SpecImporter {
    // Checked in order; the first that matches reads the file.
    static let formats: [any ImportFormat.Type] = [
        OpenAPIImporter.self,
        PostmanImporter.Collection.self,
        PostmanImporter.Environment.self,
        PostmanImporter.DataExport.self,
    ]

    static func importFile(_ url: URL) throws -> ImportResult {
        let text = try String(contentsOf: url, encoding: .utf8)
        return try importText(text, fallbackName: url.deletingPathExtension().lastPathComponent)
    }

    static func importText(_ text: String, fallbackName: String) throws -> ImportResult {
        let root = try YAMLParser.parse(text)
        guard let format = formats.first(where: { $0.matches(root) }) else { throw ImportError.unsupported }
        return format.read(root, fallbackName: fallbackName)
    }
}

extension UTType {
    static let apiSpecs: [UTType] = [.yaml, .json, UTType(filenameExtension: "yml") ?? .yaml, .plainText]
}
