import Foundation
import SwiftUI

public enum ProxyType: String, CaseIterable {
    case http = "http"
    case socks5 = "socks5"
    
    public var localizedName: String {
        switch self {
        case .http:
            return "HTTP"
        case .socks5:
            return "SOCKS5"
        }
    }
}

public struct ProxyConfiguration {
    public var isEnabled: Bool
    public var proxyType: ProxyType
    public var host: String
    public var port: Int
    
    public init(isEnabled: Bool = false, proxyType: ProxyType = .http, host: String = "", port: Int = 8080) {
        self.isEnabled = isEnabled
        self.proxyType = proxyType
        self.host = host
        self.port = port
    }
    
    public var isValid: Bool {
        return !host.isEmpty && port > 0 && port <= 65535
    }
    
    public var urlString: String? {
        guard isValid else { return nil }
        return "\(proxyType.rawValue)://\(host):\(port)"
    }
}

class ProxySettingsManager: ObservableObject {
    static let shared = ProxySettingsManager()
    
    @AppStorage("proxyEnabled") public var isProxyEnabled: Bool = false {
        didSet { 
            objectWillChange.send()
            updateSystemProxy()
        }
    }
    
    @AppStorage("proxyType") private var proxyTypeRawValue: String = ProxyType.http.rawValue {
        didSet { 
            objectWillChange.send()
            updateSystemProxy()
        }
    }
    
    @AppStorage("proxyHost") public var proxyHost: String = "" {
        didSet { 
            objectWillChange.send()
            updateSystemProxy()
        }
    }
    
    @AppStorage("proxyPort") public var proxyPort: Int = 8080 {
        didSet { 
            objectWillChange.send()
            updateSystemProxy()
        }
    }
    
    public var proxyType: ProxyType {
        get { ProxyType(rawValue: proxyTypeRawValue) ?? .http }
        set { 
            proxyTypeRawValue = newValue.rawValue
        }
    }
    
    public var configuration: ProxyConfiguration {
        ProxyConfiguration(
            isEnabled: isProxyEnabled,
            proxyType: proxyType,
            host: proxyHost,
            port: proxyPort
        )
    }
    
    private init() {
        updateSystemProxy()
    }
    
    private func updateSystemProxy() {
        guard isProxyEnabled, configuration.isValid else {
            clearSystemProxy()
            return
        }
        
        setSystemProxy(configuration: configuration)
    }
    
    private func setSystemProxy(configuration: ProxyConfiguration) {
        let proxyDict: [String: Any] = [
            kCFNetworkProxiesHTTPEnable as String: true,
            kCFNetworkProxiesHTTPProxy as String: configuration.host,
            kCFNetworkProxiesHTTPPort as String: configuration.port,
            kCFNetworkProxiesHTTPSEnable as String: true,
            kCFNetworkProxiesHTTPSProxy as String: configuration.host,
            kCFNetworkProxiesHTTPSPort as String: configuration.port
        ]
        
        if configuration.proxyType == .socks5 {
            let socksDict: [String: Any] = [
                kCFNetworkProxiesSOCKSEnable as String: true,
                kCFNetworkProxiesSOCKSProxy as String: configuration.host,
                kCFNetworkProxiesSOCKSPort as String: configuration.port
            ]
            
            let combinedDict = proxyDict.merging(socksDict) { _, new in new }
            URLSessionConfiguration.default.connectionProxyDictionary = combinedDict
        } else {
            URLSessionConfiguration.default.connectionProxyDictionary = proxyDict
        }
        
        Logger.shared.info("代理已设置: \(configuration.proxyType.rawValue)://\(configuration.host):\(configuration.port)")
    }
    
    private func clearSystemProxy() {
        URLSessionConfiguration.default.connectionProxyDictionary = nil
        Logger.shared.info("代理已禁用")
    }
    
    public func testProxyConnection(completion: @escaping (Result<Void, Error>) -> Void) {
        guard configuration.isValid else {
            let error = GlobalError.network(
                chineseMessage: "代理配置无效",
                i18nKey: "settings.proxy.error.invalid_configuration",
                level: .silent
            )
            completion(.failure(error))
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        
        var proxyDict: [String: Any] = [:]
        
        if configuration.proxyType == .socks5 {
            proxyDict = [
                kCFNetworkProxiesSOCKSEnable as String: true,
                kCFNetworkProxiesSOCKSProxy as String: configuration.host,
                kCFNetworkProxiesSOCKSPort as String: configuration.port
            ]
        } else {
            proxyDict = [
                kCFNetworkProxiesHTTPEnable as String: true,
                kCFNetworkProxiesHTTPProxy as String: configuration.host,
                kCFNetworkProxiesHTTPPort as String: configuration.port,
                kCFNetworkProxiesHTTPSEnable as String: true,
                kCFNetworkProxiesHTTPSProxy as String: configuration.host,
                kCFNetworkProxiesHTTPSPort as String: configuration.port
            ]
        }
        
        config.connectionProxyDictionary = proxyDict
        
        let session = URLSession(configuration: config)
        
        // 使用多个测试URL以提高成功率
        let testURLs = [
            "https://bing.com",
        ]
        
        var lastError: Error?
        let group = DispatchGroup()
        var success = false
        
        for urlString in testURLs {
            guard let url = URL(string: urlString), !success else { continue }
            
            group.enter()
            session.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    lastError = error
                    Logger.shared.debug("代理测试失败 (\(urlString)): \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                        success = true
                        Logger.shared.info("代理测试成功: \(urlString)")
                    } else {
                        let connectionError = GlobalError.network(
                            chineseMessage: "连接失败",
                            i18nKey: "settings.proxy.error.connection_failed",
                            level: .silent
                        )
                        lastError = connectionError
                        Logger.shared.debug("代理测试HTTP错误 (\(urlString)): \(httpResponse.statusCode)")
                    }
                }
            }.resume()
            
            // 给每个请求一些时间
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        group.notify(queue: .main) {
            session.invalidateAndCancel()
            if success {
                completion(.success(()))
            } else {
                let finalError = lastError ?? GlobalError.network(
                    chineseMessage: "连接失败",
                    i18nKey: "settings.proxy.error.connection_failed",
                    level: .silent
                )
                completion(.failure(finalError))
            }
        }
    }
}
