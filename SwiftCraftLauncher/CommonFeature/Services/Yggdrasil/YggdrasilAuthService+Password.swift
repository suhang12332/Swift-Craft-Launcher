//
//  YggdrasilAuthService+Password.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Yggdrasil classic authserver 用户名密码登录与令牌续期状态机。
///
/// 持久化登录策略(classic 协议没有 refresh_token,记住的密码即续期凭据):
/// ① `validate`(幂等,有效直接用)→ ② `refresh`(吊销旧令牌并颁发新令牌)
/// → ③ 失败时若有记住的密码则静默重登,密码已改则清除记住值并要求重输;
/// 未记住密码则要求重新登录。
extension YggdrasilAuthService {
    /// 密码登录续期结果。
    struct YggdrasilRenewalOutcome: Equatable {
        let credential: AccountCredential
        /// 服务器侧角色改名后的新名称;`nil` 表示未变化。
        let updatedName: String?
    }

    /// 按玩家维度单飞:authenticate/refresh 均有吊销旧令牌的副作用,
    /// 并发重复触发会导致刚拿到的新令牌立即被下一次刷新吊销。
    private static let renewalTasksLock = OSAllocatedUnfairLock<[String: Task<YggdrasilRenewalOutcome, Error>]>(initialState: [:])

    // MARK: - 登录

