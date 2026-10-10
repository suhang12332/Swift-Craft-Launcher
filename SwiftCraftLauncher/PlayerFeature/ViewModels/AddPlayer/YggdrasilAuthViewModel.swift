//
//  YggdrasilAuthViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages Yggdrasil authentication server selection and profile dispatch.
///
/// The selected server lives in `YggdrasilAuthService.currentServer` (the picker is
/// visible and switchable at any stage); this view model only handles profile
/// selection and cleanup when the view disappears.
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
