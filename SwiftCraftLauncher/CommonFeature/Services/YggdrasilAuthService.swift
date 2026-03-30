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
        // 清理旧会话
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

                    // 用户取消或系统错误
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

                    // 用户拒绝授权
                    if authResponse.isUserDenied {
                        Logger.shared.info("用户拒绝了 Yggdrasil 授权")
                        finish(.idle)
                        return
                    }

                    // 授权过程中出现错误
                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        Logger.shared.error("Yggdrasil 授权失败: \(description)")
                        finish(.failed(description))
                        return
                    }

                    // 获取授权码
                    guard authResponse.isSuccess, let code = authResponse.code else {
                        Logger.shared.error("未获取到 Yggdrasil 授权码")
                        finish(.failed("yggdrasil.error.no_auth_code".localized()))
                        return
                    }

                    await self.handleAuthorizationCode(code, server: server)
                }
            }

            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = false
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
    /// 构建授权 URL
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

    /// 处理授权码：换取 token 并拉取玩家列表；默认选择第一个玩家资料完成认证
    @MainActor
    func handleAuthorizationCode(_ code: String, server: YggdrasilServerConfig) async {
        authState = .exchangingCode

        do {
            let token = try await exchangeCodeForToken(code: code, server: server)
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
                    serverBaseURL: server.baseURL
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

    /// 使用授权码换取访问令牌
    func exchangeCodeForToken(code: String, server: YggdrasilServerConfig) async throws -> TokenResponse {
        guard let tokenURL = server.tokenURL else {
            throw GlobalError.validation(
                chineseMessage: "Token 地址无效",
                i18nKey: "error.validation.yggdrasil_token_url_invalid",
                level: .notification
            )
        }

        var parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": server.redirectURI,
        ]

        if let clientId = server.clientId {
            parameters["client_id"] = clientId
        }
        if let clientSecret = server.clientSecret {
            parameters["client_secret"] = clientSecret
        }

        let bodyString = parameters
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")

        let bodyData = bodyString.data(using: .utf8)
        let headers = ["Content-Type": "application/x-www-form-urlencoded"]

        let data = try await APIClient.post(url: tokenURL, body: bodyData, headers: headers)

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Yggdrasil Token 响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.yggdrasil_token_response_parse_failed",
                level: .notification
            )
        }
    }

    /// 拉取玩家资料列表：优先按 LittleSkin 多用户格式解析，否则尝试单用户兼容格式
    func fetchProfileList(
        accessToken: String,
        server: YggdrasilServerConfig
    ) async throws -> [YggdrasilProfileCandidate] {
        guard let profileURL = server.profileURL else {
            throw GlobalError.validation(
                chineseMessage: "玩家资料地址无效",
                i18nKey: "error.validation.yggdrasil_profile_url_invalid",
                level: .notification
            )
        }

        let headers = ["Authorization": "Bearer \(accessToken)"]
        let data = try await APIClient.get(url: profileURL, headers: headers)

        guard let parser = YggdrasilProfileParsers.make(server.parserId, baseURL: server.baseURL) else {
            throw GlobalError.validation(
                chineseMessage: "未找到对应的 Yggdrasil 玩家资料解析器",
                i18nKey: "error.validation.yggdrasil_profile_parse_failed",
                level: .notification
            )
        }

        if let candidates = await parser.parse(data: data) {
            return candidates
        }

        throw GlobalError.validation(
            chineseMessage: "解析 Yggdrasil 玩家资料失败：格式无法识别",
            i18nKey: "error.validation.yggdrasil_profile_parse_failed",
            level: .notification
        )
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension YggdrasilAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
