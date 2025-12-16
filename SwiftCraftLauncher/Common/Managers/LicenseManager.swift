//
//  LicenseManager.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/1.
//

import SwiftUI

/// 协议显示管理器
public class LicenseManager {
    /// 单例实例
    public static let shared = LicenseManager()

    private init() {}

    /// 显示协议窗口（使用窗口管理器）
    @MainActor
    public func showLicense() {
        TemporaryWindowManager.shared.showWindow(
            content: LicenseView(),
            config: .license(title: "license.view".localized())
        )
    }

    /// 关闭协议窗口
    @MainActor
    public func closeLicense() {
        TemporaryWindowManager.shared.closeWindow()
    }
}
