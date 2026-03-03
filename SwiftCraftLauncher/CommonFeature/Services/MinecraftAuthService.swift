import Foundation
import SwiftUI
import AuthenticationServices

class MinecraftAuthService: NSObject, ObservableObject {
    static let shared = MinecraftAuthService()

    @Published var authState: AuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    private var webAuthSession: ASWebAuthenticationSession?

    private let clientId = AppConstants.minecraftClientId
    private let scope = AppConstants.minecraftScope
    private let redirectUri = URLConfig.API.Authentication.redirectUri

    override private init() {
        super.init()
    }

    // MARK: - 认证流程 (使用 ASWebAuthenticationSession)
    @MainActor
    func startAuthentication() async {
        // 开始新认证前清理之前的状态
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

                    // 检查是否是用户拒绝授权
                    if authResponse.isUserDenied {
                        Logger.shared.info("用户拒绝了 Microsoft 授权")
                        self?.authState = .notAuthenticated
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    // 检查是否有其他错误
                    if let error = authResponse.error {
                        let description = authResponse.errorDescription ?? error
                        Logger.shared.error("Microsoft 授权失败: \(description)")
                        self?.authState = .error("授权失败: \(description)")
                        self?.isLoading = false
                        continuation.resume()
                        return
                    }

                    // 检查是否成功获取授权码
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
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }
    }

    // MARK: - 构建授权 URL（失败时返回 nil，由调用方处理，避免生产环境闪退）
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

    // MARK: - 处理授权码
    @MainActor
    private func handleAuthorizationCode(_ code: String) async {
        authState = .processingAuthCode

        do {
            // 使用授权码获取访问令牌
            let tokenResponse = try await exchangeCodeForToken(code: code)

            // 获取完整的认证链
            let xboxToken = try await getXboxLiveTokenThrowing(accessToken: tokenResponse.accessToken)
            let minecraftToken = try await getMinecraftTokenThrowing(xboxToken: xboxToken.token, uhs: xboxToken.displayClaims.xui.first?.uhs ?? "")
            try await checkMinecraftOwnership(accessToken: minecraftToken)

            // 使用JWT解析获取Minecraft token的真实过期时间
            let minecraftTokenExpiration = JWTDecoder.getMinecraftTokenExpiration(from: minecraftToken)
            Logger.shared.info("Minecraft token过期时间: \(minecraftTokenExpiration)")

            // 创建包含正确过期时间的profile
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
            authState = .error(globalError.chineseMessage)
        }
    }

    // MARK: - 使用授权码交换访问令牌
    private func exchangeCodeForToken(code: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParameters = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "scope": scope,
        ]

