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

class GeneralSettingsManager: ObservableObject, WorkingPathProviding {
    static let shared = GeneralSettingsManager()

    /// 是否启用 GitHub 代理（默认开启）
    @AppStorage(AppConstants.UserDefaultsKeys.enableGitHubProxy)
    var enableGitHubProxy: Bool = true {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.gitProxyURL)
    var gitProxyURL: String = "https://gh-proxy.com" {
        didSet { objectWillChange.send() }
    }

    /// 是否限制通用 Sheet 高度（默认关闭）
    @AppStorage(AppConstants.UserDefaultsKeys.limitCommonSheetHeight)
    var limitCommonSheetHeight: Bool = false {
        didSet { objectWillChange.send() }
    }

    // MARK: - 应用设置属性
    @AppStorage(AppConstants.UserDefaultsKeys.concurrentDownloads)
    var concurrentDownloads: Int = 64 {
        didSet {
            if concurrentDownloads < 1 {
                concurrentDownloads = 1
            }
            objectWillChange.send()
        }
    }

    // 新增：启动器工作目录
    @AppStorage(AppConstants.UserDefaultsKeys.launcherWorkingDirectory)
    var launcherWorkingDirectory: String = AppPaths.launcherSupportDirectory.path {
        didSet { objectWillChange.send() }
    }

    /// 界面风格：经典（列表 | 内容）/ 聚焦（内容 | 列表）
    @AppStorage(AppConstants.UserDefaultsKeys.interfaceLayoutStyle)
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
