//
//  YggdrasilAuthService+Password.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import os

/// Username/password login against Yggdrasil classic authservers and the token
/// renewal state machine used before launching the game.
///
/// The classic protocol has no refresh_token, so a remembered password acts as the
/// long-lived renewal secret:
/// 1. `validate` (idempotent) — use the token as-is when it is still valid.
/// 2. `refresh` — revokes the old token and issues a new one.
/// 3. Silent re-login with the remembered password. If the server rejects that
///    password it is cleared and the user must sign in again; without a remembered
///    password the user must sign in again as well.
extension YggdrasilAuthService {
    /// Recoverable renewal failures carrying the data the caller needs to persist.
    enum YggdrasilRenewalError: Error {
        /// The server rejected the remembered password (it was changed). The caller is
        /// responsible for storing `clearedProfile`, which no longer holds the password.
        case passwordRejected(clearedProfile: YggdrasilProfile)
    }

    /// Per-player single flight: both `authenticate` and `refresh` revoke the previous
    /// token, so concurrent renewals would immediately invalidate each other's tokens.
    private static let renewalTasksLock = OSAllocatedUnfairLock<[String: Task<YggdrasilProfile, Error>]>(initialState: [:])

    /// Signs in to the selected custom Yggdrasil server with a username and password.
    @MainActor
    func startPasswordAuthentication(username: String, password: String, rememberPassword: Bool) async {
        authenticatedProfiles = []
        passwordTokenNeedsBinding = false

        guard let server = currentServer, let apiRoot = server.passwordAPIRoot else {
            authState = .error("yggdrasil.error.server_not_selected".localized())
            return
        }

        isLoading = true
        authState = .processing

        do {
            let response = try await authServerClient.authenticate(
                username: username,
                password: password,
                clientToken: YggdrasilClientTokenProvider.currentToken(),
                apiRoot: apiRoot,
            )

            let makeProfile: (YggdrasilAuthProfile) -> YggdrasilProfile = { authProfile in
                YggdrasilProfile(
                    id: authProfile.id,
                    name: authProfile.name,
                    skins: [],
                    capes: nil,
                    accessToken: response.accessToken,
                    refreshToken: "",
                    serverBaseURL: server.baseURL.absoluteString,
                    loginMethod: .password,
                    clientToken: response.clientToken,
                    loginUsername: username,
                    savedPassword: rememberPassword ? password : nil,
                )
            }

            // The authenticate response carries no skin data; fetch it from the
            // sessionserver on a best-effort basis to show the avatar.
            let hydrateSkin: (YggdrasilProfile) async -> YggdrasilProfile = { [authServerClient] profile in
                let detail = try? await authServerClient.fetchSessionProfile(uuid: profile.id, apiRoot: apiRoot)
                return profile.withSkinURL(detail?.skinURL)
            }

            // The server already bound a profile (common for single-profile accounts).
            if let selected = response.selectedProfile {
                let profile = await hydrateSkin(makeProfile(selected))
                authenticatedProfiles = [profile]
                isLoading = false
                authState = .authenticated(profile: profile)
                return
            }

            // Several profiles: let the user pick one; the token is bound to it when the
            // account is added (see `prepareProfileForAdding`).
            var candidates: [YggdrasilProfile] = []
            for authProfile in response.availableProfiles ?? [] {
                await candidates.append(hydrateSkin(makeProfile(authProfile)))
            }
            guard let first = candidates.first else {
                throw GlobalError.validation(
                    i18nKey: "error.validation.yggdrasil_no_profiles",
                    level: .notification,
                    message: "Yggdrasil returned 0 player profiles for server \(server.baseURL.absoluteString)",
                )
            }
            authenticatedProfiles = candidates
            passwordTokenNeedsBinding = true
            isLoading = false
            authState = .authenticated(profile: first)
        } catch {
            isLoading = false
            authState = .error(Self.localizePasswordFailure(error))
        }
    }

    /// User-facing message for classic authserver failures.
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

