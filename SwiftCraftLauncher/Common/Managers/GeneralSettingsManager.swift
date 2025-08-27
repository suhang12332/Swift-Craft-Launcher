import Foundation
import SwiftUI


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
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
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

class GeneralSettingsManager: ObservableObject {
    static let shared = GeneralSettingsManager()
    
    @AppStorage("themeMode") public var themeMode: ThemeMode = .system {
        didSet {
            applyAppAppearance()
            objectWillChange.send()
        }
    }
    // 新增：启动器工作目录
    @AppStorage("launcherWorkingDirectory") public var launcherWorkingDirectory: String = AppPaths.launcherSupportDirectory.path {
        didSet { objectWillChange.send() }
    }
    
    // 添加系统外观变化观察者
    private var appearanceObserver: NSKeyValueObservation?
    
    private init() {
        // 延迟应用外观设置，确保 NSApp 已完全初始化
        DispatchQueue.main.async { [weak self] in
            self?.applyAppAppearance()
            self?.setupAppearanceObserver()
        }
        

    }
    
    deinit {
        appearanceObserver?.invalidate()
    }
    
    /// 设置系统外观变化观察者
    private func setupAppearanceObserver() {
        // 监听 NSApp 的 effectiveAppearance 变化
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new, .initial]) { [weak self] _, _ in
            DispatchQueue.main.async {
                // 当系统外观变化时，如果当前主题模式是 system，则通知 UI 更新
                if self?.themeMode == .system {
                    self?.objectWillChange.send()
                }
            }
        }
    }

    /// 应用基于主题设置的全局 AppKit 外观（影响 Sparkle 等 AppKit UI）
    public func applyAppAppearance() {
        let appearance = themeMode.nsAppearance
        if Thread.isMainThread {
            NSApp.appearance = appearance
        } else {
            DispatchQueue.main.async {
                NSApp.appearance = appearance
            }
        }
    }
    
    /// 获取当前有效的 ColorScheme，用于 @Environment(\.colorScheme) 的替代方案
    /// 当主题模式为 system 时，返回系统当前的主题
    public var currentColorScheme: ColorScheme? {
        return themeMode.effectiveColorScheme
    }
}
