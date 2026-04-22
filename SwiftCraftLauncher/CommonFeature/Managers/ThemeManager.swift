//
//  ThemeManager.swift
//  SwiftCraftLauncher
//
//  独立主题管理器，将主题/外观相关职责从 GeneralSettingsManager 拆分，
//  减少根视图因 GeneralSettingsManager 其他设置变化而重建。
//

import AppKit
import Combine
import Foundation
import SwiftUI

/// 主题管理器：负责主题模式、外观应用、系统外观监听
/// 与 GeneralSettingsManager 解耦，避免非主题设置变更触发根视图重建
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage(AppConstants.UserDefaultsKeys.themeMode)
    var themeMode: ThemeMode = .system {
        didSet {
            applyAppAppearance()
            objectWillChange.send()
        }
    }

    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.applyAppAppearance()
            self?.setupAppearanceObserver()
        }
    }

    deinit {
        appearanceObserver?.invalidate()
    }

    /// 当主题模式为 system 时，返回系统当前的主题
    var currentColorScheme: ColorScheme? {
        guard NSApplication.shared.isRunning else {
            return themeMode == .system ? nil : themeMode.effectiveColorScheme
        }
        return themeMode.effectiveColorScheme
    }

    /// 设置系统外观变化观察者
    private func setupAppearanceObserver() {
        appearanceObserver = NSApp.observe(
            \.effectiveAppearance,
            options: [.new, .initial]
        ) { [weak self] _, _ in
            guard let self, self.themeMode == .system else { return }
            self.objectWillChange.send()
        }
    }

    /// 应用基于主题设置的全局 AppKit 外观（影响 Sparkle 等 AppKit UI）
    func applyAppAppearance() {
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
