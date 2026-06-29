//
//  HttpRequests.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 6/28/26.
//

import Foundation

enum HttpRequest {

    /// Performs a GET/POST/etc HTTP request for a given URL w/ optional headers
    static func fetchData(url: URL,
                          httpMethod: String,
                          headers: [String: String],
                          urlSession: URLSession) async throws -> Data {
        // Configure request
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod

        for header in headers {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        // Perform the request
        let (data, response) = try await urlSession.data(for: request)

        // Check for a valid HTTP response
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return data
    }
}
