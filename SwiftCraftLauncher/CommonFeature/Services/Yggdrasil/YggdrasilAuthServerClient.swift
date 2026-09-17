//
//  YggdrasilAuthServerClient.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Yggdrasil classic 协议的角色信息(authenticate/refresh 响应内嵌)。
struct YggdrasilAuthProfile: Codable, Equatable {
    let id: String
    let name: String
}

/// `POST /authserver/authenticate` 与 `POST /authserver/refresh` 的响应。
struct YggdrasilAuthenticateResponse: Codable, Equatable {
    let accessToken: String
    let clientToken: String
    let availableProfiles: [YggdrasilAuthProfile]?
    let selectedProfile: YggdrasilAuthProfile?
}

/// classic authserver 拒绝请求的细分错误。
///
/// 协议中密码错误与令牌失效均为 HTTP 403 + `ForbiddenOperationException`,
/// 依靠响应体 errorMessage 区分,供续期状态机分支决策。
enum YggdrasilAuthServerError: Error {
    /// 用户名或密码错误(或多次失败被临时禁止),重试无意义。
    case invalidCredentials
    /// 令牌无效,应走刷新/重登流程。
    case invalidToken
    /// 其他拒绝原因,附带服务器提供的描述。
    case rejected(String)
}

/// sessionserver 角色档案(用于头像展示)。
struct YggdrasilSessionProfile: Codable, Equatable {
    let id: String
    let name: String
    /// 角色皮肤贴图地址;角色未设置皮肤时为 `nil`。
    let skinURL: String?
}

/// Yggdrasil classic authserver API 客户端抽象(协议缝,便于单元测试)。
protocol YggdrasilAuthServerClientProtocol: Sendable {
    /// 用户名密码登录。
    func authenticate(
        username: String,
        password: String,
        clientToken: String,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse

    /// 刷新令牌;`selectedProfileId` 非 nil 时同时完成角色绑定。
    func refresh(
        accessToken: String,
        clientToken: String,
        selectedProfileId: String?,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse

    /// 校验令牌是否有效(204 即有效)。
    func validate(accessToken: String, clientToken: String, apiRoot: URL) async -> Bool

    /// 拉取角色档案(含皮肤贴图地址),用于密码登录后的头像展示。
    func fetchSessionProfile(uuid: String, apiRoot: URL) async throws -> YggdrasilSessionProfile
}

/// 默认实现,基于共享 `APIClient`。
struct YggdrasilAuthServerClient: YggdrasilAuthServerClientProtocol {
    private static let invalidTokenMarker = "invalid token"
    private static let invalidCredentialsMarker = "invalid credentials"

    func authenticate(
        username: String,
        password: String,
        clientToken: String,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        let body: [String: Any] = [
            "agent": ["name": "Minecraft", "version": 1],
            "username": username,
            "password": password,
            "clientToken": clientToken,
            "requestUser": false,
        ]
        return try await post(body: body, url: endpoint(apiRoot, action: "authenticate"))
    }

    func refresh(
        accessToken: String,
        clientToken: String,
        selectedProfileId: String?,
        apiRoot: URL,
    ) async throws -> YggdrasilAuthenticateResponse {
        var body: [String: Any] = [
            "accessToken": accessToken,
            "clientToken": clientToken,
        ]
        if let selectedProfileId {
            body["selectedProfile"] = ["id": selectedProfileId]
        }
        return try await post(body: body, url: endpoint(apiRoot, action: "refresh"))
    }

    func validate(accessToken: String, clientToken: String, apiRoot: URL) async -> Bool {
        let body: [String: Any] = [
            "accessToken": accessToken,
            "clientToken": clientToken,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return false }
        do {
            let (_, statusCode) = try await APIClient.postUnchecked(
                url: endpoint(apiRoot, action: "validate"),
                body: data,
                headers: APIClient.DefaultHeaders.contentTypeJSON,
            )
            // 规范:有效返回 204 No Content
            return statusCode == 204
        } catch {
            return false
        }
    }

    func fetchSessionProfile(uuid: String, apiRoot: URL) async throws -> YggdrasilSessionProfile {
        let url = apiRoot.appendingPathComponent("sessionserver/session/minecraft/profile/\(uuid)")
        let data = try await APIClient.get(url: url, headers: [:])

        struct RawProfile: Codable {
            struct Property: Codable {
                let name: String
                let value: String
            }

            let id: String
            let name: String
            let properties: [Property]
        }

        let raw = try JSONDecoder().decode(RawProfile.self, from: data)
        let textureValue = raw.properties.first { $0.name == "textures" }?.value
        return YggdrasilSessionProfile(id: raw.id, name: raw.name, skinURL: textureValue.flatMap(Self.skinURL(fromTextureValue:)))
    }

    /// 解码 textures 属性(base64url 的 JSON)中的 SKIN 贴图地址。
    static func skinURL(fromTextureValue base64: String) -> String? {
        var padded = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while !padded.count.isMultiple(of: 4) {
            padded += "="
        }
        guard let data = Data(base64Encoded: padded),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let textures = object["textures"] as? [String: Any],
              let skin = textures["SKIN"] as? [String: Any] else {
            return nil
        }
        return skin["url"] as? String
    }

    // MARK: - 私有

    private func endpoint(_ apiRoot: URL, action: String) -> URL {
        apiRoot.appendingPathComponent("authserver/\(action)")
    }

    private func post(body: [String: Any], url: URL) async throws -> YggdrasilAuthenticateResponse {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_request_serialize_failed",
                level: .notification,
                message: "Failed to serialize Yggdrasil authserver request for \(url): \(error.localizedDescription)",
            )
        }

        let (responseData, statusCode) = try await APIClient.postUnchecked(
            url: url,
            body: data,
            headers: APIClient.DefaultHeaders.contentTypeJSON,
        )
        try rejectIfDenied(data: responseData, statusCode: statusCode, url: url)

        do {
            return try JSONDecoder().decode(YggdrasilAuthenticateResponse.self, from: responseData)
        } catch {
            throw GlobalError.validation(
                i18nKey: "error.validation.yggdrasil_token_response_parse_failed",
                level: .notification,
                message: "Failed to parse Yggdrasil authserver response from \(url): \(error.localizedDescription)",
            )
        }
    }

    /// 非 2xx 响应按协议错误体细分(均为 UTF-8 JSON:`error` / `errorMessage`)。
    private func rejectIfDenied(data: Data, statusCode: Int, url: URL) throws {
        guard !(200 ..< 300).contains(statusCode) else { return }

        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { $0["errorMessage"] as? String } ?? ""
        let lowercased = message.lowercased()

        if statusCode == 403 {
            if lowercased.contains(Self.invalidCredentialsMarker) {
                throw YggdrasilAuthServerError.invalidCredentials
            }
            if lowercased.contains(Self.invalidTokenMarker) {
                throw YggdrasilAuthServerError.invalidToken
            }
        }
        throw YggdrasilAuthServerError.rejected(message.isEmpty ? "HTTP \(statusCode)" : message)
    }
}

/// 安装级 Yggdrasil classic clientToken。
///
/// 规范要求客户端全程保持 clientToken 一致;首次使用时生成并持久化到
/// UserDefaults(非敏感标识,无需钥匙串)。
enum YggdrasilClientTokenProvider {
    static func currentToken() -> String {
        let key = AppConstants.UserDefaultsKeys.yggdrasilClientToken
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: key)
        return token
    }
}
