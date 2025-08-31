import Foundation

enum PlayerSkinService {

    private static let cacheNamespace = "session_skin"

    struct PublicSkinInfo: Codable, Equatable {
        let skinURL: String?
        let model: SkinModel
        let capeURL: String?
        let fetchedAt: Date

        enum SkinModel: String, Codable { case classic, slim }
    }

    // Flattened previously deeply-nested types to satisfy SwiftLint nesting rule
    private struct SessionProfile: Decodable {
        let id: String
        let name: String
        let properties: [SessionProperty]
    }
    private struct SessionProperty: Decodable { let name: String; let value: String }

    private struct TexturesPayload: Decodable {
        let timestamp: Int64
        let profileId: String
        let profileName: String
        let textures: Textures
    }
    private struct Textures: Decodable {
        let SKIN: SkinObj?
        let CAPE: CapeObj?
    }
    private struct SkinObj: Decodable {
        let url: String
        let metadata: SkinMetadata?
    }
    private struct SkinMetadata: Decodable { let model: String? }
    private struct CapeObj: Decodable { let url: String }

    static func fetchPublicSkin(uuid: String) async -> PublicSkinInfo? {
        do { return try await fetchPublicSkinThrowing(uuid: uuid) } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Fetch Skin failed: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)

            if let cached: PublicSkinInfo = AppCacheManager.shared.get(namespace: cacheNamespace, key: uuid, as: PublicSkinInfo.self) {
                return cached
            }
            return nil
        }
    }

    static func fetchPublicSkinThrowing(uuid: String) async throws -> PublicSkinInfo {
        let cleanUUID = uuid.replacingOccurrences(of: "-", with: "")

        if let cached: PublicSkinInfo = AppCacheManager.shared.get(namespace: cacheNamespace, key: cleanUUID, as: PublicSkinInfo.self) {
            if Date().timeIntervalSince(cached.fetchedAt) < 300 { return cached }
        }

        guard let url = URL(string: "https://sessionserver.mojang.com/session/minecraft/profile/\(cleanUUID)") else {
            throw GlobalError.validation(
                chineseMessage: "Invalid UUID: \(uuid)",
                i18nKey: "error.validation.invalid_uuid",
                level: .silent
            )
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "Session Server invalid response",
                i18nKey: "error.download.session_invalid_response",
                level: .silent
            )
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw GlobalError.resource(
                chineseMessage: "Player not found or no skin: \(uuid)",
                i18nKey: "error.resource.skin_player_not_found",
                level: .silent
            )
        default:
            throw GlobalError.download(
                chineseMessage: "Session Server error: HTTP \(http.statusCode)",
                i18nKey: "error.download.session_http_error",
                level: .silent
            )
        }

    let profile = try JSONDecoder().decode(SessionProfile.self, from: data)
    guard let texturesProperty = profile.properties.first(where: { $0.name == "textures" }) else {
            throw GlobalError.resource(
                chineseMessage: "Missing textures property",
                i18nKey: "error.resource.textures_property_missing",
                level: .silent
            )
        }

        // Base64 → JSON
        guard let decodedData = Data(base64Encoded: texturesProperty.value) else {
            throw GlobalError.validation(
                chineseMessage: "textures Base64 decode failed",
                i18nKey: "error.validation.textures_base64_decode_failed",
                level: .silent
            )
    }

    let payload = try JSONDecoder().decode(TexturesPayload.self, from: decodedData)
    let skinURL = payload.textures.SKIN?.url
    let modelString = payload.textures.SKIN?.metadata?.model?.lowercased()
    let model: PublicSkinInfo.SkinModel = (modelString == "slim") ? .slim : .classic
    let capeURL = payload.textures.CAPE?.url

    let secureSkin = skinURL?.httpToHttps()
    let secureCape = capeURL?.httpToHttps()

    let result = PublicSkinInfo(skinURL: secureSkin, model: model, capeURL: secureCape, fetchedAt: Date())

    AppCacheManager.shared.setSilently(namespace: cacheNamespace, key: cleanUUID, value: result)
    return result
    }

    // MARK: - Upload Skin (multipart/form-data)
    /// Upload (silent version)
    /// - Parameters:
    ///   - imageData: PNG image data (64x64 or 64x32 standard formats)
    ///   - model: Skin model classic / slim
    ///   - player: Current online player (requires valid accessToken)
    /// - Returns: Whether successful
    static func uploadSkin(imageData: Data, model: PublicSkinInfo.SkinModel, player: Player) async -> Bool {
        do {
            try await uploadSkinThrowing(imageData: imageData, model: model, player: player)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Upload skin failed: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    /// Upload (throwing version)
    /// Implemented according to https://zh.minecraft.wiki/w/Mojang_API#upload-skin specification
    static func uploadSkinThrowing(imageData: Data, model: PublicSkinInfo.SkinModel, player: Player) async throws {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage: "Offline accounts do not support skin upload",
                i18nKey: "error.validation.offline_skin_upload_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "Missing access token, please log in again",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }

        let boundary = "Boundary-" + UUID().uuidString
        var body = Data()
        func appendField(name: String, value: String) {
            if let fieldData = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8) {
                body.append(fieldData)
            }
        }
        func appendFile(name: String, filename: String, mime: String, data: Data) {
            var part = Data()
            func appendString(_ s: String) { if let d = s.data(using: .utf8) { part.append(d) } }
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            appendString("Content-Type: \(mime)\r\n\r\n")
            part.append(data)
            appendString("\r\n")
            body.append(part)
        }
        appendField(name: "variant", value: model == .slim ? "slim" : "classic")
        appendFile(name: "file", filename: "skin.png", mime: "image/png", data: imageData)
        if let closing = "--\(boundary)--\r\n".data(using: .utf8) { body.append(closing) }

        var request = URLRequest(url: URLConfig.API.Authentication.minecraftProfileSkins)
        request.httpMethod = "POST"
        request.setValue("Bearer \(player.authAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "Upload skin failed: Invalid response",
                i18nKey: "error.network.skin_upload_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204: // Mojang documentation may return empty payload
            // Invalidate cache
            AppCacheManager.shared.removeSilently(namespace: cacheNamespace, key: player.id.replacingOccurrences(of: "-", with: ""))
            Logger.shared.info("Skin upload successful, status=\(http.statusCode) bytes=\(data.count)")
            return
        case 400:
            throw GlobalError.validation(
                chineseMessage: "Invalid skin file",
                i18nKey: "error.validation.skin_invalid_file",
                level: .notification
            )
        case 401:
            throw GlobalError.authentication(
                chineseMessage: "Invalid or expired access token, please log in again",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        case 403:
            throw GlobalError.authentication(
                chineseMessage: "No permission to upload skin (403)",
                i18nKey: "error.authentication.skin_upload_forbidden",
                level: .notification
            )
        case 429:
            throw GlobalError.network(
                chineseMessage: "Too many requests, please try again later",
                i18nKey: "error.network.rate_limited",
                level: .notification
            )
        default:
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw GlobalError.network(
                chineseMessage: "Upload skin failed: HTTP \(http.statusCode) \(bodyText)",
                i18nKey: "error.network.skin_upload_http_error",
                level: .notification
            )
        }
    }

    // MARK: - Reset Skin (delete active)
    static func resetSkin(player: Player) async -> Bool {
        do {
            try await resetSkinThrowing(player: player)
            return true
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("Reset skin failed: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return false
        }
    }

    static func resetSkinThrowing(player: Player) async throws {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage: "Offline accounts do not support skin reset",
                i18nKey: "error.validation.offline_skin_reset_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "Access token missing, please log in again",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }
        var request = URLRequest(url: URLConfig.API.Authentication.minecraftProfileActiveSkin)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(player.authAccessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "Reset skin failed: Invalid response",
                i18nKey: "error.network.skin_reset_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204:
            AppCacheManager.shared.removeSilently(namespace: cacheNamespace, key: player.id.replacingOccurrences(of: "-", with: ""))
            Logger.shared.info("Skin reset to default")
        case 401:
            throw GlobalError.authentication(
                chineseMessage: "Invalid or expired access token, please log in again",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        default:
            throw GlobalError.network(
                chineseMessage: "Reset skin failed: HTTP \(http.statusCode)",
                i18nKey: "error.network.skin_reset_http_error",
                level: .notification
            )
        }
    }
}
