//
//  YggdrasilAuthService.swift
//  SwiftCraftLauncher
//
//  Created by rayanceking on 2025/8/16.
//

import Foundation
import Combine

/// 通过设备代码流获取 OAuth 访问令牌
/// https://manual.littlesk.in/advanced/oauth2/device-authorization-grant
@MainActor
class YggdrasilAuthService: ObservableObject {
    static let shared = YggdrasilAuthService()

    @Published var authState: AuthenticationState = .notAuthenticated
    @Published var isLoading: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var openURLHandler: ((URL) -> Void)?

    private let clientId = AppConstants.yggdrasilClientId
    private let scope = AppConstants.yggdrasilScope

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
            // 自动打开带 code 的验证页面
            if let verificationUriComplete = deviceCodeResponse.verificationUriComplete, let url = URL(string: verificationUriComplete) {
                Logger.shared.info(String(format: "yggdrasil.auth.complete_verification".localized(), url.absoluteString))
                await MainActor.run {
                    openURLHandler?(url)
                }
            }
            await pollForToken(deviceCode: deviceCodeResponse.deviceCode, interval: deviceCodeResponse.interval)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error(String(format: "yggdrasil.auth.failed".localized(), globalError.chineseMessage))
            GlobalErrorHandler.shared.handle(globalError)
            await MainActor.run {
                isLoading = false
                authState = .error(globalError.localizedDescription)
            }
        }
    }

    // MARK: - 请求设备代码
    private func requestDeviceCodeThrowing() async throws -> YggdrasilDeviceCodeResponse {
        let url = URLConfig.API.Authentication.yggdrasilDeviceCode
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "client_id=\(clientId)&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scope)"
        request.httpBody = body.data(using: .utf8)
        let (data, response) = try await NetworkManager.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "请求设备代码失败: HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)",
                i18nKey: "error.network.device_code_request_failed",
                level: .popup
            )
        }
        do {
            return try JSONDecoder().decode(YggdrasilDeviceCodeResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析设备代码响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.device_code_parse_failed",
                level: .popup
            )
        }
    }

    // MARK: - 轮询检查令牌
    private func pollForToken(deviceCode: String, interval: Int) async {
        let maxAttempts = 60 // 最多尝试次数
        var attempts = 0
        while attempts < maxAttempts {
            do {
                let tokenResponse = try await requestTokenThrowing(deviceCode: deviceCode)
                // 获取用户档案信息
                let profile = try await fetchYggdrasilProfileThrowing(accessToken: tokenResponse.accessToken, tokenResponse: tokenResponse)
                await MainActor.run {
                    isLoading = false
                    authState = .authenticatedYggdrasil(profile: profile)
                }
                return
            } catch let globalError as GlobalError {
                // 检查是否是轮询期间的特殊状态
                if globalError.i18nKey == "error.authentication.authorization_pending" {
                    // 继续轮询，不做任何处理
                } else if globalError.i18nKey == "error.authentication.slow_down" {
                    // 减慢轮询速度
                    try? await Task.sleep(nanoseconds: UInt64((interval + 5) * 1_000_000_000))
                } else {
                    // 其他认证错误，停止轮询
                    Logger.shared.error(String(format: "yggdrasil.auth.polling_failed".localized(), globalError.chineseMessage))
                    GlobalErrorHandler.shared.handle(globalError)
                    await MainActor.run {
                        isLoading = false
                        authState = .error(globalError.localizedDescription)
                    }
                    return
                }
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(String(format: "yggdrasil.auth.polling_failed".localized(), globalError.chineseMessage))
                GlobalErrorHandler.shared.handle(globalError)
                await MainActor.run {
                    isLoading = false
                    authState = .error(globalError.localizedDescription)
                }
                return
            }
            attempts += 1
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        let timeoutError = GlobalError.authentication(
            chineseMessage: "认证超时，请重试",
            i18nKey: "error.authentication.timeout",
            level: .popup
        )
        Logger.shared.error("yggdrasil.auth.timeout".localized())
        GlobalErrorHandler.shared.handle(timeoutError)
        await MainActor.run {
            isLoading = false
            authState = .error(timeoutError.localizedDescription)
        }
    }

    // MARK: - 请求访问令牌
    private func requestTokenThrowing(deviceCode: String) async throws -> YggdrasilTokenResponse {
        let url = URLConfig.API.Authentication.yggdrasilToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=urn:ietf:params:oauth:grant-type:device_code&client_id=\(clientId)&device_code=\(deviceCode)"
        request.httpBody = body.data(using: .utf8)
        let (data, response) = try await NetworkManager.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_http_response",
                level: .popup
            )
        }
        // 检查 OAuth 错误
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let error = errorResponse["error"] as? String {
            switch error {
            case "authorization_pending":
                throw GlobalError.authentication(
                    chineseMessage: "授权待处理，请完成浏览器验证",
                    i18nKey: "error.authentication.authorization_pending",
                    level: .silent  // 轮询期间的正常状态，不需要显示错误
                )
            case "expired_token":
                throw GlobalError.authentication(
                    chineseMessage: "令牌已过期",
                    i18nKey: "error.authentication.expired_token",
                    level: .popup
                )
            case "slow_down":
                throw GlobalError.authentication(
                    chineseMessage: "请求过于频繁，请稍后再试",
                    i18nKey: "error.authentication.slow_down",
                    level: .silent  // 轮询期间的正常状态，不需要显示错误
                )
            default:
                throw GlobalError.authentication(
                    chineseMessage: "认证错误: \(error)",
                    i18nKey: "error.authentication.yggdrasil_general",
                    level: .popup
                )
            }
        }
        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "请求访问令牌失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.network.token_request_failed",
                level: .popup
            )
        }
        do {
            return try JSONDecoder().decode(YggdrasilTokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析访问令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.token_parse_failed",
                level: .popup
            )
        }
    }

    // MARK: - 获取Yggdrasil用户档案
    private func fetchYggdrasilProfileThrowing(accessToken: String, tokenResponse: YggdrasilTokenResponse) async throws -> YggdrasilProfileResponse {
        let url = URLConfig.API.Authentication.yggdrasilUserInfo
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_http_response",
                level: .popup
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "获取用户档案失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.network.yggdrasil_profile_request_failed",
                level: .popup
            )
        }

        do {
            // 使用反序列化解析UserInfo响应
            let userInfo = try JSONDecoder().decode(YggdrasilUserInfo.self, from: data)

            Logger.shared.info("UserInfo: \(userInfo)")

            // 自动获取皮肤信息
            var textures: YggdrasilTextures?
            do {
                textures = try await fetchSkinInfo(for: userInfo.selectedProfile.id)
            }

            return YggdrasilProfileResponse(
                id: userInfo.selectedProfile.id,
                username: userInfo.selectedProfile.name,
                selectedProfile: userInfo.selectedProfile,
                accessToken: accessToken,
                refreshToken: tokenResponse.refreshToken,
                idToken: tokenResponse.idToken,
                textures: textures
            )
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析用户档案响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.yggdrasil_profile_parse_failed",
                level: .popup
            )
        }
    }

    // MARK: - 登出
    func logout() {
        // 重置认证状态
        authState = .notAuthenticated

        // 停止加载状态
        isLoading = false

        Logger.shared.debug("Yggdrasil认证服务已清除所有内存状态")
    }

    // MARK: - 取消认证
    func cancelAuthentication() {
        authState = .notAuthenticated
    }

    // MARK: - 获取皮肤信息
    func fetchSkinInfo(for profileId: String) async throws -> YggdrasilTextures? {
        let url = URLConfig.API.Authentication.yggdrasilProfile(uuid: profileId)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "无效的 HTTP 响应",
                i18nKey: "error.network.invalid_http_response",
                level: .popup
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "获取皮肤信息失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.network.yggdrasil_skin_request_failed",
                level: .popup
            )
        }

        do {
            // 使用反序列化解析皮肤响应
            let skinResponse = try JSONDecoder().decode(YggdrasilSkinResponse.self, from: data)

            // 查找 textures 属性
            guard let texturesProperty = skinResponse.properties.first(where: { $0.name == "textures" }) else {
                Logger.shared.warning("No textures property found in skin response")
                return nil
            }

            // 解码 Base64 编码的纹理数据
            guard let texturesData = Data(base64Encoded: texturesProperty.value) else {
                throw GlobalError.validation(
                    chineseMessage: "无法解码纹理数据",
                    i18nKey: "error.validation.texture_decode_failed",
                    level: .popup
                )
            }

            let textures = try JSONDecoder().decode(YggdrasilTextures.self, from: texturesData)
            return textures

        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析皮肤响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.yggdrasil_skin_parse_failed",
                level: .popup
            )
        }
    }

    // MARK: - 验证并刷新第三方账户Token

    /// 验证并尝试刷新第三方玩家Token（静默版本）
    /// - Parameter player: 玩家对象
    /// - Returns: 验证/刷新后的玩家对象，如果失败返回nil
    func validateAndRefreshPlayerToken(for player: Player) async -> Player? {
        do {
            return try await validateAndRefreshPlayerTokenThrowing(for: player)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("验证/刷新第三方玩家Token失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return nil
        }
    }

    /// 验证并尝试刷新第三方玩家Token（抛出异常版本）
    /// - Parameter player: 玩家对象
    /// - Returns: 验证/刷新后的玩家对象
    /// - Throws: GlobalError 当操作失败时
    func validateAndRefreshPlayerTokenThrowing(for player: Player) async throws -> Player {
        Logger.shared.info("验证第三方账户 \(player.name) 的Token")

        // 如果没有访问令牌，抛出错误要求重新登录
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "第三方账户 \(player.name) 缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.third_party_missing_token",
                level: .notification
            )
        }

        // 首先尝试验证当前token是否有效
        let isTokenValid = await validateThirdPartyToken(player.authAccessToken)

        if isTokenValid {
            Logger.shared.info("第三方账户 \(player.name) 的Token仍然有效")
            return player
        }

        Logger.shared.info("第三方账户 \(player.name) 的Token已过期，尝试刷新")

        // Token无效，尝试使用refresh token刷新
        guard !player.authRefreshToken.isEmpty else {
            Logger.shared.warning("第三方账户 \(player.name) 缺少刷新令牌，需要重新登录")
            throw GlobalError.authentication(
                chineseMessage: "第三方账户 \(player.name) 的登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.third_party_token_expired_relogin_required",
                level: .popup
            )
        }

        do {
            // 使用refresh token刷新访问令牌
            let refreshedTokens = try await refreshThirdPartyTokenThrowing(refreshToken: player.authRefreshToken)

            // 获取更新后的用户档案信息
            let updatedProfile = try await fetchYggdrasilProfileThrowing(accessToken: refreshedTokens.accessToken, tokenResponse: refreshedTokens)

            // 创建更新后的玩家对象
            let updatedPlayer = try Player(
                name: player.name,
                uuid: player.id,
                isOnlineAccount: player.isOnlineAccount,
                avatarName: updatedProfile.textures?.textures.SKIN?.url ?? player.avatarName,
                authXuid: player.authXuid,
                authAccessToken: refreshedTokens.accessToken,
                authRefreshToken: refreshedTokens.refreshToken ?? player.authRefreshToken,
                tokenExpiresAt: Calendar.current.date(byAdding: .second, value: refreshedTokens.expiresIn, to: Date()),
                createdAt: player.createdAt,
                lastPlayed: player.lastPlayed,
                isCurrent: player.isCurrent,
                gameRecords: player.gameRecords
            )

            Logger.shared.info("成功刷新第三方账户 \(player.name) 的Token")
            return updatedPlayer

        } catch {
            Logger.shared.warning("刷新第三方账户 \(player.name) 的Token失败: \(error.localizedDescription)")
            throw GlobalError.authentication(
                chineseMessage: "第三方账户 \(player.name) 的登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.third_party_token_expired_relogin_required",
                level: .popup
            )
        }
    }

    /// 验证第三方访问令牌是否有效
    /// - Parameter accessToken: 访问令牌
    /// - Returns: 是否有效
    private func validateThirdPartyToken(_ accessToken: String) async -> Bool {
        do {
            let url = URLConfig.API.Authentication.yggdrasilUserInfo
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            return httpResponse.statusCode == 200
        } catch {
            Logger.shared.debug("第三方Token验证失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 使用refresh token刷新第三方访问令牌（抛出异常版本）
    /// - Parameter refreshToken: 刷新令牌
    /// - Returns: 新的令牌响应
    /// - Throws: GlobalError 当刷新失败时
    private func refreshThirdPartyTokenThrowing(refreshToken: String) async throws -> YggdrasilTokenResponse {
        let url = URLConfig.API.Authentication.yggdrasilToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "刷新第三方访问令牌失败: 无效的 HTTP 响应",
                i18nKey: "error.download.third_party_refresh_token_request_failed",
                level: .notification
            )
        }

        // 检查OAuth错误
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorResponse["error"] as? String {
            throw GlobalError.authentication(
                chineseMessage: "刷新第三方令牌失败: \(error)",
                i18nKey: "error.authentication.third_party_refresh_failed",
                level: .popup
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "刷新第三方访问令牌失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.network.third_party_refresh_token_failed",
                level: .popup
            )
        }

        do {
            return try JSONDecoder().decode(YggdrasilTokenResponse.self, from: data)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析刷新后的第三方令牌响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.third_party_refresh_token_parse_failed",
                level: .popup
            )
        }
    }
}

