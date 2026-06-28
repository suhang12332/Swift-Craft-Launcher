import Foundation
import SwiftUI
import AuthenticationServices

final class YggdrasilAuthService: NSObject, ObservableObject {
    static let shared = YggdrasilAuthService()

    /// 当前认证状态
    @Published var authState: YggdrasilAuthState = .idle

    /// 是否处于加载/网络请求中
    @Published var isLoading: Bool = false

    /// 当前选中的 Yggdrasil 服务器配置
    @Published var currentServer: YggdrasilServerConfig?

    /// 认证后拿到的玩家资料列表（多角色时用于 UI 选择）
    @Published var authenticatedProfiles: [YggdrasilProfile] = []

    private var webAuthSession: ASWebAuthenticationSession?

    override private init() {
        super.init()
    }
}

extension YggdrasilAuthService {
    /// 设置当前要使用的 Yggdrasil 服务器
    func setServer(_ config: YggdrasilServerConfig) {
        currentServer = config
        authenticatedProfiles = []
        if case .authenticated = authState {
            authState = .idle
        }
    }

    /// 在多角色场景下切换当前选中的玩家资料
    @MainActor
    func selectAuthenticatedProfile(id: String) {
        guard let profile = authenticatedProfiles.first(where: { $0.id == id }) else { return }
        authState = .authenticated(profile: profile)
    }

    /// 启动 Yggdrasil OAuth2 授权码登录流程
    @MainActor
    func startAuthentication() async {
        webAuthSession?.cancel()
        webAuthSession = nil
        authenticatedProfiles = []

        guard let server = currentServer else {
            authState = .failed("yggdrasil.error.server_not_selected".localized())
            return
        }

        guard let authURL = buildAuthorizationURL(for: server) else {
            authState = .failed("yggdrasil.error.build_authorize_url_failed".localized())
            return
        }

        isLoading = true
        authState = .waitingForBrowser

        await withCheckedContinuation { continuation in
            let scheme = URL(string: server.redirectURI)?.scheme

            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
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

                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            Logger.shared.info("用户取消了 Yggdrasil 登录")
                            finish(.idle)
                        } else {
                            Logger.shared.error("Yggdrasil 登录失败: \(error.localizedDescription)")
                            finish(.failed("yggdrasil.error.login_failed_retry".localized()))
                        }
                        return
                    }

                    guard let callbackURL,
                          let authResponse = AuthorizationCodeResponse(from: callbackURL) else {
                        Logger.shared.error("Yggdrasil 回调地址无效")
                        finish(.failed("yggdrasil.error.invalid_callback_url".localized()))
                        return
                    }

                    if authResponse.isUserDenied {
                        Logger.shared.info("用户拒绝了 Yggdrasil 授权")
                        finish(.idle)
                        return
                    }

                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        Logger.shared.error("Yggdrasil 授权失败: \(description)")
                        finish(.failed(description))
                        return
                    }

                    guard authResponse.isSuccess, let code = authResponse.code else {
                        Logger.shared.error("未获取到 Yggdrasil 授权码")
                        finish(.failed("yggdrasil.error.no_auth_code".localized()))
                        return
                    }

                    await self.handleAuthorizationCode(code, server: server)
                }
            }

            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = AppServices.playerSettingsManager.enableEphemeralWebLogin
            webAuthSession?.start()
        }
    }

    /// 登出/清理认证状态
    @MainActor
    func logout() {
        authState = .idle
        isLoading = false
        webAuthSession?.cancel()
        webAuthSession = nil
        currentServer = nil
        authenticatedProfiles = []
    }
}

// MARK: - 内部流程
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

        let scope = server.scope.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scope.isEmpty {
            items.append(URLQueryItem(name: "scope", value: scope))
        }

        components.queryItems = items
        return components.url
    }

    @MainActor
    func handleAuthorizationCode(_ code: String, server: YggdrasilServerConfig) async {
        authState = .exchangingCode

        do {
            let token = try await exchangeCodeForToken(code: code, server: server)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let candidates = try await fetchProfileList(
                accessToken: token.accessToken,
                server: server
            )

            let accessToken = token.accessToken
            let refreshToken = token.refreshToken ?? ""

            if candidates.isEmpty {
                throw GlobalError.validation(
                    chineseMessage: "未获取到任何玩家资料",
                    i18nKey: "error.validation.yggdrasil_no_profiles",
                    level: .notification
                )
            }

            if candidates.count > 1 {
                Logger.shared.info("Yggdrasil 返回多个玩家资料，默认选择第一个: \(candidates[0].name)")
            }

            let profiles = candidates.map { c in
                YggdrasilProfile(
                    id: c.id,
                    name: c.name,
                    skins: c.skins,
                    capes: c.capes,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    serverBaseURL: server.baseURL.absoluteString
                )
            }

            authenticatedProfiles = profiles
            isLoading = false
            authState = .authenticated(profile: profiles[0])
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Yggdrasil 认证失败: \(globalError.chineseMessage)")
            isLoading = false
            authState = .failed(globalError.localizedDescription)
        }
    }
}
