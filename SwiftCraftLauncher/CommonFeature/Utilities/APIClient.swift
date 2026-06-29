import Foundation

/// 统一的 API 客户端
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

    private static let sharedDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

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

    /// 执行 GET 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - headers: 可选的请求头
    /// - Returns: 响应数据
    /// - Throws: GlobalError 当请求失败时
    static func get(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.get

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await performRequest(request: request)
    }

    /// 执行 POST 请求
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - body: 请求体数据
    ///   - headers: 可选的请求头（如果包含 Content-Type，将使用提供的值，否则默认为 application/json）
    /// - Returns: 响应数据
    /// - Throws: GlobalError 当请求失败时
    static func post(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.post
        request.httpBody = body

        var needsContentType = false
        if body != nil {
            if let headers = headers {
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

    /// 执行 PUT 请求
    static func put(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        try await requestData(url: url, method: HTTPMethods.put, body: body, headers: headers)
    }

    /// 执行 DELETE 请求
    static func delete(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> Data {
        try await requestData(url: url, method: HTTPMethods.delete, headers: headers)
    }

    /// 执行 GET 请求，不检查状态码，返回 (Data, statusCode)
    /// 用于需要在非200时仍解析响应体的场景
    static func getUnchecked(
        url: URL,
        headers: [String: String]? = nil
    ) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.get
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return try await performRequestUnchecked(request: request)
    }

    /// 执行 POST 请求，不检查状态码，返回 (Data, statusCode)
    /// 用于需要在非200时仍解析响应体的场景
    static func postUnchecked(
        url: URL,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethods.post
        request.httpBody = body

        var needsContentType = false
        if body != nil {
            if let headers = headers {
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

    /// 执行请求并返回解码后的对象
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - body: 请求体数据
    ///   - headers: 可选的请求头
    ///   - decoder: JSON 解码器（可选，默认使用共享解码器）
    /// - Returns: 解码后的对象
    /// - Throws: GlobalError 当请求失败时
    static func request<T: Decodable>(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil,
        decoder: JSONDecoder? = nil
    ) async throws -> T {
        let data = try await requestData(
            url: url,
            method: method,
            body: body,
            headers: headers
        )
        return try (decoder ?? sharedDecoder).decode(T.self, from: data)
    }

    /// 执行请求并返回原始数据
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - body: 请求体数据
    ///   - headers: 可选的请求头
    /// - Returns: 响应数据
    /// - Throws: GlobalError 当请求失败时
    static func requestData(
        url: URL,
        method: String = HTTPMethods.get,
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if body != nil && method == HTTPMethods.post {
            request.setValue(MimeType.json, forHTTPHeaderField: Header.contentType)
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await performRequest(request: request)
    }

    /// 执行请求（内部方法）
    /// - Parameter request: URLRequest
    /// - Returns: 响应数据
    /// - Throws: GlobalError 当请求失败时
    private static func performRequest(request: URLRequest) async throws -> Data {
        let (data, response) = try await sharedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "API 请求失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.network.api_request_failed",
                statusCode: httpResponse.statusCode
            )
        }

        return data
    }

    /// 执行请求（不检查状态码），返回 (Data, statusCode)
    private static func performRequestUnchecked(request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await sharedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response"
            )
        }

        return (data, httpResponse.statusCode)
    }

    /// 执行流式请求并返回字节流与响应
    /// - Parameter request: URLRequest
    /// - Returns: (流式字节, HTTP响应)
    /// - Throws: GlobalError 当响应无效时
    static func performStreamRequest(request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (asyncBytes, response) = try await sharedSession.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        return (asyncBytes, httpResponse)
    }
}