    /// Makes sure a password-login profile has a usable token before launching,
    /// refreshing or silently re-logging in when necessary.
    ///
    /// - Parameter profile: The stored profile from ``OfflineUserServerMap``.
    /// - Returns: The renewed profile; `name` reflects a rename on the server side.
    /// - Throws: ``YggdrasilRenewalError`` or a popup-level error when the token cannot
    ///   be recovered silently.
    func ensureFreshPasswordProfile(_ profile: YggdrasilProfile) async throws -> YggdrasilProfile {
        let key = profile.id
        let task = Self.renewalTasksLock.withLock { tasks -> Task<YggdrasilProfile, Error> in
            if let existing = tasks[key] {
                return existing
            }
            let task = Task { [weak self] in
                guard let self else {
                    throw YggdrasilAuthServerError.rejected("Service released")
                }
                guard let apiRoot = YggdrasilServerRegistry.server(for: profile.serverBaseURL)?.passwordAPIRoot else {
                    throw GlobalError.validation(
                        i18nKey: "yggdrasil.error.server_not_selected",
                        level: .notification,
                        message: "Unknown Yggdrasil password server: \(profile.serverBaseURL)",
                    )
                }
                return try await renewPasswordProfile(profile, apiRoot: apiRoot)
            }
            tasks[key] = task
            return task
        }

        defer {
            // Only remove our own task; a newer renewal may already occupy the slot.
            Self.renewalTasksLock.withLock { tasks in
                if tasks[key] == task {
                    tasks.removeValue(forKey: key)
                }
            }
        }

        return try await task.value
    }

    /// The password renewal state machine (internal so tests can inject a stub client).
    func renewPasswordProfile(_ profile: YggdrasilProfile, apiRoot: URL) async throws -> YggdrasilProfile {
        let clientToken = profile.clientToken ?? YggdrasilClientTokenProvider.currentToken()

        // 1. validate: idempotent and side-effect free.
        if await authServerClient.validate(accessToken: profile.accessToken, clientToken: clientToken, apiRoot: apiRoot) {
            return profile
        }

        // 2. refresh: revokes the old token and issues a new one. A failed refresh
        //    leaves the old token untouched, so falling through is safe.
        do {
            let response = try await authServerClient.refresh(
                accessToken: profile.accessToken,
                clientToken: clientToken,
                selectedProfileId: nil,
                apiRoot: apiRoot,
            )
            var renewed = profile
            renewed.accessToken = response.accessToken
            renewed.clientToken = response.clientToken
            if let name = response.selectedProfile?.name, !name.isEmpty {
                renewed.name = name
            }
            return renewed
        } catch {
            AppLog.common.info("Yggdrasil token refresh failed for \(profile.serverBaseURL), trying password re-login")
        }

        // 3. Silent re-login: requires both the remembered password and the login name.
        guard let password = profile.savedPassword, let username = profile.loginUsername else {
            throw GlobalError.authentication(
                i18nKey: "yggdrasil.error.token_expired_relogin",
                level: .popup,
                message: "Yggdrasil token expired and no saved password for user \(profile.id)",
            )
        }

        do {
            let response = try await authServerClient.authenticate(
                username: username,
                password: password,
                clientToken: clientToken,
                apiRoot: apiRoot,
            )

            // Make sure the original profile still belongs to this account.
            let available = response.availableProfiles ?? []
            let boundProfile = response.selectedProfile ?? available.first { $0.id == profile.id }
            guard boundProfile != nil || available.isEmpty else {
                throw GlobalError.authentication(
                    i18nKey: "yggdrasil.error.profile_missing",
                    level: .popup,
                    message: "Profile \(profile.id) no longer exists on \(profile.serverBaseURL)",
                )
            }

            var renewed = profile
            renewed.accessToken = response.accessToken
            renewed.clientToken = response.clientToken
            if let name = boundProfile?.name, !name.isEmpty {
                renewed.name = name
            }
            AppLog.common.info("Yggdrasil password auto re-login succeeded for user \(profile.id)")
            return renewed
        } catch YggdrasilAuthServerError.invalidCredentials {
            // The password was changed, so the remembered value is useless now.
            var cleared = profile
            cleared.savedPassword = nil
            throw YggdrasilRenewalError.passwordRejected(clearedProfile: cleared)
        }
    }
}