        let bodyString = bodyParameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)

        // 使用统一的 API 客户端
        let headers = ["Content-Type": "application/x-www-form-urlencoded"]
        let data = try await APIClient.post(url: url, body: bodyData, headers: headers)

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.token_response_parse_failed",
                level: .notification
            )
        }
    }

    // MARK: - 获取Xbox Live令牌（静默版本）
    private func getXboxLiveToken(accessToken: String) async -> XboxLiveTokenResponse? {
        do {
            return try await getXboxLiveTokenThrowing(accessToken: accessToken)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Xbox Live 令牌失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    // MARK: - 获取Xbox Live令牌（抛出异常版本）
    private func getXboxLiveTokenThrowing(accessToken: String) async throws -> XboxLiveTokenResponse {
        let url = URLConfig.API.Authentication.xboxLiveAuth
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "Properties": [
                "AuthMethod": "RPS",
                "SiteName": "user.auth.xboxlive.com",
                "RpsTicket": "d=\(accessToken)",
            ],
            "RelyingParty": "http://auth.xboxlive.com",
            "TokenType": "JWT",
        ]

        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 Xbox Live 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xbox_live_request_serialize_failed",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let headers = ["Content-Type": "application/json"]
        let data = try await APIClient.post(url: url, body: bodyData, headers: headers)

        do {
            return try JSONDecoder().decode(XboxLiveTokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Xbox Live 令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xbox_live_token_parse_failed",
                level: .notification
            )
        }
    }

    // MARK: - 获取Minecraft访问令牌（静默版本）
    private func getMinecraftToken(xboxToken: String, uhs: String) async -> String? {
        do {
            return try await getMinecraftTokenThrowing(xboxToken: xboxToken, uhs: uhs)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Minecraft 访问令牌失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    // MARK: - 获取Minecraft访问令牌（抛出异常版本）
    private func getMinecraftTokenThrowing(xboxToken: String, uhs: String) async throws -> String {
        // 获取XSTS令牌
        let xstsUrl = URLConfig.API.Authentication.xstsAuth
        var xstsRequest = URLRequest(url: xstsUrl)
        xstsRequest.httpMethod = "POST"
        xstsRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let xstsBody: [String: Any] = [
            "Properties": [
                "SandboxId": "RETAIL",
                "UserTokens": [xboxToken],
            ],
            "RelyingParty": "rp://api.minecraftservices.com/",
            "TokenType": "JWT",
        ]

        let xstsBodyData: Data
        do {
            xstsBodyData = try JSONSerialization.data(withJSONObject: xstsBody)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 XSTS 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xsts_request_serialize_failed",
                level: .notification
            )
        }

        // 使用统一的 API 客户端
        let xstsHeaders = ["Content-Type": "application/json"]
        let xstsData = try await APIClient.post(url: xstsUrl, body: xstsBodyData, headers: xstsHeaders)

        let xstsTokenResponse: XboxLiveTokenResponse
        do {
            xstsTokenResponse = try JSONDecoder().decode(XboxLiveTokenResponse.self, from: xstsData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 XSTS 令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xsts_token_parse_failed",
                level: .notification
            )
        }

        // 获取Minecraft访问令牌
        Logger.shared.debug("开始获取 Minecraft 访问令牌")
        let minecraftUrl = URLConfig.API.Authentication.minecraftLogin

        let minecraftBody: [String: Any] = [
            "identityToken": "XBL3.0 x=\(uhs);\(xstsTokenResponse.token)"
        ]

        let minecraftBodyData: Data
        do {
            minecraftBodyData = try JSONSerialization.data(withJSONObject: minecraftBody)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 Minecraft 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.minecraft_request_serialize_failed",
                level: .notification
            )
        }

        // 使用统一的 API 客户端（需要处理非 200 状态码）
        var minecraftRequest = URLRequest(url: minecraftUrl)
        minecraftRequest.httpMethod = "POST"
        minecraftRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        minecraftRequest.timeoutInterval = 30.0
        minecraftRequest.httpBody = minecraftBodyData

        let (minecraftData, minecraftHttpResponse) = try await APIClient.performRequestWithResponse(request: minecraftRequest)

        guard minecraftHttpResponse.statusCode == 200 else {
            let statusCode = minecraftHttpResponse.statusCode
            Logger.shared.error("Minecraft 认证失败: HTTP \(statusCode)")

            // 根据不同的状态码提供更具体的错误信息
            switch statusCode {
            case 401:
                throw GlobalError.authentication(
                    chineseMessage: "Minecraft 认证失败: Xbox Live 令牌无效或已过期",
                    i18nKey: "error.authentication.invalid_xbox_token",
                    level: .notification
                )
            case 403:
                throw GlobalError.authentication(
                    chineseMessage: "Minecraft 认证失败: 该Microsoft账户未购买Minecraft",
                    i18nKey: "error.authentication.minecraft_not_owned",
                    level: .notification
                )
            case 503:
                throw GlobalError.network(
                    chineseMessage: "Minecraft 认证服务暂时不可用，请稍后重试",
                    i18nKey: "error.network.minecraft_service_unavailable",
                    level: .notification
                )
            case 429:
                throw GlobalError.network(
                    chineseMessage: "请求过于频繁，请稍后重试",
                    i18nKey: "error.network.rate_limited",
                    level: .notification
                )
            default:
                throw GlobalError.download(
                    chineseMessage: "获取 Minecraft 访问令牌失败: HTTP \(statusCode)",
                    i18nKey: "error.download.minecraft_token_failed",
                    level: .notification
                )
            }
        }

        let minecraftTokenResponse: TokenResponse
        do {
            minecraftTokenResponse = try JSONDecoder().decode(TokenResponse.self, from: minecraftData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Minecraft 访问令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.minecraft_token_parse_failed",
                level: .notification
            )
        }

        return minecraftTokenResponse.accessToken
    }

    // MARK: - 检查Minecraft游戏拥有情况
    private func checkMinecraftOwnership(accessToken: String) async throws {
        let url = URLConfig.API.Authentication.minecraftEntitlements
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0

        // 使用统一的 API 客户端（需要处理非 200 状态码）
        let (data, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        guard httpResponse.statusCode == 200 else {
            let statusCode = httpResponse.statusCode

            // 根据状态码提供具体的错误信息
            switch statusCode {
            case 401:
                throw GlobalError.authentication(
                    chineseMessage: "Minecraft 访问令牌无效或已过期",
                    i18nKey: "error.authentication.invalid_minecraft_token",
                    level: .notification
                )
            case 403:
                throw GlobalError.authentication(
                    chineseMessage: "该账户未购买 Minecraft，请使用已购买 Minecraft 的 Microsoft 账户登录",
                    i18nKey: "error.authentication.minecraft_not_purchased",
                    level: .popup
                )
            default:
                throw GlobalError.download(
                    chineseMessage: "检查游戏拥有情况失败: HTTP \(statusCode)",
                    i18nKey: "error.download.entitlements_check_failed",
                    level: .notification
                )
            }
        }

        do {
            let entitlements = try JSONDecoder().decode(MinecraftEntitlementsResponse.self, from: data)

            // 检查是否拥有必要的游戏权限
            let hasProductMinecraft = entitlements.items.contains { $0.name == MinecraftEntitlement.productMinecraft.rawValue }
            let hasGameMinecraft = entitlements.items.contains { $0.name == MinecraftEntitlement.gameMinecraft.rawValue }

            if !hasProductMinecraft || !hasGameMinecraft {
                throw GlobalError.authentication(
                    chineseMessage: "该 Microsoft 账户未购买 Minecraft 或权限不足，请使用已购买 Minecraft 的账户登录",
                    i18nKey: "error.authentication.insufficient_minecraft_entitlements",
                    level: .popup
                )
            }

            // 验证通过
        } catch let decodingError as DecodingError {
            throw GlobalError.validation(
                chineseMessage: "解析游戏权限响应失败: \(decodingError.localizedDescription)",
                i18nKey: "error.validation.entitlements_parse_failed",
                level: .notification
            )
        } catch let globalError as GlobalError {
            // 重新抛出 GlobalError
            throw globalError
        } catch {
            throw GlobalError.validation(
                chineseMessage: "检查游戏拥有情况时发生未知错误: \(error.localizedDescription)",
                i18nKey: "error.validation.entitlements_check_unknown_error",
                level: .notification
            )
        }
    }

    // MARK: - 获取Minecraft用户资料
    private func getMinecraftProfileThrowing(accessToken: String, authXuid: String, refreshToken: String = "") async throws -> MinecraftProfileResponse {
        let url = URLConfig.API.Authentication.minecraftProfile
        // 使用统一的 API 客户端
        let headers = ["Authorization": "Bearer \(accessToken)"]
        let data = try await APIClient.get(url: url, headers: headers)

        do {
            let profile = try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)

            // accessToken、authXuid 和 refreshToken 非 API 返回，需手动设置
            return MinecraftProfileResponse(
                id: profile.id,
                name: profile.name,
                skins: profile.skins,
                capes: profile.capes,
                accessToken: accessToken,
                authXuid: authXuid,
                refreshToken: refreshToken
            )
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 Minecraft 用户资料响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.minecraft_profile_parse_failed",
                level: .notification
            )
        }
    }

    // MARK: - 登出/取消认证
    @MainActor
    func logout() {
        authState = .notAuthenticated
        webAuthSession?.cancel()
        webAuthSession = nil
        isLoading = false
    }

    // MARK: - 清理认证数据
    @MainActor
    func clearAuthenticationData() {
        authState = .notAuthenticated
        isLoading = false
        webAuthSession?.cancel()
        webAuthSession = nil
    }
}

