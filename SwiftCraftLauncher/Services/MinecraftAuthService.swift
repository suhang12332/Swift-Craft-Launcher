import Foundation
import Combine
import SwiftUI
// swiftlint:disable:next type_body_length
class MinecraftAuthService: ObservableObject {
    static let shared = MinecraftAuthService()

    @Published var authState: AuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var openURLHandler: ((URL) -> Void)?

    private let clientId = AppConstants.minecraftClientId
    private let scope = AppConstants.minecraftScope

    private init() {}

    // MARK: - 认证流程
    func startAuthentication() async {
        await MainActor.run {
            isLoading = true
            authState = .requestingCode
        }

        do {
            let deviceCodeResponse = try await requestDeviceCodeThrowing()

            await MainActor.run {
                authState = .waitingForUser(
                    userCode: deviceCodeResponse.userCode,
                    verificationUri: deviceCodeResponse.verificationUri
                )
            }

            // 自动打开验证页面
            if let url = URL(string: deviceCodeResponse.verificationUri) {
                await MainActor.run {
                    openURLHandler?(url)
                }
            }

            // 轮询检查认证状态
            await pollForToken(deviceCode: deviceCodeResponse.deviceCode, interval: deviceCodeResponse.interval)
        } catch {
            let globalError = GlobalError.from(error)
            await MainActor.run {
                isLoading = false
                authState = .error(globalError.chineseMessage)
            }
        }
    }

    // MARK: - 请求设备代码（静默版本）
    private func requestDeviceCode() async -> DeviceCodeResponse? {
        do {
            return try await requestDeviceCodeThrowing()
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("请求设备代码失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    // MARK: - 请求设备代码（抛出异常版本）
    private func requestDeviceCodeThrowing() async throws -> DeviceCodeResponse {
        let url = URLConfig.API.Authentication.deviceCode
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await NetworkManager.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "请求设备代码失败: HTTP \(response)",
                i18nKey: "error.download.device_code_request_failed",
                level: .notification
            )
        }

        do {
            return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析设备代码响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.device_code_parse_failed",
                level: .notification
            )
        }
    }

