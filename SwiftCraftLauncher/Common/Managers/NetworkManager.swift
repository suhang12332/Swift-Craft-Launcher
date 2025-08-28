import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let proxySettings = ProxySettingsManager.shared
    
    private init() {}
    
    /// 获取配置了代理的URLSession
    var urlSession: URLSession {
        let configuration = URLSessionConfiguration.default
        
        if proxySettings.isProxyEnabled && proxySettings.configuration.isValid {
            let config = proxySettings.configuration
            
            var proxyDict: [String: Any] = [:]
            
            if config.proxyType == .http {
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = true
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = config.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = config.port
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = true
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = config.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = config.port
            } else if config.proxyType == .socks5 {
                proxyDict[kCFNetworkProxiesSOCKSEnable as String] = true
                proxyDict[kCFNetworkProxiesSOCKSProxy as String] = config.host
                proxyDict[kCFNetworkProxiesSOCKSPort as String] = config.port
            }
            
            configuration.connectionProxyDictionary = proxyDict
        }
        
        return URLSession(configuration: configuration)
    }
    
    /// 使用代理设置执行网络请求
    func data(from url: URL) async throws -> (Data, URLResponse) {
        return try await urlSession.data(from: url)
    }
    
    /// 使用代理设置下载文件
    func download(from url: URL) async throws -> (URL, URLResponse) {
        return try await urlSession.download(from: url)
    }
    
    /// 使用代理设置执行请求
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await urlSession.data(for: request)
    }
}