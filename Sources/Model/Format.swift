import Foundation

enum Format {
    // Foundation calls 200 "no error"; every client and the spec say "OK".
    static func reason(_ statusCode: Int) -> String {
        statusCode == 200 ? "OK" : HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }

    static func count(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        seconds < 1 ? String(format: "%.0f ms", seconds * 1000) : String(format: "%.2f s", seconds)
    }
}