// MARK: - Token Validation and Refresh
extension MinecraftAuthService {
    // MARK: - Token验证和刷新相关方法

    /// 刷新指定玩家的 Token（公开接口）
    /// - Parameter player: 需要刷新 Token 的玩家
    /// - Returns: 刷新后的玩家对象
    @MainActor
    func refreshPlayerToken(for player: Player) async -> Result<Player, GlobalError> {
        isLoading = true
        defer { isLoading = false }

        do {
            let refreshedPlayer = try await validateAndRefreshPlayerTokenThrowing(for: player)
            Logger.shared.info("成功刷新玩家 \(player.name) 的 Token")
            return .success(refreshedPlayer)
        } catch let error as GlobalError {
            return .failure(error)
        } catch {
            let globalError = GlobalError.authentication(
                chineseMessage: "刷新 Token 时发生未知错误: \(error.localizedDescription)",
                i18nKey: "error.authentication.unknown_refresh_error",
                level: .popup
            )
            return .failure(globalError)
        }
    }

    /// 验证并尝试刷新玩家Token
    /// - Parameter player: 玩家对象
    /// - Returns: 验证/刷新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func validateAndRefreshPlayerTokenThrowing(for player: Player) async throws -> Player {

        // 如果没有访问令牌，抛出错误要求重新登录
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .notification
            )
        }

        // 基于tokenExpiresAt检查token是否过期
        let isTokenExpired = await isTokenExpiredBasedOnTime(for: player)

        if !isTokenExpired {
            Logger.shared.debug("玩家 \(player.name) 的Token尚未过期，无需刷新")
            return player
        }

        Logger.shared.info("玩家 \(player.name) 的Token已过期，尝试刷新")

        // Token过期，尝试使用refresh token刷新
        guard !player.authRefreshToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.token_expired_relogin_required",
                level: .popup
            )
        }

        // 使用refresh token刷新访问令牌
        let refreshedTokens = try await refreshTokenThrowing(refreshToken: player.authRefreshToken)

        // 使用新的访问令牌获取完整的认证链
        let xboxToken = try await getXboxLiveTokenThrowing(accessToken: refreshedTokens.accessToken)
        let minecraftToken = try await getMinecraftTokenThrowing(xboxToken: xboxToken.token, uhs: xboxToken.displayClaims.xui.first?.uhs ?? "")

        // 创建更新后的玩家对象
        var updatedProfile = player.profile
        updatedProfile.lastPlayed = player.lastPlayed
        updatedProfile.isCurrent = player.isCurrent

        var updatedCredential = player.credential
        if var credential = updatedCredential {
            credential.accessToken = minecraftToken
            credential.refreshToken = refreshedTokens.refreshToken ?? player.authRefreshToken
            credential.xuid = xboxToken.displayClaims.xui.first?.uhs ?? player.authXuid
            updatedCredential = credential
        } else {
            // 如果原来没有 credential，创建一个新的
            updatedCredential = AuthCredential(
                userId: player.id,
                accessToken: minecraftToken,
                refreshToken: refreshedTokens.refreshToken ?? "",
                expiresAt: nil,
                xuid: xboxToken.displayClaims.xui.first?.uhs ?? ""
            )
        }

        let updatedPlayer = Player(profile: updatedProfile, credential: updatedCredential)

        return updatedPlayer
    }

    /// 使用refresh token刷新访问令牌（抛出异常版本）
    /// - Parameter refreshToken: 刷新令牌
    /// - Returns: 新的令牌响应
    /// - Throws: GlobalError 当刷新失败时
    private func refreshTokenThrowing(refreshToken: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token

        // refresh_token 可能包含特殊字符，必须进行 x-www-form-urlencoded 编码
        let bodyParameters: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken,
        ]
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)

        // 使用统一的 API 客户端（需要处理非 200 状态码）
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        // 检查OAuth错误
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorResponse["error"] as? String {
            switch error {
            case "invalid_grant":
                Logger.shared.error("刷新令牌已过期或无效")
                throw GlobalError.authentication(
                    chineseMessage: "刷新令牌已过期或无效",
                    i18nKey: "error.authentication.invalid_refresh_token",
                    level: .notification
                )
            default:
                Logger.shared.error("刷新令牌错误: \(error)")
                throw GlobalError.authentication(
                    chineseMessage: "刷新令牌错误: \(error)",
                    i18nKey: "error.authentication.refresh_token_error",
                    level: .notification
                )
            }
        }

        guard httpResponse.statusCode == 200 else {
            Logger.shared.error("刷新访问令牌失败: HTTP \(httpResponse.statusCode)")
            throw GlobalError.download(
                chineseMessage: "刷新访问令牌失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.download.refresh_token_request_failed",
                level: .notification
            )
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// 基于时间戳检查Token是否过期
    /// - Parameter player: 玩家对象
    /// - Returns: 是否过期
    func isTokenExpiredBasedOnTime(for player: Player) async -> Bool {
        // 正常逻辑：根据 JWT 中的 exp 字段判断是否即将过期（含 5 分钟缓冲）
        return JWTDecoder.isTokenExpiringSoon(player.authAccessToken)
    }

    /// 提示用户重新登录指定玩家
    /// - Parameter player: 需要重新登录的玩家
    func promptForReauth(player: Player) {
        // 显示通知提示用户重新登录
        let notification = GlobalError.authentication(
            chineseMessage: "玩家 \(player.name) 的登录已过期，请在玩家管理中重新登录该账户后再启动游戏",
            i18nKey: "error.authentication.reauth_required",
            level: .notification
        )

        GlobalErrorHandler.shared.handle(notification)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension MinecraftAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // 返回主窗口作为展示锚点
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
