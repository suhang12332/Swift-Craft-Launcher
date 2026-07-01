//
//  MinecraftAuthService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AuthenticationServices
import Foundation
import os
import SwiftUI

/// Handles Microsoft OAuth authentication for Minecraft accounts.
class MinecraftAuthService: NSObject, ObservableObject {
    static let shared = MinecraftAuthService()

    @Published var authState: AuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    var webAuthSession: ASWebAuthenticationSession?

    let clientId = AppConstants.minecraftClientId
    let scope = AppConstants.minecraftScope
    let redirectUri = URLConfig.API.Authentication.redirectUri

    let refreshTasksLock = OSAllocatedUnfairLock<[String: Task<Player, Error>]>(initialState: [:])

    override private init() {
        super.init()
    }

    @MainActor
    func startAuthentication() async {
        webAuthSession?.cancel()
        webAuthSession = nil

        isLoading = true
        authState = .waitingForBrowserAuth

        guard let authURL = buildAuthorizationURL() else {
            isLoading = false
            authState = .error("minecraft.auth.error.authentication_failed".localized())
            return
        }

        await withCheckedContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: URL(string: redirectUri)?.scheme,
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError {
                            if authError.code == .canceledLogin {
                                AppLog.common.info("User cancelled Microsoft authentication")
                                self?.authState = .notAuthenticated
                            } else {
                                AppLog.common.error("Microsoft authentication failed: \(authError.localizedDescription)")
                                self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                            }
                        } else {
                            AppLog.common.error("Unknown Microsoft authentication error: \(error.localizedDescription)")
                            self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                        }
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    guard let callbackURL,
                          let authResponse = AuthorizationCodeResponse(from: callbackURL) else {
                        AppLog.common.error("Invalid Microsoft callback URL")
                        self?.authState = .error("minecraft.auth.error.invalid_callback_url".localized())
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    if authResponse.isUserDenied {
                        AppLog.common.info("User denied Microsoft authorization")
                        self?.authState = .notAuthenticated
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        AppLog.common.error("Microsoft authorization failed: \(description)")
                        self?.authState = .error("Authorization failed: \(description)")
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    guard authResponse.isSuccess, let code = authResponse.code else {
                        AppLog.common.error("No authorization code received")
                        self?.authState = .error("minecraft.auth.error.no_authorization_code".localized())
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    await self?.handleAuthorizationCode(code)
                    continuation.resume()
                }
            }

            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = AppServices.playerSettingsManager.enableEphemeralWebLogin
            webAuthSession?.start()
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
        ]
        guard let url = components.url else {
            AppLog.common.error("Failed to build authorization URL")
            return nil
        }
        return url
    }

    @MainActor
    private func handleAuthorizationCode(_ code: String) async {
        authState = .processingAuthCode

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
        authState = .notAuthenticated
        webAuthSession?.cancel()
        webAuthSession = nil
        isLoading = false
    }

    @MainActor
    func clearAuthenticationData() {
        authState = .notAuthenticated
        isLoading = false
        webAuthSession?.cancel()
        webAuthSession = nil
    }
}
