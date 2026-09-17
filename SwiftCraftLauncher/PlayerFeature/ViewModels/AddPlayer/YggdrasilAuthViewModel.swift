//
//  YggdrasilAuthViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages Yggdrasil authentication server selection and profile dispatch.
///
/// 服务器选择的真源在 `YggdrasilAuthService.currentServer`(选择器全局可见,
/// 任意阶段可切换);本视图模型只负责角色选择与视图消失时的清理。
@MainActor
@Observable
final class YggdrasilAuthViewModel {
    /// Cleans up the auth service state when the view disappears.
    ///
    /// - Parameter authService: The Yggdrasil authentication service.
    func onDisappear(authService: YggdrasilAuthService) {
        if case .idle = authService.authState {
            authService.logout()
        }
    }

    /// Selects an authenticated profile by identifier.
    ///
    /// - Parameters:
    ///   - id: The profile identifier to select.
    ///   - authService: The Yggdrasil authentication service.
    func selectAuthenticatedProfile(id: String, authService: YggdrasilAuthService) {
        authService.selectAuthenticatedProfile(id: id)
    }
}
