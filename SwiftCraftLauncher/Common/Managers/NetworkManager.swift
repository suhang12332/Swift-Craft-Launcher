import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private let proxySettings = ProxySettingsManager.shared
    private var cachedSession: URLSession?
    private var lastProxyConfiguration: ProxyConfiguration?
    
    private init() {
        setupProxyChangeObserver()
    }
    
    deinit {
        cachedSession?.invalidateAndCancel()
    }
    
    /// 设置代理配置变化监听
    private func setupProxyChangeObserver() {
        // 监听代理设置变化
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ProxyConfigurationChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateSession()
        }
    }
    
    /// 清理缓存的session
    private func invalidateSession() {
        cachedSession?.invalidateAndCancel()
        cachedSession = nil
        lastProxyConfiguration = nil
    }
    
    /// 获取配置了代理的URLSession
    var urlSession: URLSession {
        let currentConfig = proxySettings.configuration
        
        // 检查是否需要重新创建session
        if let cached = cachedSession, 
           let lastConfig = lastProxyConfiguration,
           lastConfig.isEnabled == currentConfig.isEnabled &&
           lastConfig.proxyType == currentConfig.proxyType &&
           lastConfig.host == currentConfig.host &&
           lastConfig.port == currentConfig.port &&
           lastConfig.username == currentConfig.username &&
           lastConfig.password == currentConfig.password {
            return cached
        }
        
        // 清理旧session
        invalidateSession()
        
        // 创建新的configuration
        let configuration = URLSessionConfiguration.default.copy() as! URLSessionConfiguration
        
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
                
                // HTTP 认证
                if config.hasAuthentication {
                    proxyDict["HTTPProxyUsername"] = config.username
                    proxyDict["HTTPProxyPassword"] = config.password
                    proxyDict["HTTPSProxyUsername"] = config.username
                    proxyDict["HTTPSProxyPassword"] = config.password
                }
            } else if config.proxyType == .socks5 {
                proxyDict[kCFNetworkProxiesSOCKSEnable as String] = true
                proxyDict[kCFNetworkProxiesSOCKSProxy as String] = config.host
                proxyDict[kCFNetworkProxiesSOCKSPort as String] = config.port
                
                // SOCKS5 认证
                if config.hasAuthentication {
                    proxyDict["SOCKSUsername"] = config.username
                    proxyDict["SOCKSPassword"] = config.password
                }
            }
            
            configuration.connectionProxyDictionary = proxyDict
        }
        
        // 创建并缓存session
        let session = URLSession(configuration: configuration)
        cachedSession = session
        lastProxyConfiguration = currentConfig
        
        return session
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