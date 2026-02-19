import Combine
import Foundation
import SwiftUI

/// 主界面布局风格：经典（列表在左、内容在右）/ 聚焦（内容在左、列表在右）
public enum InterfaceLayoutStyle: String, CaseIterable {
    case classic = "classic"   // 经典
    case focused = "focused"  // 聚焦

    public var localizedName: String {
        "settings.interface_style.\(rawValue)".localized()
    }
}

public enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    public var localizedName: String {
        "settings.theme.\(rawValue)".localized()
    }

    public var effectiveColorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            // 在主线程上安全访问系统外观
            if Thread.isMainThread {
                // 使用 NSApplication.shared 而不是 NSApp，更安全
                let appearance = NSApplication.shared.effectiveAppearance
                let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
                return bestMatch == .darkAqua ? .dark : .light
            } else {
                // 如果不在主线程，返回默认的 light 主题
                return .light
            }
        }
    }

    /// 对应的 AppKit 外观，用于影响基于 AppKit 的 UI（如 Sparkle）
    public var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .system:
            return nil
        }
    }
}

class GeneralSettingsManager: ObservableObject, WorkingPathProviding {
    static let shared = GeneralSettingsManager()

    /// 是否启用 GitHub 代理（默认开启）
    @AppStorage("enableGitHubProxy")
    var enableGitHubProxy: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage("gitProxyURL")
    var gitProxyURL: String = "https://gh-proxy.com" {
        didSet { objectWillChange.send() }
    }

    /// 是否启用资源页面本地缓存（默认开启）
    @AppStorage("enableResourcePageCache")
    var enableResourcePageCache: Bool = true {
        didSet { objectWillChange.send() }
    }

    // MARK: - 应用设置属性
    @AppStorage("concurrentDownloads")
    var concurrentDownloads: Int = 64 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }

    // 新增：启动器工作目录
    @AppStorage("launcherWorkingDirectory")
    var launcherWorkingDirectory: String = AppPaths.launcherSupportDirectory.path {
        didSet { objectWillChange.send() }
    }

    /// 界面风格：经典（列表 | 内容）/ 聚焦（内容 | 列表）
    @AppStorage("interfaceLayoutStyle")
    var interfaceLayoutStyle: InterfaceLayoutStyle = .classic {
        didSet { objectWillChange.send() }
    }

    private init() {}

    /// 当前启动器工作目录（WorkingPathProviding）
    /// 空时使用默认支持目录
    var currentWorkingPath: String {
        launcherWorkingDirectory.isEmpty ? AppPaths.launcherSupportDirectory.path : launcherWorkingDirectory
    }

    var workingPathWillChange: AnyPublisher<Void, Never> {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }
}
