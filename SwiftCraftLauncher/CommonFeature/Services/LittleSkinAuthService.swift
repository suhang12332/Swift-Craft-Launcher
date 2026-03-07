import Foundation

final class LittleSkinAuthService: ObservableObject {
    static let shared = LittleSkinAuthService()

    @Published var authState: LittleSkinAuthenticationState = .idle
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var selectedProfileId: String = ""

    private var pendingResponse: LittleSkinAuthenticateResponse?

    private init() {}

    @MainActor
    func login() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            authState = .error("请输入 LittleSkin 邮箱和密码")
            return
        }

        authState = .authenticating

        do {
            let response = try await authenticateThrowing(username: trimmedEmail, password: password)
            password = ""
            handleAuthenticationResponse(response)
        } catch {
            authState = .error(Self.mapErrorMessage(error))
        }
    }

    @MainActor
    func finalizeSelectedProfile() -> AuthenticatedPlayerPayload? {
        guard let payload = payloadForCurrentSelection() else {
            authState = .error("请选择要导入的 LittleSkin 角色")
            return nil
        }
        authState = .authenticated(payload)
        return payload
    }

    @MainActor
    func clearAuthenticationData() {
        authState = .idle
        email = ""
        password = ""
        selectedProfileId = ""
        pendingResponse = nil
    }

    func authenticateThrowing(username: String, password: String) async throws -> LittleSkinAuthenticateResponse {
        let requestBody = LittleSkinAuthenticateRequest(
            agent: .init(name: "Minecraft", version: 1),
            username: username,
            password: password,
            requestUser: false
        )
        return try await performAuthRequest(
            url: URLConfig.API.LittleSkin.authenticate,
            body: requestBody
        )
    }

    func validateTokenThrowing(
        accessToken: String,
        clientToken: String,
        authServerBaseURL: String = URLConfig.API.LittleSkin.yggdrasilBase.absoluteString
    ) async throws {
        let endpoint = try validateEndpoint(baseURL: authServerBaseURL, path: "authserver/validate")
        let body = LittleSkinValidateRequest(
            accessToken: accessToken,
            clientToken: clientToken
        )
        let data = try JSONEncoder().encode(body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await APIClient.performRequestWithResponse(request: request)
        guard response.statusCode == 200 || response.statusCode == 204 else {
            throw try Self.mapYggdrasilError(from: responseData, fallback: "LittleSkin 登录校验失败")
        }
    }

    func refreshTokenThrowing(
        accessToken: String,
        clientToken: String,
        profile: LittleSkinProfileSummary,
        authServerBaseURL: String = URLConfig.API.LittleSkin.yggdrasilBase.absoluteString
    ) async throws -> LittleSkinAuthenticateResponse {
        let endpoint = try validateEndpoint(baseURL: authServerBaseURL, path: "authserver/refresh")
        let requestBody = LittleSkinRefreshRequest(
            accessToken: accessToken,
            clientToken: clientToken,
            selectedProfile: profile,
            requestUser: false
        )
        let response = try await performAuthRequest(url: endpoint, body: requestBody)
        guard response.clientToken == clientToken else {
            throw GlobalError.authentication(
                chineseMessage: "LittleSkin 刷新响应异常：Client Token 不一致",
                i18nKey: "error.authentication.littleskin_auth_failed",
                level: .notification
            )
        }
        guard let selectedProfile = response.selectedProfile,
              selectedProfile.id == profile.id else {
            throw GlobalError.authentication(
                chineseMessage: "LittleSkin 刷新响应异常：选中角色与请求不一致",
                i18nKey: "error.authentication.littleskin_auth_failed",
                level: .notification
            )
        }
        return response
    }

    @MainActor
    private func handleAuthenticationResponse(_ response: LittleSkinAuthenticateResponse) {
        pendingResponse = response
        let profiles = response.availableProfiles ?? []
        if profiles.count > 1 {
            selectedProfileId = profiles.first?.id ?? ""
            authState = .selectingProfiles(profiles)
            return
        }

        let profile = response.selectedProfile ?? profiles.first
        guard let profile else {
            authState = .error("LittleSkin 未返回可用角色")
            return
        }

        let payload = Self.makePayload(
            response: response,
            profile: profile,
            authServerBaseURL: URLConfig.API.LittleSkin.yggdrasilBase.absoluteString
        )
        authState = .authenticated(payload)
    }

    @MainActor
    private func payloadForCurrentSelection() -> AuthenticatedPlayerPayload? {
        guard let response = pendingResponse else {
            return nil
        }
        guard let profile = (response.availableProfiles ?? []).first(where: { $0.id == selectedProfileId }) else {
            return nil
        }
        return Self.makePayload(
            response: response,
            profile: profile,
            authServerBaseURL: URLConfig.API.LittleSkin.yggdrasilBase.absoluteString
        )
    }

    private func performAuthRequest<T: Encodable>(
        url: URL,
        body: T
    ) async throws -> LittleSkinAuthenticateResponse {
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await APIClient.performRequestWithResponse(request: request)
        guard response.statusCode == 200 else {
            throw try Self.mapYggdrasilError(from: responseData, fallback: "LittleSkin 登录失败")
        }

        do {
            return try JSONDecoder().decode(LittleSkinAuthenticateResponse.self, from: responseData)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "解析 LittleSkin 认证响应失败: \(error.localizedDescription)",
                i18nKey: "error.validation.littleskin_auth_response_parse_failed",
                level: .notification
            )
        }
    }

    private func validateEndpoint(baseURL: String, path: String) throws -> URL {
        guard let url = URL(string: baseURL) else {
            throw GlobalError.configuration(
                chineseMessage: "LittleSkin 认证服务器地址无效",
                i18nKey: "error.configuration.invalid_littleskin_server_url",
                level: .notification
            )
        }
        return url.appendingPathComponent(path)
    }

    private static func makePayload(
        response: LittleSkinAuthenticateResponse,
        profile: LittleSkinProfileSummary,
        authServerBaseURL: String
    ) -> AuthenticatedPlayerPayload {
        AuthenticatedPlayerPayload(
            provider: .littleskin,
            playerId: profile.id,
            playerName: profile.name,
            avatarURL: "https://littleskin.cn/skin/\(profile.name).png",
            accessToken: response.accessToken,
            clientToken: response.clientToken,
            refreshToken: "",
            xuid: "",
            authServerBaseURL: authServerBaseURL
        )
    }

    private static func mapYggdrasilError(from data: Data, fallback: String) throws -> GlobalError {
        if let errorResponse = try? JSONDecoder().decode(LittleSkinErrorResponse.self, from: data) {
            let rawMessage = [
                errorResponse.errorMessage,
                errorResponse.message,
                errorResponse.error,
                errorResponse.cause,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

            if let rawMessage {
                return GlobalError.authentication(
                    chineseMessage: rawMessage,
                    i18nKey: "error.authentication.littleskin_auth_failed",
                    level: .notification
                )
            }
        }

        return GlobalError.authentication(
            chineseMessage: fallback,
            i18nKey: "error.authentication.littleskin_auth_failed",
            level: .notification
        )
    }

    private static func mapErrorMessage(_ error: Error) -> String {
        if let globalError = error as? GlobalError {
            return globalError.chineseMessage
        }
        return error.localizedDescription
    }
}

private struct LittleSkinAgent: Codable {
    let name: String
    let version: Int
}

private struct LittleSkinAuthenticateRequest: Codable {
    let agent: LittleSkinAgent
    let username: String
    let password: String
    let requestUser: Bool
}

private struct LittleSkinValidateRequest: Codable {
    let accessToken: String
    let clientToken: String
}

private struct LittleSkinRefreshRequest: Codable {
    let accessToken: String
    let clientToken: String
    let selectedProfile: LittleSkinProfileSummary
    let requestUser: Bool
}
