//
//  AppIconManager.swift
//  Swift Craft Launcher
//
//  Created by Auto on 2025/1/27.
//

import Foundation
import SwiftUI
import AppKit

/// 应用图标选项枚举
public enum AppIconOption: String, CaseIterable, Identifiable {
    case `default` = "AppIcon"
    case blue = "AppIconBlue"
    case cyan = "AppIconCyan"
    case green = "AppIconGreen"
    case pink = "AppIconPink"
    case purple = "AppIconPurple"
    case red = "AppIconRed"

    public var id: String { rawValue }

    /// 图标显示名称
    public var displayName: String {
        switch self {
        case .default:
            return "settings.app_icon.default".localized()
        case .blue:
            return "settings.app_icon.blue".localized()
        case .cyan:
            return "settings.app_icon.cyan".localized()
        case .green:
            return "settings.app_icon.green".localized()
        case .pink:
            return "settings.app_icon.pink".localized()
        case .purple:
            return "settings.app_icon.purple".localized()
        case .red:
            return "settings.app_icon.red".localized()
        }
    }

    /// 图标资源名称（用于在 Assets 中查找）
    public var assetName: String {
        return rawValue
    }
}

/// 应用图标管理器
/// 负责管理应用图标的切换
public class AppIconManager: ObservableObject {
    public static let shared = AppIconManager()

    /// 当前选中的图标
    @AppStorage("selectedAppIcon")
    public var selectedIcon: AppIconOption = .default {
        didSet {
            objectWillChange.send()
            applyIcon()
        }
    }

    private init() {
        // 应用启动时应用已保存的图标
        DispatchQueue.main.async { [weak self] in
            self?.applyIcon()
        }
    }

    /// 应用图标
    private func applyIcon() {
        // 确保在主线程执行（@AppStorage 的 didSet 通常在主线程，但为了安全起见）
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.applyIcon()
            }
            return
        }

        // 尝试从 Assets 中获取图标
        guard let iconImage = getIconImage(for: selectedIcon) else { return }

        NSApplication.shared.applicationIconImage = iconImage

        // 同时使用 NSWorkspace 设置 Finder 中的图标
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.setIcon(iconImage, forFile: appURL.path, options: [])

        // 通知系统文件系统已更改，强制刷新图标显示
        NSWorkspace.shared.noteFileSystemChanged(appURL.path)
    }

    /// 获取图标图像
    private func getIconImage(for option: AppIconOption) -> NSImage? {
        // 尝试从 Assets 中加载图标
        // NSImage(named:) 会自动选择合适尺寸的图像表示
        if let image = NSImage(named: option.assetName) {
            return image
        }

        // 如果备用图标不存在，回退到默认图标
        return NSImage(named: AppIconOption.default.assetName)
    }

    /// 检查图标是否可用
    public func isIconAvailable(_ option: AppIconOption) -> Bool {
        // 默认图标总是可用
        if option == .default {
            return true
        }

        // 检查备用图标是否存在
        return NSImage(named: option.assetName) != nil
    }

    /// 获取所有可用的图标选项
    public var availableIcons: [AppIconOption] {
        return AppIconOption.allCases.filter { isIconAvailable($0) }
    }
}
