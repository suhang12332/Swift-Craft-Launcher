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
    private var shouldCheckOnStartup: Bool {
        // 默认启用，但用户可以通过设置关闭
        return UserDefaults.standard.object(forKey: "SwiftCraftLauncher.StartupUpdateCheck") as? Bool ?? true
    }
    private let startupCheckDelay: TimeInterval = 1.0 // 启动后延迟检查时间（秒）
    
    // GitHub API 配置 - 已移动到 URLConfig
    
    private override init() {
        super.init()
        currentVersion = Bundle.main.appVersion
        setupUpdater()
    }
    
    /// 设置 Sparkle 更新器
    private func setupUpdater() {
        let hostBundle = Bundle.main
        let driver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)
        
        do {
            updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: hostBundle, userDriver: driver, delegate: self)
            
            setSparkleLanguage()

            
            try updater?.start()
            
            Logger.shared.info("update.updater.initialization.success".localized())
            Logger.shared.info(String(format: "update.system.architecture".localized() + ": %@", getSystemArchitecture()))
            
            // 应用启动后延迟检查更新
            if shouldCheckOnStartup {
                DispatchQueue.main.asyncAfter(deadline: .now() + startupCheckDelay) { [weak self] in
                    self?.checkForUpdatesOnStartup()
                }
            }
        } catch {
            Logger.shared.error(String(format: "update.updater.initialization.failed".localized() + ": %@", error.localizedDescription))
        }
    }
    
    /// 设置 Sparkle 的语言
    private func setSparkleLanguage() {
        let selectedLanguage = LanguageManager.shared.selectedLanguage
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
        Logger.shared.info(String(format: "update.sparkle.language.set".localized() + ": %@", selectedLanguage))
    }
    
    /// 公共方法：设置 Sparkle 的语言
    /// - Parameter language: 语言代码
    public func updateSparkleLanguage(_ language: String) {
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        Logger.shared.info(String(format: "update.sparkle.language.updated".localized() + ": %@", language))
    }
    
    // MARK: - SPUUpdaterDelegate
    
    /// 提供 feed URL - 根据系统架构选择对应的 appcast 文件
    func feedURLString(for updater: SPUUpdater) -> String? {
        let architecture = getSystemArchitecture()
        let appcastURL = URLConfig.API.GitHub.appcastURL(version: latestVersion.isEmpty ? nil : latestVersion, architecture: architecture)
        
        Logger.shared.info(String(format: "update.appcast.file".localized() + ": appcast-\(architecture).xml"))
        Logger.shared.info(String(format: "update.appcast.url".localized() + ": %@", appcastURL.absoluteString))
        
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
    
    /// 检查更新
    func checkForUpdates() {
        guard updater != nil else {
            Logger.shared.error("update.updater.not.initialized".localized())
            return
        }
        
        isCheckingForUpdates = true
        fetchLatestReleaseInfo()
    }
    
    /// 应用启动时自动检查更新
    private func checkForUpdatesOnStartup() {
        Logger.shared.info("update.startup.check.start".localized())
        
        // 使用静默检查，不显示用户界面
        fetchLatestReleaseInfo()
    }
    
    /// 通过 GitHub API 获取最新 release 信息
    private func fetchLatestReleaseInfo() {
        let url = URLConfig.API.GitHub.latestRelease()
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isCheckingForUpdates = false
                
                if let error = error {
                    Logger.shared.error(String(format: "update.github.api.failed".localized() + ": %@", error.localizedDescription))
                    return
                }
                
                guard let data = data else {
                    Logger.shared.error("update.no.data".localized())
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self?.handleGitHubRelease(release)
                } catch {
                    Logger.shared.error(String(format: "update.github.release.parse.failed".localized() + ": %@", error.localizedDescription))
                }
            }
        }.resume()
    }
    
    /// 处理 GitHub Release 信息并触发更新检查
    private func handleGitHubRelease(_ release: GitHubRelease) {
        latestVersion = release.tagName
        updateDescription = release.body ?? "update.available".localized()
        updateAvailable = true
        
        Logger.shared.info(String(format: "update.latest.version.info".localized() + ": %@", release.tagName))
        
        // 直接触发 Sparkle 更新检查，无需单独方法
        guard let updater = updater else { 
            Logger.shared.error("update.updater.not.initialized".localized() + "update.trigger.check.failed.detail".localized())
            return 
        }
        
        Logger.shared.info(String(format: "update.check.architecture".localized(), getSystemArchitecture()))
        
        DispatchQueue.main.async {
            do {
                try updater.start()
                updater.checkForUpdates()
                Logger.shared.info("update.trigger.check.success".localized())
            } catch {
                Logger.shared.error(String(format: "update.trigger.check.failed".localized() + ": %@", error.localizedDescription))
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取当前系统架构
    func getCurrentArchitecture() -> String {
        return getSystemArchitecture()
    }
    
    /// 获取更新器状态
    func getUpdaterStatus() -> String {
        return updater != nil ? "update.updater.status.initialized".localized() : "update.updater.status.not.initialized".localized()
    }
    
    /// 手动检查更新（显示用户界面）
    func checkForUpdatesWithUI() {
        checkForUpdates()
    }
    
    /// 静默检查更新
    func checkForUpdatesSilently() {
        fetchLatestReleaseInfo()
    }
    
    /// 设置是否在启动时自动检查更新
    func setStartupUpdateCheck(_ enabled: Bool) {
        // 注意：这个设置只影响下次启动，当前启动已经完成
        UserDefaults.standard.set(enabled, forKey: "SwiftCraftLauncher.StartupUpdateCheck")
        Logger.shared.info(String(format: "update.startup.check.setting.changed".localized() + ": %@", enabled ? "enabled" : "disabled"))
    }
    
    /// 获取启动时检查更新的设置状态
    func getStartupUpdateCheckStatus() -> Bool {
        return UserDefaults.standard.bool(forKey: "SwiftCraftLauncher.StartupUpdateCheck")
    }
    
    /// 手动触发启动时检查（用于测试或立即执行）
    func triggerStartupCheck() {
        Logger.shared.info("update.startup.check.manual.trigger".localized())
        checkForUpdatesOnStartup()
    }
}

// MARK: - GitHub API 模型

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
} 
 
