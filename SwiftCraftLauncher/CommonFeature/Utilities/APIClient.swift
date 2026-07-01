//
//  APIClient.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides convenience methods for making HTTP requests.
enum APIClient {
    enum Header {
        static let accept = "Accept"
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let xAPIKey = "x-api-key"
        static let contentLength = "Content-Length"
    }

    enum MimeType {
        static let json = "application/json"
        static let formURLEncoded = "application/x-www-form-urlencoded"
        static let formURLEncodedUTF8 = "application/x-www-form-urlencoded; charset=utf-8"
        static let multipart = "multipart/form-data"
    }

    static func bearer(_ token: String) -> String {
        "Bearer \(token)"
    }

    enum DefaultHeaders {
        static let acceptJSON: [String: String] = [Header.accept: MimeType.json]
        static let contentTypeJSON: [String: String] = [Header.contentType: MimeType.json]
        static let contentTypeFormURLEncoded: [String: String] = [Header.contentType: MimeType.formURLEncoded]
        static let contentTypeFormURLEncodedUTF8: [String: String] = [Header.contentType: MimeType.formURLEncodedUTF8]
    }

    static func formURLEncodedBody(from parameters: [String: String]) -> Data {
        guard !parameters.isEmpty else { return Data() }

        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let query = components.percentEncodedQuery else { return Data() }
        return Data(query.utf8)
    }

    private static let sharedDecoder: JSONDecoder = .init()

    private static let sharedSession: URLSession = NetworkSession.makeSession()

    enum HTTPMethods {
        static let get = "GET"
        static let post = "POST"
        static let put = "PUT"
        static let delete = "DELETE"
        static let head = "HEAD"
        static let patch = "PATCH"
        static let options = "OPTIONS"
        static let trace = "TRACE"
        static let connect = "CONNECT"
    }

    /// Performs a GET request.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - headers: Optional additional HTTP headers.
    /// - Returns: The response data.
    /// - Throws: A ``GlobalError`` if the request fails.
    static func get(
        url: URL,
        headers: [String: String]? = nil,
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.get

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await performRequest(request: request)
    }

    /// Performs a POST request.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - body: The request body data.
    ///   - headers: Optional additional HTTP headers. If the headers include a `Content-Type`,
    ///     the provided value is used; otherwise, `application/json` is set as the default.
    /// - Returns: The response data.
    /// - Throws: A ``GlobalError`` if the request fails.
    static func post(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil,
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.post
        request.httpBody = body

        var needsContentType = false
        if body != nil {
            if let headers {
                needsContentType = !headers.keys.contains { key in
                    key.localizedCaseInsensitiveCompare(Header.contentType) == .orderedSame
                }
            } else {
                needsContentType = true
            }
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if needsContentType {
            request.setValue(MimeType.json, forHTTPHeaderField: Header.contentType)
        }

        return try await performRequest(request: request)
    }

    /// Performs a PUT request.
    static func put(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil,
    ) async throws -> Data {
        try await requestData(url: url, method: HTTPMethods.put, body: body, headers: headers)
    }

    /// Performs a DELETE request.
    static func delete(
        url: URL,
        headers: [String: String]? = nil,
    ) async throws -> Data {
        try await requestData(url: url, method: HTTPMethods.delete, headers: headers)
    }

    /// Performs a GET request without checking the status code, returning the data and status code as a tuple.
    /// Use this when the response body needs to be parsed even if the status code is not 200.
    static func getUnchecked(
        url: URL,
        headers: [String: String]? = nil,
    ) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.get
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await performRequestUnchecked(request: request)
    }

    /// Performs a POST request without checking the status code, returning the data and status code as a tuple.
    /// Use this when the response body needs to be parsed even if the status code is not 200.
    static func postUnchecked(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil,
    ) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.post
        request.httpBody = body

        var needsContentType = false
        if body != nil {
            if let headers {
                needsContentType = !headers.keys.contains { key in
                    key.localizedCaseInsensitiveCompare(Header.contentType) == .orderedSame
                }
            } else {
                needsContentType = true
            }
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if needsContentType {
            request.setValue(MimeType.json, forHTTPHeaderField: Header.contentType)
        }

        return try await performRequestUnchecked(request: request)
    }

    /// Performs a request and returns the decoded object.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - method: The HTTP method to use.
    ///   - body: The request body data.
    ///   - headers: Optional additional HTTP headers.
    ///   - decoder: The JSON decoder to use. If `nil`, the shared decoder is used.
    /// - Returns: The decoded object.
    /// - Throws: A ``GlobalError`` if the request fails, or a ``DecodingError`` if decoding fails.
    static func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil,
        decoder: JSONDecoder? = nil,
    ) async throws -> T {
        let data = try await requestData(
            url: url,
            method: method,
            body: body,
            headers: headers,
        )
        return try (decoder ?? sharedDecoder).decode(T.self, from: data)
    }

    /// Performs a request and returns the raw response data.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - method: The HTTP method to use.
    ///   - body: The request body data.
    ///   - headers: Optional additional HTTP headers.
    /// - Returns: The response data.
    /// - Throws: A ``GlobalError`` if the request fails.
    static func requestData(
        url: URL,
        method: String = HTTPMethods.get,
        body: Data? = nil,
        headers: [String: String]? = nil,
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if body != nil, method == HTTPMethods.post {
            request.setValue(MimeType.json, forHTTPHeaderField: Header.contentType)
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await performRequest(request: request)
    }

    /// Executes a URL request and returns the response data.
    private static func performRequest(request: URLRequest) async throws -> Data {
        let (data, response) = try await sharedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_response",
                level: .notification,
                message: "Response is not HTTPURLResponse: \(type(of: response)), URL: \(request.url?.absoluteString ?? "nil")",
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                i18nKey: "error.network.api_request_failed",
                statusCode: httpResponse.statusCode,
                message: "HTTP \(httpResponse.statusCode) for \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "nil")",
            )
        }

        return data
    }

    /// Executes a URL request without status code validation, returning the data and status code.
    private static func performRequestUnchecked(request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await sharedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_response",
                message: "Response is not HTTPURLResponse for unchecked request: \(request.url?.absoluteString ?? "nil")",
            )
        }

        return (data, httpResponse.statusCode)
    }

    /// Executes a streaming request and returns the async bytes and response.
    static func performStreamRequest(request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (asyncBytes, response) = try await sharedSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                i18nKey: "error.network.invalid_response",
                level: .notification,
                message: "Response is not HTTPURLResponse for stream request: \(request.url?.absoluteString ?? "nil")",
            )
        }

        return (asyncBytes, httpResponse)
    }
}
