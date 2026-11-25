//
//  YggdrasilAuthService.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Manages OAuth2 authentication with Yggdrasil-compatible authentication servers.
@MainActor
@Observable
final class YggdrasilAuthService {
    /// The current authentication state.
    var authState: YggdrasilAuthState = .idle

    /// Whether an authentication request is in progress.
    var isLoading: Bool = false

    /// The currently selected Yggdrasil server configuration.
    var currentServer: YggdrasilServerConfig?

    /// The list of player profiles returned after authentication.
    var authenticatedProfiles: [YggdrasilProfile] = []

    private let authorizationFlow = OAuth2AuthorizationFlow()

    /// Sets the Yggdrasil server to use for authentication.
    func setServer(_ config: YggdrasilServerConfig) {
        currentServer = config
        authenticatedProfiles = []
        if case .authenticated = authState {
            authState = .idle
        }
    }

    /// Selects a player profile from the authenticated profiles list.
    @MainActor
    func selectAuthenticatedProfile(id: String) {
        guard let profile = authenticatedProfiles.first(where: { $0.id == id }) else { return }
        authState = .authenticated(profile: profile)
    }

    /// Starts the Yggdrasil OAuth2 authorization code login flow.
    @MainActor
    func startAuthentication() async {
        authorizationFlow.cancel()
        authenticatedProfiles = []

        guard let server = currentServer else {
            authState = .error("yggdrasil.error.server_not_selected".localized())
            return
        }

        guard let authURL = buildAuthorizationURL(for: server) else {
            authState = .error("yggdrasil.error.build_authorize_url_failed".localized())
            return
        }

        isLoading = true
        authState = .waitingForBrowser

        do {
            switch try await authorizationFlow.requestAuthorizationCode(
                authorizationURL: authURL,
                callbackScheme: URL(string: server.redirectURI)?.scheme,
                prefersEphemeral: DIContainer.shared.ui.playerSettingsManager.enableEphemeralWebLogin,
            ) {
            case let .authorized(code):
                await handleAuthorizationCode(code, server: server)

            case .cancelled:
                AppLog.common.info("User cancelled Yggdrasil login")
                authState = .idle
                isLoading = false

            case .denied:
                AppLog.common.info("User denied Yggdrasil authorization")
                authState = .idle
                isLoading = false
            }
        } catch let error as OAuth2AuthorizationError {
            handleAuthorizationError(error)
        } catch {
            handleAuthorizationError(.sessionFailed(error.localizedDescription))
        }
    }

    /// Clears the authentication state and cancels any active sessions.
    @MainActor
    func logout() {
        authState = .idle
        isLoading = false
        authorizationFlow.cancel()
        currentServer = nil
        authenticatedProfiles = []
    }
}

private extension YggdrasilAuthService {
    @MainActor
    func handleAuthorizationError(_ error: OAuth2AuthorizationError) {
        switch error {
        case .invalidCallbackURL:
            AppLog.common.error("Invalid Yggdrasil callback URL")
            authState = .error("yggdrasil.error.invalid_callback_url".localized())
        case .missingAuthorizationCode:
            AppLog.common.error("No Yggdrasil authorization code received")
            authState = .error("yggdrasil.error.no_auth_code".localized())
        case let .authorizationFailed(description):
            AppLog.common.error("Yggdrasil authorization failed: \(description)")
            authState = .error(description)
        case let .sessionFailed(description):
            AppLog.common.error("Yggdrasil login failed: \(description)")
            authState = .error("yggdrasil.error.login_failed_retry".localized())
        }
        isLoading = false
    }

    func buildAuthorizationURL(for server: YggdrasilServerConfig) -> URL? {
        guard var components = URLComponents(url: server.authorizeURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "redirect_uri", value: server.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
        ]

        if let clientId = server.clientId {
            items.append(URLQueryItem(name: "client_id", value: clientId))
        }

        if !server.scope.isEmpty {
            items.append(URLQueryItem(name: "scope", value: server.scope))
        }

        if server.parserId == .mua || server.parserId == .littleskin {
            items.append(URLQueryItem(name: "prompt", value: "consent"))
        }

        components.queryItems = items
        return components.url
    }

    @MainActor
    func handleAuthorizationCode(_ code: String, server: YggdrasilServerConfig) async {
        authState = .processing

        do {
            let token = try await exchangeCodeForToken(code: code, server: server)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let candidates = try await fetchProfileList(
                accessToken: token.accessToken,
                server: server,
                idToken: token.idToken,
            )

            let accessToken = token.accessToken
            let refreshToken = token.refreshToken ?? ""

            if candidates.isEmpty {
                throw GlobalError.validation(
                    i18nKey: "error.validation.yggdrasil_no_profiles",
                    level: .notification,
                    message: "Yggdrasil returned 0 player profiles for server \(server.baseURL.absoluteString)",
                )
            }

            if candidates.count > 1 {
                AppLog.common.info("Yggdrasil returned multiple player profiles, defaulting to the first one: \(candidates[0].name)")
            }

            let profiles = candidates.map { c in
                YggdrasilProfile(
                    id: c.id,
                    name: c.name,
                    skins: c.skins,
                    capes: c.capes,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    serverBaseURL: server.baseURL.absoluteString,
                )
            }

            authenticatedProfiles = profiles
            isLoading = false
            authState = .authenticated(profile: profiles[0])
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Yggdrasil authentication failed: \(globalError.localizedDescription)")
            isLoading = false
            authState = .error(globalError.localizedDescription)
        }
    }
}
