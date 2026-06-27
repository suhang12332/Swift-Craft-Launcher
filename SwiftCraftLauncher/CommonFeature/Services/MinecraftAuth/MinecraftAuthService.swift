import Foundation
import SwiftUI
import AuthenticationServices

class MinecraftAuthService: NSObject, ObservableObject {
    static let shared = MinecraftAuthService()

    @Published var authState: AuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    var webAuthSession: ASWebAuthenticationSession?

    let clientId = AppConstants.minecraftClientId
    let scope = AppConstants.minecraftScope
    let redirectUri = URLConfig.API.Authentication.redirectUri

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
                callbackURLScheme: AppConstants.callbackURLScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError {
                            if authError.code == .canceledLogin {
                                Logger.shared.info("用户取消了 Microsoft 认证")
                                self?.authState = .notAuthenticated
                            } else {
                                Logger.shared.error("Microsoft 认证失败: \(authError.localizedDescription)")
                                self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                            }
                        } else {
                            Logger.shared.error("Microsoft 认证发生未知错误: \(error.localizedDescription)")
                            self?.authState = .error("minecraft.auth.error.authentication_failed".localized())
                        }
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    guard let callbackURL = callbackURL,
                          let authResponse = AuthorizationCodeResponse(from: callbackURL) else {
                        Logger.shared.error("Microsoft 无效的回调 URL")
                        self?.authState = .error("minecraft.auth.error.invalid_callback_url".localized())
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    if authResponse.isUserDenied {
                        Logger.shared.info("用户拒绝了 Microsoft 授权")
                        self?.authState = .notAuthenticated
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        Logger.shared.error("Microsoft 授权失败: \(description)")
                        self?.authState = .error("授权失败: \(description)")
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    guard authResponse.isSuccess, let code = authResponse.code else {
                        Logger.shared.error("未获取到授权码")
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
            Logger.shared.error("Invalid authorization URL configuration")
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
            Logger.shared.error("Failed to build authorization URL")
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
                uhs: xboxToken.displayClaims.xui.first?.uhs ?? ""
            )
            try await checkMinecraftOwnership(accessToken: minecraftToken)

            let minecraftTokenExpiration = JWTDecoder.getMinecraftTokenExpiration(from: minecraftToken)
            Logger.shared.info("Minecraft token过期时间: \(minecraftTokenExpiration)")

            let profile = try await getMinecraftProfileThrowing(
                accessToken: minecraftToken,
                authXuid: xboxToken.displayClaims.xui.first?.uhs ?? "",
                refreshToken: tokenResponse.refreshToken ?? ""
            )

            Logger.shared.info("Minecraft 认证成功，用户: \(profile.name)")
            isLoading = false
            authState = .authenticated(profile: profile)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Minecraft 认证失败: \(globalError.chineseMessage)")
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
