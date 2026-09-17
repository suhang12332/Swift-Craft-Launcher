//
//  YggdrasilAuthService.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AuthenticationServices
import Foundation
import SwiftUI

/// Manages OAuth2 authentication with Yggdrasil-compatible authentication servers.
@Observable
final class YggdrasilAuthService: @unchecked Sendable {
    /// The current authentication state.
    var authState: YggdrasilAuthState = .idle

    /// Whether an authentication request is in progress.
    var isLoading: Bool = false

    /// The currently selected Yggdrasil server configuration.
    var currentServer: YggdrasilServerConfig?

    /// The list of player profiles returned after authentication.
    var authenticatedProfiles: [YggdrasilProfile] = []

    /// 密码登录时令牌尚未绑定角色(多角色服务器需用户选择后绑定)。
    var passwordTokenNeedsBinding = false

    private let webAuthenticator = WebAuthenticator()

    /// classic authserver 客户端(协议缝,测试可注入)。
    let authServerClient: YggdrasilAuthServerClientProtocol

    init(authServerClient: YggdrasilAuthServerClientProtocol = YggdrasilAuthServerClient()) {
        self.authServerClient = authServerClient
    }

    /// Sets the Yggdrasil server to use for authentication.
    func setServer(_ config: YggdrasilServerConfig) {
        currentServer = config
        authenticatedProfiles = []
        passwordTokenNeedsBinding = false
        if case .authenticated = authState {
            authState = .idle
        }
    }

    /// Selects a player profile from the authenticated profiles list.
    @MainActor
    func selectAuthenticatedProfile(id: String) {
        guard let profile = authenticatedProfiles.first(where: { $0.id == id }) else { return }
        authState = .authenticated(profile: profile)
        // 密码登录 + 令牌未绑定角色:选择角色后立即通过 refresh 完成绑定
        if passwordTokenNeedsBinding, profile.authMethod == .yggdrasilPassword,
           let server = currentServer, let apiRoot = server.passwordAPIRoot {
            Task { @MainActor in
                await bindPasswordProfile(profile, apiRoot: apiRoot)
            }
        }
    }

    /// Starts the Yggdrasil OAuth2 authorization code login flow.
    @MainActor
    func startAuthentication() async {
        webAuthenticator.cancel()
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

        await withCheckedContinuation { continuation in
            self.webAuthenticator.start(
                authorizationURL: authURL,
                callbackScheme: URL(string: server.redirectURI)?.scheme,
                prefersEphemeral: DIContainer.shared.ui.playerSettingsManager.enableEphemeralWebLogin,
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    func finish(_ state: YggdrasilAuthState) {
                        self?.authState = state
                        self?.isLoading = false
                    }

                    guard let self else {
                        continuation.resume()
                        return
                    }

                    defer { continuation.resume() }

                    if let error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            AppLog.common.info("User cancelled Yggdrasil login")
                            finish(.idle)
                        } else {
                            AppLog.common.error("Yggdrasil login failed: \(error.localizedDescription)")
                            finish(.error("yggdrasil.error.login_failed_retry".localized()))
                        }
                        return
                    }

                    guard let callbackURL,
                          let authResponse = AuthorizationCodeResponse(from: callbackURL) else {
                        AppLog.common.error("Invalid Yggdrasil callback URL")
                        finish(.error("yggdrasil.error.invalid_callback_url".localized()))
                        return
                    }

                    if authResponse.isUserDenied {
                        AppLog.common.info("User denied Yggdrasil authorization")
                        finish(.idle)
                        return
                    }

                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        AppLog.common.error("Yggdrasil authorization failed: \(description)")
                        finish(.error(description))
                        return
                    }

                    guard authResponse.isSuccess, let code = authResponse.code else {
                        AppLog.common.error("No Yggdrasil authorization code received")
                        finish(.error("yggdrasil.error.no_auth_code".localized()))
                        return
                    }

                    await self.handleAuthorizationCode(code, server: server)
                }
            }
        }
    }

    /// Clears the authentication state and cancels any active sessions.
    @MainActor
    func logout() {
        authState = .idle
        isLoading = false
        webAuthenticator.cancel()
        currentServer = nil
        authenticatedProfiles = []
        passwordTokenNeedsBinding = false
    }

    /// 通过 refresh(selectedProfile) 将密码登录令牌绑定到所选角色。
    ///
    /// 绑定失败不阻塞账号添加(部分服务器在 authenticate 时已自动绑定),
    /// 令牌有效性会在启动前由续期状态机再次校验。
    @MainActor
    private func bindPasswordProfile(_ profile: YggdrasilProfile, apiRoot: URL) async {
        authState = .processing
        do {
            let response = try await authServerClient.refresh(
                accessToken: profile.accessToken,
                clientToken: profile.clientToken ?? YggdrasilClientTokenProvider.currentToken(),
                selectedProfileId: profile.id,
                apiRoot: apiRoot,
            )
            passwordTokenNeedsBinding = false
            if let index = authenticatedProfiles.firstIndex(where: { $0.id == profile.id }) {
                authenticatedProfiles[index].accessToken = response.accessToken
                authenticatedProfiles[index].clientToken = response.clientToken
            }
            let bound = authenticatedProfiles.first(where: { $0.id == profile.id }) ?? profile
            authState = .authenticated(profile: bound)
        } catch {
            AppLog.common.error("Yggdrasil profile binding failed: \(error)")
            authState = .authenticated(profile: profile)
        }
    }
}

private extension YggdrasilAuthService {
    func buildAuthorizationURL(for server: YggdrasilServerConfig) -> URL? {
        guard let authorizeURL = server.authorizeURL,
              var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false) else {
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
