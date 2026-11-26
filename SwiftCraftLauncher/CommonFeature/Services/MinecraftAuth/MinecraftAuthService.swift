//
//  MinecraftAuthService.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os
import SwiftUI

/// Handles Microsoft OAuth authentication for Minecraft accounts.
@MainActor
@Observable
final class MinecraftAuthService {
    var authState: AuthenticationState = .idle
    var isLoading: Bool = false
    var authenticationIssue: MinecraftAuthenticationIssue?

    let clientId = AppConstants.minecraftClientId
    let scope = AppConstants.minecraftScope
    let redirectUri = URLConfig.API.Authentication.redirectUri

    let refreshTasksLock = OSAllocatedUnfairLock<[String: Task<Player, Error>]>(initialState: [:])

    private let authorizationFlow = OAuth2AuthorizationFlow()

    @MainActor
    func startAuthentication() async {
        authorizationFlow.cancel()

        isLoading = true
        authenticationIssue = nil
        authState = .waitingForBrowser

        guard let authURL = buildAuthorizationURL() else {
            isLoading = false
            authState = .error("minecraft.auth.error.authentication_failed".localized())
            return
        }

        do {
            switch try await authorizationFlow.requestAuthorizationCode(
                authorizationURL: authURL,
                callbackScheme: URL(string: redirectUri)?.scheme,
                prefersEphemeral: DIContainer.shared.ui.playerSettingsManager.enableEphemeralWebLogin,
            ) {
            case let .authorized(code):
                await handleAuthorizationCode(code)

            case .cancelled:
                AppLog.common.info("User cancelled Microsoft authentication")
                authState = .idle
                isLoading = false

            case .denied:
                AppLog.common.info("User denied Microsoft authorization")
                authState = .idle
                isLoading = false
            }
        } catch let error as OAuth2AuthorizationError {
            handleAuthorizationError(error)
        } catch {
            handleAuthorizationError(.sessionFailed(error.localizedDescription))
        }
    }

    private func buildAuthorizationURL() -> URL? {
        guard var components = URLComponents(url: URLConfig.API.Authentication.authorize, resolvingAgainstBaseURL: false) else {
            AppLog.common.error("Invalid authorization URL configuration")
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: UUID().uuidString),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let url = components.url else {
            AppLog.common.error("Failed to build authorization URL")
            return nil
        }
        return url
    }

    @MainActor
    private func handleAuthorizationCode(_ code: String) async {
        authState = .processing

        do {
            let tokenResponse = try await exchangeCodeForToken(code: code)

            let xboxToken = try await getXboxLiveTokenThrowing(accessToken: tokenResponse.accessToken)
            let minecraftToken = try await getMinecraftTokenThrowing(
                xboxToken: xboxToken.token,
                uhs: xboxToken.displayClaims.xui.first?.uhs ?? "",
            )
            try await checkMinecraftOwnership(accessToken: minecraftToken)

            let minecraftTokenExpiration = JWTDecoder.getMinecraftTokenExpiration(from: minecraftToken)
            AppLog.common.info("Minecraft token expiration time: \(minecraftTokenExpiration)")

            let profile = try await getMinecraftProfileThrowing(
                accessToken: minecraftToken,
                authXuid: xboxToken.displayClaims.xui.first?.uhs ?? "",
                refreshToken: tokenResponse.refreshToken ?? "",
            )

            AppLog.common.info("Minecraft authentication succeeded, user: \(profile.name)")
            isLoading = false
            authState = .authenticated(profile: profile)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Minecraft authentication failed: \(globalError.localizedDescription)")
            isLoading = false
            authState = .error(globalError.localizedDescription)
        }
    }

    @MainActor
    func logout() {
        authState = .idle
        authenticationIssue = nil
        authorizationFlow.cancel()
        isLoading = false
    }

    @MainActor
    func clearAuthenticationData() {
        logout()
    }

    @MainActor
    private func handleAuthorizationError(_ error: OAuth2AuthorizationError) {
        switch error {
        case .invalidCallbackURL:
            AppLog.common.error("Invalid Microsoft callback URL")
            authState = .error("minecraft.auth.error.invalid_callback_url".localized())
        case .missingAuthorizationCode:
            AppLog.common.error("No authorization code received")
            authState = .error("minecraft.auth.error.no_authorization_code".localized())
        case let .authorizationFailed(description):
            AppLog.common.error("Microsoft authorization failed: \(description)")
            authState = .error("Authorization failed: \(description)")
        case let .sessionFailed(description):
            AppLog.common.error("Microsoft authentication failed: \(description)")
            authState = .error("minecraft.auth.error.authentication_failed".localized())
        }
        isLoading = false
    }
}