    // MARK: - 轮询检查令牌
    private func pollForToken(deviceCode: String, interval: Int) async {
        let maxAttempts = 60
        var attempts = 0

        while attempts < maxAttempts {
            do {
                let tokenResponse = try await requestTokenThrowing(deviceCode: deviceCode)

                await MainActor.run {
                    authState = .authenticating
                }

                // 获取完整的认证链
                let xboxToken = try await getXboxLiveTokenThrowing(accessToken: tokenResponse.accessToken)
                let minecraftToken = try await getMinecraftTokenThrowing(xboxToken: xboxToken.token, uhs: xboxToken.displayClaims.xui.first?.uhs ?? "")
                let profile = try await getMinecraftProfileThrowing(accessToken: minecraftToken, authXuid: xboxToken.displayClaims.xui.first?.uhs ?? "", refreshToken: tokenResponse.refreshToken ?? "")

                await MainActor.run {
                    isLoading = false
                    authState = .authenticated(profile: profile)
                }

                return
            } catch let error as GlobalError {
                switch error {
                case .authentication( _, let i18nKey, _) where i18nKey == "error.authentication.authorization_pending":
                    break // 继续轮询
                case .authentication( _, let i18nKey, _) where i18nKey == "error.authentication.slow_down":
                    try? await Task.sleep(nanoseconds: UInt64((interval + 5) * 1_000_000_000))
                default:
                    await MainActor.run {
                        isLoading = false
                        authState = .error(error.chineseMessage)
                    }
                    return
                }
            } catch {
                let globalError = GlobalError.from(error)
                await MainActor.run {
                    isLoading = false
                    authState = .error(globalError.chineseMessage)
                }
                return
            }

            attempts += 1
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        await MainActor.run {
            isLoading = false
            authState = .error("认证超时，请重试")
        }
    }

    // MARK: - 请求访问令牌（静默版本）
    private func requestToken(deviceCode: String) async -> TokenResponse? {
        do {
            return try await requestTokenThrowing(deviceCode: deviceCode)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("请求访问令牌失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    // MARK: - 请求访问令牌（抛出异常版本）
    private func requestTokenThrowing(deviceCode: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientId)&device_code=\(deviceCode)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "请求访问令牌失败: 无效的 HTTP 响应",
                i18nKey: "error.download.access_token_request_failed",
                level: .notification
            )
        }

        // 检查OAuth错误
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorResponse["error"] as? String {
            switch error {
            case "authorization_pending":
                throw GlobalError.authentication(
                    chineseMessage: "授权待处理，请完成浏览器验证",
                    i18nKey: "error.authentication.authorization_pending",
                    level: .notification
                )
            case "authorization_declined":
                throw GlobalError.authentication(
                    chineseMessage: "用户拒绝了授权",
                    i18nKey: "error.authentication.authorization_declined",
                    level: .notification
                )
            case "expired_token":
                throw GlobalError.authentication(
                    chineseMessage: "令牌已过期",
                    i18nKey: "error.authentication.expired_token",
                    level: .notification
                )
            case "invalid_device_code":
                throw GlobalError.authentication(
                    chineseMessage: "无效的设备代码",
                    i18nKey: "error.authentication.invalid_device_code",
                    level: .notification
                )
            case "slow_down":
                throw GlobalError.authentication(
                    chineseMessage: "请求过于频繁，请稍后再试",
                    i18nKey: "error.authentication.slow_down",
                    level: .notification
                )
            default:
                throw GlobalError.authentication(
                    chineseMessage: "认证错误: \(error)",
                    i18nKey: "error.authentication.general_error",
                    level: .notification
                )
            }
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "请求访问令牌失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.download.access_token_request_failed",
                level: .notification
            )
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析访问令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.access_token_parse_failed",
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

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 Xbox Live 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xbox_live_request_serialize_failed",
                level: .notification
            )
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Xbox Live 令牌失败: HTTP \(response)",
                i18nKey: "error.download.xbox_live_token_failed",
                level: .notification
            )
        }

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

        do {
            xstsRequest.httpBody = try JSONSerialization.data(withJSONObject: xstsBody)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 XSTS 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.xsts_request_serialize_failed",
                level: .notification
            )
        }
        
        let (xstsData, xstsResponse) = try await URLSession.shared.data(for: xstsRequest)
        
        guard let xstsHttpResponse = xstsResponse as? HTTPURLResponse, xstsHttpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 XSTS 令牌失败: HTTP \(xstsResponse)",
                i18nKey: "error.download.xsts_token_failed",
                level: .notification
            )
        }

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
        let minecraftUrl = URLConfig.API.Authentication.minecraftLogin
        var minecraftRequest = URLRequest(url: minecraftUrl)
        minecraftRequest.httpMethod = "POST"
        minecraftRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let minecraftBody: [String: Any] = [
            "identityToken": "XBL3.0 x=\(uhs);\(xstsTokenResponse.token)"
        ]

        do {
            minecraftRequest.httpBody = try JSONSerialization.data(withJSONObject: minecraftBody)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "序列化 Minecraft 认证请求失败: \(error.localizedDescription)",
                i18nKey: "error.validation.minecraft_request_serialize_failed",
                level: .notification
            )
        }
        
        let (minecraftData, minecraftResponse) = try await URLSession.shared.data(for: minecraftRequest)
        
        guard let minecraftHttpResponse = minecraftResponse as? HTTPURLResponse, minecraftHttpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Minecraft 访问令牌失败: HTTP \(minecraftResponse)",
                i18nKey: "error.download.minecraft_token_failed",
                level: .notification
            )
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

        // MARK: - 获取Minecraft用户资料（静默版本）
    private func getMinecraftProfile(accessToken: String, authXuid: String) async -> MinecraftProfileResponse? {
        do {
            return try await getMinecraftProfileThrowing(accessToken: accessToken, authXuid: authXuid)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取 Minecraft 用户资料失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    // MARK: - 获取Minecraft用户资料（抛出异常版本）
    private func getMinecraftProfileThrowing(accessToken: String, authXuid: String, refreshToken: String = "") async throws -> MinecraftProfileResponse {
        let url = URLConfig.API.Authentication.minecraftProfile
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "获取 Minecraft 用户资料失败: HTTP \(response)",
                i18nKey: "error.download.minecraft_profile_failed",
                level: .notification
            )
        }

        do {
            let profile = try JSONDecoder().decode(MinecraftProfileResponse.self, from: data)
            // 由于 accessToken、authXuid 和 refreshToken 不是从 API 响应中获取的，我们需要手动设置
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

    // MARK: - 登出
    func logout() {
        authState = .notAuthenticated
    }

    // MARK: - 取消认证
    func cancelAuthentication() {
        authState = .notAuthenticated
    }

    // MARK: - Token验证和刷新相关方法

    /// 验证并尝试刷新玩家Token
    /// - Parameter player: 玩家对象
    /// - Returns: 验证/刷新后的玩家对象，如果失败返回nil
    func validateAndRefreshPlayerToken(for player: Player) async -> Player? {
        do {
            return try await validateAndRefreshPlayerTokenThrowing(for: player)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("验证/刷新玩家Token失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 验证并尝试刷新玩家Token（抛出异常版本）
    /// - Parameter player: 玩家对象
    /// - Returns: 验证/刷新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func validateAndRefreshPlayerTokenThrowing(for player: Player) async throws -> Player {
        // 如果是离线账户但没有访问令牌，直接返回（纯离线用户）
        if !player.isOnlineAccount && player.authAccessToken.isEmpty {
            return player
        }

        // 如果是离线账户但有访问令牌，说明是第三方账户，需要验证token
        if !player.isOnlineAccount && !player.authAccessToken.isEmpty {
            Logger.shared.info("验证第三方账户 \(player.name) 的Token")
            return try await YggdrasilAuthService.shared.validateAndRefreshPlayerTokenThrowing(for: player)
        }

        // 如果没有访问令牌，抛出错误要求重新登录
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "玩家 \(player.name) 缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .notification
            )
        }

        Logger.shared.info("验证玩家 \(player.name) 的Token")

        // 首先尝试验证当前token是否有效
        let isTokenValid = await validateToken(player.authAccessToken, authXuid: player.authXuid)

        if isTokenValid {
            Logger.shared.info("玩家 \(player.name) 的Token仍然有效")
            return player
        }

        Logger.shared.info("玩家 \(player.name) 的Token已过期，尝试刷新")

        // Token无效，尝试使用refresh token刷新
        guard !player.authRefreshToken.isEmpty else {
            Logger.shared.warning("玩家 \(player.name) 缺少刷新令牌，需要重新登录")
            throw GlobalError.authentication(
                chineseMessage: "玩家 \(player.name) 的登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.token_expired_relogin_required",
                level: .popup
            )
        }

        do {
            // 使用refresh token刷新访问令牌
            let refreshedTokens = try await refreshTokenThrowing(refreshToken: player.authRefreshToken)

            // 使用新的访问令牌获取完整的认证链
            let xboxToken = try await getXboxLiveTokenThrowing(accessToken: refreshedTokens.accessToken)
            let minecraftToken = try await getMinecraftTokenThrowing(xboxToken: xboxToken.token, uhs: xboxToken.displayClaims.xui.first?.uhs ?? "")

            // 创建更新后的玩家对象
            let updatedPlayer = try Player(
                name: player.name,
                uuid: player.id,
                isOnlineAccount: player.isOnlineAccount,
                avatarName: player.avatarName,
                authXuid: xboxToken.displayClaims.xui.first?.uhs ?? player.authXuid,
                authAccessToken: minecraftToken,
                authRefreshToken: refreshedTokens.refreshToken ?? player.authRefreshToken,
                tokenExpiresAt: Calendar.current.date(byAdding: .second, value: refreshedTokens.expiresIn, to: Date()),
                createdAt: player.createdAt,
                lastPlayed: player.lastPlayed,
                isCurrent: player.isCurrent,
                gameRecords: player.gameRecords
            )

            Logger.shared.info("成功刷新玩家 \(player.name) 的Token")

            return updatedPlayer
        } catch {
            Logger.shared.warning("刷新玩家 \(player.name) 的Token失败: \(error.localizedDescription)")
            throw GlobalError.authentication(
                chineseMessage: "玩家 \(player.name) 的登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.token_expired_relogin_required",
                level: .popup
            )
        }
    }

    /// 使用refresh token刷新访问令牌（抛出异常版本）
    /// - Parameter refreshToken: 刷新令牌
    /// - Returns: 新的令牌响应
    /// - Throws: GlobalError 当刷新失败时
    private func refreshTokenThrowing(refreshToken: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "刷新访问令牌失败: 无效的 HTTP 响应",
                i18nKey: "error.download.refresh_token_request_failed",
                level: .notification
            )
        }

        // 检查OAuth错误
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorResponse["error"] as? String {
            switch error {
            case "invalid_grant":
                throw GlobalError.authentication(
                    chineseMessage: "刷新令牌已过期或无效",
                    i18nKey: "error.authentication.invalid_refresh_token",
                    level: .notification
                )
            default:
                throw GlobalError.authentication(
                    chineseMessage: "刷新令牌错误: \(error)",
                    i18nKey: "error.authentication.refresh_token_error",
                    level: .notification
                )
            }
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.download(
                chineseMessage: "刷新访问令牌失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.download.refresh_token_request_failed",
                level: .notification
            )
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析刷新令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.refresh_token_parse_failed",
                level: .notification
            )
        }
    }

    /// 验证Token是否有效
    /// - Parameters:
    ///   - accessToken: 访问令牌
    ///   - authXuid: Xbox用户ID
    /// - Returns: 是否有效
    func validateToken(_ accessToken: String, authXuid: String) async -> Bool {
        do {
            _ = try await getMinecraftProfileThrowing(accessToken: accessToken, authXuid: authXuid)
            return true
        } catch {
            Logger.shared.debug("Token验证失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 提示用户重新登录指定玩家
    /// - Parameter player: 需要重新登录的玩家
    func promptForReauth(player: Player) {
        Logger.shared.info("提示用户为玩家 \(player.name) 重新登录")

        // 显示通知提示用户重新登录
        let notification = GlobalError.authentication(
            chineseMessage: "玩家 \(player.name) 的登录已过期，请在玩家管理中重新登录该账户后再启动游戏",
            i18nKey: "error.authentication.reauth_required",
            level: .notification
        )

        GlobalErrorHandler.shared.handle(notification)
    }

    // MARK: - 清理认证状态和内存信息
    func clearAuthenticationData() {
        // 重置认证状态到初始状态
        authState = .notAuthenticated

        // 停止加载状态
        isLoading = false

        // 清理 Combine 订阅，释放内存
        cancellables.removeAll()

        // 清理 URL 处理器回调，避免内存泄漏
        openURLHandler = nil

        Logger.shared.debug("Microsoft 认证数据已清理，下次添加账户将显示初始状态")
    }
}
