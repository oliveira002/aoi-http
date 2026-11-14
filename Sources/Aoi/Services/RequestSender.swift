import Foundation

// Sends a resolved draft and turns the reply into a ResponseResult.
enum RequestSender {
    static func send(_ draft: RequestDraft, timeout: TimeInterval, using client: any HTTPClient) async throws -> ResponseResult {
        var request = try draft.urlRequest()
        request.timeoutInterval = timeout
        let start = Date()
        let (data, response) = try await client.send(request)
        let duration = Date().timeIntervalSince(start)
        let http = response as? HTTPURLResponse

        let headers = (http?.allHeaderFields ?? [:])
            .map { ResponseHeader(name: "\($0.key)", value: "\($0.value)") }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }

        let text = String(decoding: data, as: UTF8.self)
        let tree = Node.parseJSON(text)
        return ResponseResult(
            statusCode: http?.statusCode ?? 0,
            duration: duration,
            size: data.count,
            headers: headers,
            body: tree?.json ?? text,
            tree: tree
        )
    }
}
