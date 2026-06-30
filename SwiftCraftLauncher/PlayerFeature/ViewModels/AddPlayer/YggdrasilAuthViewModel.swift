//
//  YggdrasilAuthViewModel.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Manages Yggdrasil authentication server selection and profile dispatch.
@MainActor
final class YggdrasilAuthViewModel: ObservableObject {
    /// The currently selected Yggdrasil server configuration.
    @Published var selectedOption: YggdrasilServerConfig?

    /// Handles a change in server selection and updates the auth service.
    ///
    /// - Parameters:
    ///   - option: The newly selected server configuration.
    ///   - authService: The Yggdrasil authentication service.
    func onSelectedOptionChanged(_ option: YggdrasilServerConfig?, authService: YggdrasilAuthService) {
        if let option {
            authService.setServer(option)
        }
    }

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
