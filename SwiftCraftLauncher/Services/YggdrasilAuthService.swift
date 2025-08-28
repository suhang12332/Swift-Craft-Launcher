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
        let (data, response) = try await URLSession.shared.data(for: request)
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
        let (data, response) = try await URLSession.shared.data(for: request)
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
            // 解析OpenID Connect userinfo响应
            let userInfo = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            // 提取用户信息
            Logger.shared.info(userInfo)
            let sub = userInfo["sub"] as? String ?? ""
            let username = userInfo["preferred_username"] as? String ?? ""

            // 解析Yggdrasil profiles（如果存在）
            var selectedProfile: YggdrasilSelectedProfile?
            if let profiles = userInfo["Yggdrasil.PlayerProfiles"] as? [[String: Any]], let firstProfile = profiles.first {
                let profileId = firstProfile["id"] as? String ?? ""
                let profileName = firstProfile["name"] as? String ?? ""
                selectedProfile = YggdrasilSelectedProfile(
                    id: profileId,
                    name: profileName,
                    legacy: firstProfile["legacy"] as? Bool,
                    demo: firstProfile["demo"] as? Bool
                )
            }

            return YggdrasilProfileResponse(
                id: sub,
                username: username,
                selectedProfile: selectedProfile,
                accessToken: accessToken,
                refreshToken: tokenResponse.refreshToken,
                idToken: tokenResponse.idToken
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
        authState = .notAuthenticated
    }

    // MARK: - 取消认证
    func cancelAuthentication() {
        authState = .notAuthenticated
    }
}
