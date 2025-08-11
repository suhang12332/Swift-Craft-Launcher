import Foundation
import Sparkle
import AppKit

/// Sparkle 更新服务
class SparkleUpdateService: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = SparkleUpdateService()
    
    private var updater: SPUUpdater?
    
    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var currentVersion = ""
    @Published var latestVersion = ""
    @Published var updateDescription = ""
    
    // 配置选项
    private let startupCheckDelay: TimeInterval = 2.0 // 启动后延迟检查时间（秒）
    
    private override init() {
        super.init()
        currentVersion = Bundle.main.appVersion
        setupUpdater()
        // 延迟 2 秒后静默检查更新
        DispatchQueue.main.asyncAfter(deadline: .now() + startupCheckDelay) { [weak self] in
            self?.checkForUpdatesSilently()
        }
    }
    
    /// 设置 Sparkle 更新器
    private func setupUpdater() {
        let hostBundle = Bundle.main
        let driver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        
        do {
            updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: driver, delegate: self)
            
            setSparkleLanguage()
            
            try updater?.start()
            
            // 添加这些配置以确保"稍后提示我"功能正常工作
            updater?.automaticallyChecksForUpdates = true
            updater?.updateCheckInterval = 24 * 60 * 60 // 24小时检查一次
            updater?.sendsSystemProfile = false
            
            
        } catch {
            Logger.shared.error("初始化更新器失败：\(error.localizedDescription)")
        }
    }
    
    /// 设置 Sparkle 的语言
    private func setSparkleLanguage() {
        let selectedLanguage = LanguageManager.shared.selectedLanguage
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
    }
    
    /// 公共方法：设置 Sparkle 的语言
    /// - Parameter language: 语言代码
    public func updateSparkleLanguage(_ language: String) {
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
    }
    
    // MARK: - SPUUpdaterDelegate
    
    /// 提供 feed URL - 根据系统架构选择对应的 appcast 文件
    func feedURLString(for updater: SPUUpdater) -> String? {
        let architecture = getSystemArchitecture()
        let appcastURL = URLConfig.API.GitHub.appcastURL(version: nil, architecture: architecture)
        
        // 拼接git代理地址
        let proxy = GameSettingsManager.shared.gitProxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !proxy.isEmpty && appcastURL.absoluteString.hasPrefix("https://github.com/") {
            return proxy + "/" + appcastURL.absoluteString
        }
        
        return appcastURL.absoluteString
    }
    
    /// 获取系统架构
    private func getSystemArchitecture() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
    
    // MARK: - Public Methods
    
    /// 获取当前系统架构
    func getCurrentArchitecture() -> String {
        return getSystemArchitecture()
    }
    
    /// 手动检查更新（显示Sparkle标准UI）
    func checkForUpdatesWithUI() {
        guard let updater = updater else {
            Logger.shared.error("更新器尚未初始化")
            return
        }
        
        updater.checkForUpdates()
    }
    
    /// 静默检查更新（无 UI）
    func checkForUpdatesSilently() {
        guard let updater = updater else {
            Logger.shared.error("更新器尚未初始化")
            return
        }
        updater.checkForUpdatesInBackground()
    }
}

// 拦截下载请求，按需为 GitHub 资源地址加上代理前缀
extension SparkleUpdateService {
    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        let proxy = GameSettingsManager.shared.gitProxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proxy.isEmpty else { return }
        guard let originalURL = request.url else { return }

        let original = originalURL.absoluteString

        // 仅对 GitHub 相关域名做代理
        let isGitHubAsset = original.hasPrefix("https://github.com/")
        guard isGitHubAsset else { return }

        // 避免重复加前缀
        if original.hasPrefix(proxy + "/") { return }

        let proxiedString = proxy.hasSuffix("/") ? proxy + original : proxy + "/" + original
        if let proxiedURL = URL(string: proxiedString) {
            Logger.shared.info("更新下载链接已重写：\(original) -> \(proxiedString)")
            request.url = proxiedURL
        }
    }
}
