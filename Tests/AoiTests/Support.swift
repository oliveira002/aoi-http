import Foundation
@testable import Aoi

// Never touches the network: it records each request and answers with a canned reply.
final class StubClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    let status: Int
    let body: String

    init(status: Int = 200, body: String = #"{"ok": true}"#) {
        self.status = status
        self.body = body
    }

    var requests: [URLRequest] { lock.withLock { recorded } }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        lock.withLock { recorded.append(request) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        return (Data(body.utf8), response)
    }
}

extension Persistence {
    // A fresh folder per test, so tests never read or write the real app data.
    static func temporary() -> Persistence {
        Persistence(directory: FileManager.default.temporaryDirectory.appending(path: "AoiTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    }
}

@MainActor
func makeStore(client: StubClient = StubClient()) -> Store {
    Store(persistence: .temporary(), client: client)
}

func request(_ name: String, url: String, method: HTTPMethod = .GET) -> SavedRequest {
    var draft = RequestDraft()
    draft.url = url
    draft.method = method
    return SavedRequest(name: name, draft: draft)
}

// Splits "text with | cursor" into the text and the cursor's UTF-16 offset.
func cursor(_ marked: String) -> (text: String, offset: Int) {
    let range = (marked as NSString).range(of: "|")
    return ((marked as NSString).replacingCharacters(in: range, with: ""), range.location)
}

func context(_ marked: String) -> JSONContext? {
    let (text, offset) = cursor(marked)
    return JSONContext.at(offset, in: text)
}

struct NoContext: Error {}

func requiredContext(_ marked: String) throws -> JSONContext {
    guard let found = context(marked) else { throw NoContext() }
    return found
}
