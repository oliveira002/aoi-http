import Foundation

// How a resolved draft goes on the wire.
extension RequestDraft {
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(string: url), components.scheme != nil else {
            throw URLError(.badURL)
        }
        // Append encoded pairs instead of reassigning queryItems, which would re-encode the existing query.
        let query = params.active.formEncoded
        if !query.isEmpty {
            components.percentEncodedQuery = [components.percentEncodedQuery, query]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "&")
        }
        guard let resolvedURL = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = method.rawValue

        switch method.allowsBody ? bodyMode : .none {
        case .none:
            break
        case .json:
            request.httpBody = Data(rawBody.utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form:
            request.httpBody = Data(formFields.active.formEncoded.utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        switch auth.mode {
        case .none:
            break
        case .bearer:
            request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        case .basic:
            let credentials = Data("\(auth.username):\(auth.password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }

        // Explicit headers win over the ones implied by body and auth.
        for header in headers.active {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }
        return request
    }
}
