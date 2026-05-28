import Foundation

extension MinecraftAuthService {

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

    func validateAndRefreshPlayerTokenThrowing(for player: Player) async throws -> Player {
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .notification
            )
        }

        let isTokenExpired = await isTokenExpiredBasedOnTime(for: player)

        if !isTokenExpired {
            if !RoutineAuthDiagnosticsLogContext.shouldSuppressRoutineDebugLogs {
                Logger.shared.debug("玩家 \(player.name) 的Token尚未过期，无需刷新")
            }
            return player
        }

        Logger.shared.info("玩家 \(player.name) 的Token已过期，尝试刷新")

        guard !player.authRefreshToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "登录已过期，请重新登录该账户",
                i18nKey: "error.authentication.token_expired_relogin_required",
                level: .popup
            )
        }

        let refreshedTokens = try await refreshTokenThrowing(refreshToken: player.authRefreshToken)

        let xboxToken = try await getXboxLiveTokenThrowing(accessToken: refreshedTokens.accessToken)
        let minecraftToken = try await getMinecraftTokenThrowing(
            xboxToken: xboxToken.token,
            uhs: xboxToken.displayClaims.xui.first?.uhs ?? ""
        )

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
            updatedCredential = AuthCredential(
                userId: player.id,
                accessToken: minecraftToken,
                refreshToken: refreshedTokens.refreshToken ?? "",
                expiresAt: nil,
                xuid: xboxToken.displayClaims.xui.first?.uhs ?? ""
            )
        }

        return Player(profile: updatedProfile, credential: updatedCredential)
    }

    func refreshTokenThrowing(refreshToken: String) async throws -> TokenResponse {
        let url = URLConfig.API.Authentication.token

        let bodyParameters: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": clientId,
            "refresh_token": refreshToken,
        ]
        let bodyString = bodyParameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIClient.MimeType.formURLEncodedUTF8, forHTTPHeaderField: APIClient.Header.contentType)
        request.httpBody = bodyData

        let (data, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

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

    func isTokenExpiredBasedOnTime(for player: Player) async -> Bool {
        JWTDecoder.isTokenExpiringSoon(player.authAccessToken)
    }

    func promptForReauth(player: Player) {
        let notification = GlobalError.authentication(
            chineseMessage: "玩家 \(player.name) 的登录已过期，请在玩家管理中重新登录该账户后再启动游戏",
            i18nKey: "error.authentication.reauth_required",
            level: .notification
        )

        AppServices.errorHandler.handle(notification)
    }
}
