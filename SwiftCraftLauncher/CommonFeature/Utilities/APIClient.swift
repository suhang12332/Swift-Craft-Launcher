import Foundation

/// 统一的 API 客户端
enum APIClient {
    enum Header {
        static let accept = "Accept"
        static let contentType = "Content-Type"
    }

    enum MimeType {
        static let json = "application/json"
        static let formURLEncoded = "application/x-www-form-urlencoded"
        static let formURLEncodedUTF8 = "application/x-www-form-urlencoded; charset=utf-8"
    }

    enum DefaultHeaders {
        static let acceptJSON: [String: String] = [Header.accept: MimeType.json]
        static let contentTypeJSON: [String: String] = [Header.contentType: MimeType.json]
        static let contentTypeFormURLEncoded: [String: String] = [Header.contentType: MimeType.formURLEncoded]
    }

    private static let sharedDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,  // 4MB 内存缓存
            diskCapacity: 20 * 1024 * 1024,   // 20MB 磁盘缓存
            diskPath: nil
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()

    private static let httpMethodGET = "GET"
    private static let httpMethodPOST = "POST"

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
        request.httpMethod = httpMethodGET

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
        request.httpMethod = httpMethodPOST
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
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        if body != nil && method == httpMethodPOST {
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
                chineseMessage: "API 请求失败",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }

        return data
    }

    /// - Parameter request: URLRequest
    /// - Returns: (数据, HTTP响应)
    /// - Throws: GlobalError 当请求失败时
    static func performRequestWithResponse(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await sharedSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        return (data, httpResponse)
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
