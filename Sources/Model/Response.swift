import Foundation

struct ResponseHeader: Equatable {
    var name: String
    var value: String
}

struct ResponseResult {
    var id = UUID()
    var receivedAt = Date()
    var statusCode: Int
    var duration: TimeInterval
    var size: Int
    var headers: [ResponseHeader]
    var body: String
    var isJSON: Bool
    var tree: Node?

    init(statusCode: Int, duration: TimeInterval, size: Int, headers: [ResponseHeader], body: String, tree: Node?) {
        self.statusCode = statusCode
        self.duration = duration
        self.size = size
        self.headers = headers
        self.body = body
        self.isJSON = tree != nil
        self.tree = tree
    }
}
