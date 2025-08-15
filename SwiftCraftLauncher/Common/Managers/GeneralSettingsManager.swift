import Foundation
import SwiftUI
import AppKit

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
    @AppStorage("launcherWorkingDirectory") public var launcherWorkingDirectory: String = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? "" {
        didSet { objectWillChange.send() }
    }
    
    private init() {
        // 确保应用启动时就应用一次外观，以影响 Sparkle 等 AppKit 组件
        applyAppAppearance()
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
}
