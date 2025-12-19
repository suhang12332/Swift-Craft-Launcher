import Foundation

/// 统一的 API 客户端
/// 用于处理所有 API 请求，统一管理内存和错误处理
enum APIClient {
    // 共享的 JSON 解码器，避免重复创建
    private static let sharedDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    // 共享的 URLSession，优化连接复用和内存使用
    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        // 优化：设置合理的缓存策略，减少内存占用
        configuration.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,  // 4MB 内存缓存
            diskCapacity: 20 * 1024 * 1024,   // 20MB 磁盘缓存
            diskPath: nil
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        // 优化：设置超时时间，避免长时间占用资源
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        // 优化：限制并发连接数，减少内存峰值
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()

    // 常量字符串，避免重复创建
    private static let contentTypeHeader = "Content-Type"
    private static let contentTypeJSON = "application/json"
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

        // 优化：直接设置请求头，避免不必要的字典操作
        // 使用 forEach 而不是 for-in，减少临时元组分配
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

        // 优化：先检查是否需要设置 Content-Type，避免不必要的字典复制
        var needsContentType = false
        if body != nil {
            if let headers = headers {
                // 优化：使用不区分大小写的检查，但避免创建临时字符串数组
                // 使用 localizedCaseInsensitiveCompare 可能更高效
                needsContentType = !headers.keys.contains { key in
                    key.localizedCaseInsensitiveCompare(contentTypeHeader) == .orderedSame
                }
            } else {
                needsContentType = true
            }
        }

        // 设置请求头
        // 优化：使用 forEach 减少临时元组分配
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // 如果需要，设置默认 Content-Type
        if needsContentType {
            request.setValue(contentTypeJSON, forHTTPHeaderField: contentTypeHeader)
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
        // 优化：使用共享解码器，避免每次创建新实例
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

        // 优化：使用常量字符串
        if body != nil && method == httpMethodPOST {
            request.setValue(contentTypeJSON, forHTTPHeaderField: contentTypeHeader)
        }

        // 设置请求头
        // 优化：使用 forEach 减少临时元组分配
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return try await performRequest(request: request)
    }

    /// 执行请求（内部方法）
    /// - Parameter request: URLRequest
    /// - Returns: 响应数据
    /// - Throws: GlobalError 当请求失败时
    private static func performRequest(request: URLRequest) async throws -> Data {
        // 优化：使用共享的 URLSession，优化连接复用和内存管理
        let (data, response) = try await sharedSession.data(for: request)

        // 优化：直接检查并提取状态码，减少中间变量
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_response",
                level: .notification
            )
        }

        // 优化：直接检查状态码，避免额外的变量分配
        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "API 请求失败",
                i18nKey: "error.network.api_request_failed",
                level: .notification
            )
        }

        return data
    }

    /// 执行请求并返回响应（用于需要处理非 200 状态码的情况）
    /// - Parameter request: URLRequest
    /// - Returns: (数据, HTTP响应)
    /// - Throws: GlobalError 当请求失败时
    static func performRequestWithResponse(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // 优化：使用共享的 URLSession，优化连接复用和内存管理
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
}