    /// 用户名密码登录(自定义 Yggdrasil 服务器)。
    @MainActor
    func startPasswordAuthentication(username: String, password: String, rememberPassword: Bool) async {
        authenticatedProfiles = []
        passwordTokenNeedsBinding = false

        guard let server = currentServer, server.isPasswordLogin,
              let apiRoot = server.passwordAPIRoot else {
            authState = .error("yggdrasil.error.server_not_selected".localized())
            return
        }

        isLoading = true
        authState = .processing

        do {
            let clientToken = YggdrasilClientTokenProvider.currentToken()
            let response = try await authServerClient.authenticate(
                username: username,
                password: password,
                clientToken: clientToken,
                apiRoot: apiRoot,
            )

            let makeProfile: (String, String) -> YggdrasilProfile = { id, name in
                YggdrasilProfile(
                    id: id,
                    name: name,
                    skins: [],
                    capes: nil,
                    accessToken: response.accessToken,
                    refreshToken: "",
                    serverBaseURL: server.baseURL.absoluteString,
                    authMethod: .yggdrasilPassword,
                    clientToken: response.clientToken,
                    loginUsername: username,
                    savedPassword: rememberPassword ? password : nil,
                )
            }

            // 服务器已自动绑定角色(单角色服务器常见行为)
            if let selected = response.selectedProfile {
                let profile = makeProfile(selected.id, selected.name)
                authenticatedProfiles = [profile]
                isLoading = false
                authState = .authenticated(profile: profile)
                return
            }

            // 多角色:展示列表供用户选择,选择后绑定
            let candidates = (response.availableProfiles ?? []).map { makeProfile($0.id, $0.name) }
            guard !candidates.isEmpty else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.yggdrasil_no_profiles",
                    level: .notification,
                    message: "Yggdrasil returned 0 player profiles for server \(server.baseURL.absoluteString)",
                )
            }
            authenticatedProfiles = candidates
            passwordTokenNeedsBinding = true
            isLoading = false
            authState = .authenticated(profile: candidates[0])
        } catch {
            isLoading = false
            authState = .error(Self.localizePasswordFailure(error))
        }
    }

    /// classic authserver 错误的用户可读文案。
    static func localizePasswordFailure(_ error: Error) -> String {
        switch error {
        case YggdrasilAuthServerError.invalidCredentials:
            return "yggdrasil.password.error.invalid_credentials".localized()
        case YggdrasilAuthServerError.invalidToken:
            return "yggdrasil.password.error.invalid_token".localized()
        case let YggdrasilAuthServerError.rejected(message):
            return message
        default:
            return GlobalError.from(error).localizedDescription
        }
    }

    // MARK: - 启动前续期状态机

    /// 确保启动游戏前凭据可用,必要时刷新或静默重登。
    ///
    /// - Parameters:
    ///   - credential: 当前统一凭据。
    ///   - serverBaseURL: 玩家档案关联的服务器地址。
    /// - Returns: 续期后的凭据与可能的角色改名结果。
    /// - Throws: 令牌彻底失效且无法静默恢复时抛出(popup 级)。
    func ensureFreshYggdrasilCredential(
        _ credential: AccountCredential,
        serverBaseURL: String,
    ) async throws -> YggdrasilRenewalOutcome {
        let key = AccountCredential.keychainAccount(userId: credential.userId, authMethod: credential.authMethod)

        let (task, _) = Self.renewalTasksLock.withLock { tasks -> (Task<YggdrasilRenewalOutcome, Error>, Bool) in
            if let existing = tasks[key] {
                return (existing, false)
            }
            let task = Task { [weak self] in
                guard let self else {
                    throw YggdrasilAuthServerError.rejected("Service released")
                }
                return try await self.doEnsureFreshYggdrasilCredential(credential, serverBaseURL: serverBaseURL)
            }
            tasks[key] = task
            return (task, true)
        }

        defer {
            _ = Self.renewalTasksLock.withLock { tasks in
                tasks.removeValue(forKey: key)
            }
        }

        return try await task.value
    }

    private func doEnsureFreshYggdrasilCredential(
        _ credential: AccountCredential,
        serverBaseURL: String,
    ) async throws -> YggdrasilRenewalOutcome {
        guard let server = YggdrasilServerRegistry.server(for: serverBaseURL) else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.error.server_not_selected",
                level: .notification,
                message: "Unknown Yggdrasil server: \(serverBaseURL)",
            )
        }

        switch credential.authMethod {
        case .yggdrasilOAuth:
            // OAuth 线保持历史行为:每次启动用 refresh_token 刷新
            let response = try await refreshOAuthToken(
                refreshToken: credential.oauthRefreshToken ?? "",
                server: server,
            )
            var updated = credential
            updated.accessToken = response.accessToken
            updated.renewalSecret = response.refreshToken ?? credential.renewalSecret
            return YggdrasilRenewalOutcome(credential: updated, updatedName: nil)

        case .yggdrasilPassword:
            return try await ensureFreshPasswordCredential(credential, server: server)

        default:
            return YggdrasilRenewalOutcome(credential: credential, updatedName: nil)
        }
    }

    /// 密码登录续期状态机。
    private func ensureFreshPasswordCredential(
        _ credential: AccountCredential,
        server: YggdrasilServerConfig,
    ) async throws -> YggdrasilRenewalOutcome {
        guard let apiRoot = server.passwordAPIRoot else {
            throw GlobalError.validation(
                i18nKey: "yggdrasil.error.server_not_selected",
                level: .notification,
                message: "Password API root missing for server \(server.baseURL.absoluteString)",
            )
        }
        let clientToken = credential.clientToken ?? YggdrasilClientTokenProvider.currentToken()

        // ① validate:幂等且无副作用,令牌有效直接使用
        if await authServerClient.validate(accessToken: credential.accessToken, clientToken: clientToken, apiRoot: apiRoot) {
            return YggdrasilRenewalOutcome(credential: credential, updatedName: nil)
        }

        // ② refresh:吊销旧令牌并颁发新令牌(失败时旧令牌仍有效,可安全重试)
        do {
            let response = try await authServerClient.refresh(
                accessToken: credential.accessToken,
                clientToken: clientToken,
                selectedProfileId: nil,
                apiRoot: apiRoot,
            )
            var updated = credential
            updated.accessToken = response.accessToken
            updated.clientToken = response.clientToken
            return YggdrasilRenewalOutcome(credential: updated, updatedName: response.selectedProfile?.name)
        } catch {
            AppLog.common.info("Yggdrasil token refresh failed (\(server.name)), falling back to password re-login")
        }

        // ③ 静默重登:需要同时持有记住的密码与登录名
        guard let password = credential.savedPassword, let username = credential.loginUsername else {
            throw GlobalError.authentication(
                i18nKey: "yggdrasil.error.token_expired_relogin",
                level: .popup,
                message: "Yggdrasil token expired and no saved password for user \(credential.userId)",
            )
        }

        do {
            let response = try await authServerClient.authenticate(
                username: username,
                password: password,
                clientToken: clientToken,
                apiRoot: apiRoot,
            )

            // 确认原角色仍然属于该账号(可能被删除或换绑)
            let profiles = response.availableProfiles ?? []
            let boundProfile = response.selectedProfile ?? profiles.first { $0.id == credential.userId }
            guard boundProfile != nil || profiles.isEmpty else {
                throw GlobalError.authentication(
                    i18nKey: "yggdrasil.error.profile_missing",
                    level: .popup,
                    message: "Profile \(credential.userId) no longer exists on \(server.name)",
                )
            }

            var updated = credential
            updated.accessToken = response.accessToken
            updated.clientToken = response.clientToken
            AppLog.common.info("Yggdrasil password auto re-login succeeded for user \(credential.userId)")
            return YggdrasilRenewalOutcome(credential: updated, updatedName: boundProfile?.name)
        } catch YggdrasilAuthServerError.invalidCredentials {
            // 密码已改:记住的密码不再有价值,清除后要求用户重新登录
            var cleared = credential
            cleared.renewalSecret = nil
            _ = DIContainer.shared.ui.playerDataManager.saveCredential(cleared)
            throw GlobalError.authentication(
                i18nKey: "yggdrasil.error.password_changed",
                level: .popup,
                message: "Saved password rejected for user \(credential.userId)",
            )
        }
    }
}
