import Foundation

// JSON files in one folder. Each file is typed, so a value can only be saved to and loaded from its own file.
struct Persistence: Sendable {
    struct File<Value: Codable> {
        let name: String
    }

    let directory: URL

    static let live = Persistence(directory: URL.applicationSupportDirectory.appending(path: "Aoi", directoryHint: .isDirectory))

    func load<Value>(_ file: File<Value>) -> Value? {
        let url = directory.appending(path: file.name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            // Move the unreadable file aside so the next save cannot overwrite it.
            let backup = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            print("Could not read \(url.path), moved it to \(backup.path): \(error)")
            return nil
        }
    }

    func save<Value>(_ value: Value, to file: File<Value>) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.encoder.encode(value).write(to: directory.appending(path: file.name), options: .atomic)
        } catch {
            print("Could not save \(file.name): \(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Persistence.File where Value == [APICollection] {
    static var collections: Self { Self(name: "collections.json") }
}

extension Persistence.File where Value == SavedEnvironments {
    static var environments: Self { Self(name: "environments.json") }
}

extension Persistence.File where Value == [KeyValue] {
    static var globals: Self { Self(name: "globals.json") }
}

extension Persistence.File where Value == AppSettings {
    static var settings: Self { Self(name: "settings.json") }
}
