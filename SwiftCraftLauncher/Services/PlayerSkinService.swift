import Foundation

enum PlayerSkinService {

    private static let cacheNamespace = "session_skin"
    
    // MARK: - Error Handling
    private static func handleError(_ error: Error, operation: String) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("\(operation) failed: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
    }

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
    private struct SessionProperty: Decodable {
        let name: String
        let value: String
    }

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
            handleError(error, operation: "Fetch Skin")

            if let cached: PublicSkinInfo = AppCacheManager.shared.get(
                namespace: cacheNamespace,
                key: uuid,
                as: PublicSkinInfo.self
            ) {
                return cached
            }
            return nil
        }
    }

    static func fetchPublicSkinThrowing(uuid: String) async throws -> PublicSkinInfo {
        let cleanUUID = uuid.replacingOccurrences(of: "-", with: "")

        if let cached: PublicSkinInfo = AppCacheManager.shared.get(
            namespace: cacheNamespace,
            key: cleanUUID,
            as: PublicSkinInfo.self
        ) {
            if Date().timeIntervalSince(cached.fetchedAt) < 300 {
                return cached
            }
        }

        guard
            let url = URL(
                string:
                    "https://sessionserver.mojang.com/session/minecraft/profile/\(cleanUUID)"
            )
        else {
            throw GlobalError.validation(
                chineseMessage: "无效的UUID: \(uuid)",
                i18nKey: "error.validation.invalid_uuid",
                level: .silent
            )
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "会话服务器响应无效",
                i18nKey: "error.download.session_invalid_response",
                level: .silent
            )
        }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw GlobalError.resource(
                chineseMessage: "未找到玩家或没有皮肤: \(uuid)",
                i18nKey: "error.resource.skin_player_not_found",
                level: .silent
            )
        default:
            throw GlobalError.download(
                chineseMessage: "会话服务器错误: HTTP \(http.statusCode)",
                i18nKey: "error.download.session_http_error",
                level: .silent
            )
        }

        let profile = try JSONDecoder().decode(SessionProfile.self, from: data)
        guard
            let texturesProperty = profile.properties.first(where: {
                $0.name == "textures"
            })
        else {
            throw GlobalError.resource(
                chineseMessage: "缺少纹理属性",
                i18nKey: "error.resource.textures_property_missing",
                level: .silent
            )
        }

        // Base64 → JSON
        guard let decodedData = Data(base64Encoded: texturesProperty.value)
        else {
            throw GlobalError.validation(
                chineseMessage: "纹理Base64解码失败",
                i18nKey: "error.validation.textures_base64_decode_failed",
                level: .silent
            )
        }

        let payload = try JSONDecoder().decode(
            TexturesPayload.self,
            from: decodedData
        )
        let skinURL = payload.textures.SKIN?.url
        let modelString = payload.textures.SKIN?.metadata?.model?.lowercased()
        let model: PublicSkinInfo.SkinModel =
            (modelString == "slim") ? .slim : .classic
        let capeURL = payload.textures.CAPE?.url

        let secureSkin = skinURL?.httpToHttps()
        let secureCape = capeURL?.httpToHttps()

        let result = PublicSkinInfo(
            skinURL: secureSkin,
            model: model,
            capeURL: secureCape,
            fetchedAt: Date()
        )

        AppCacheManager.shared.setSilently(
            namespace: cacheNamespace,
            key: cleanUUID,
            value: result
        )
        return result
    }

    // MARK: - Upload Skin (multipart/form-data)
    /// Upload (silent version)
    /// - Parameters:
    ///   - imageData: PNG image data (64x64 or 64x32 standard formats)
    ///   - model: Skin model classic / slim
    ///   - player: Current online player (requires valid accessToken)
    /// - Returns: Whether successful
    static func uploadSkin(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player
    ) async -> Bool {
        do {
            try await uploadSkinThrowing(
                imageData: imageData,
                model: model,
                player: player
            )
            return true
        } catch {
            handleError(error, operation: "Upload skin")
            return false
        }
    }

    /// Upload (throwing version)
    /// Implemented according to https://zh.minecraft.wiki/w/Mojang_API#upload-skin specification
    static func uploadSkinThrowing(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player
    ) async throws {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage: "离线账户不支持皮肤上传",
                i18nKey: "error.validation.offline_skin_upload_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }

        let boundary = "Boundary-" + UUID().uuidString
        var body = Data()
        func appendField(name: String, value: String) {
            if let fieldData =
                "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"
                .data(using: .utf8) {
                body.append(fieldData)
            }
        }
        func appendFile(
            name: String,
            filename: String,
            mime: String,
            data: Data
        ) {
            var part = Data()
            func appendString(_ s: String) {
                if let d = s.data(using: .utf8) { part.append(d) }
            }
            appendString("--\(boundary)\r\n")
            appendString(
                "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
            )
            appendString("Content-Type: \(mime)\r\n\r\n")
            part.append(data)
            appendString("\r\n")
            body.append(part)
        }
        appendField(name: "variant", value: model == .slim ? "slim" : "classic")
        appendFile(
            name: "file",
            filename: "skin.png",
            mime: "image/png",
            data: imageData
        )
        if let closing = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(closing)
        }

        var request = URLRequest(
            url: URLConfig.API.Authentication.minecraftProfileSkins
        )
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(player.authAccessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = body
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "皮肤上传失败: 响应无效",
                i18nKey: "error.network.skin_upload_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204:  // Mojang documentation may return empty payload
            // Invalidate cache
            AppCacheManager.shared.removeSilently(
                namespace: cacheNamespace,
                key: player.id.replacingOccurrences(of: "-", with: "")
            )
            Logger.shared.info(
                "Skin upload successful, status=\(http.statusCode) bytes=\(data.count)"
            )
            return
        case 400:
            throw GlobalError.validation(
                chineseMessage: "无效的皮肤文件",
                i18nKey: "error.validation.skin_invalid_file",
                level: .notification
            )
        case 401:
            throw GlobalError.authentication(
                chineseMessage:
                    "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        case 403:
            throw GlobalError.authentication(
                chineseMessage: "没有上传皮肤的权限 (403)",
                i18nKey: "error.authentication.skin_upload_forbidden",
                level: .notification
            )
        case 429:
            throw GlobalError.network(
                chineseMessage: "请求过于频繁，请稍后再试",
                i18nKey: "error.network.rate_limited",
                level: .notification
            )
        default:
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw GlobalError.network(
                chineseMessage:
                    "皮肤上传失败: HTTP \(http.statusCode) \(bodyText)",
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
            handleError(error, operation: "Reset skin")
            return false
        }
    }

    // MARK: - Cape Management
    /// Get player profile with capes information (silent version)
    /// - Parameter player: Current online player
    /// - Returns: Profile with cape information or nil if failed
    static func fetchPlayerProfile(player: Player) async
        -> MinecraftProfileResponse? {
        do {
            return try await fetchPlayerProfileThrowing(player: player)
        } catch {
            handleError(error, operation: "Fetch player profile")
            return nil
        }
    }

    /// Get player profile with capes information (throwing version)
    static func fetchPlayerProfileThrowing(player: Player) async throws
        -> MinecraftProfileResponse {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage:
                    "离线账户不支持获取个人资料",
                i18nKey: "error.validation.offline_profile_fetch_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }

        var request = URLRequest(
            url: URLConfig.API.Authentication.minecraftProfile
        )
        request.setValue(
            "Bearer \(player.authAccessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "获取个人资料失败: 响应无效",
                i18nKey: "error.network.profile_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200:
            break
        case 401:
            throw GlobalError.authentication(
                chineseMessage:
                    "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        default:
            throw GlobalError.network(
                chineseMessage: "获取个人资料失败: HTTP \(http.statusCode)",
                i18nKey: "error.network.profile_http_error",
                level: .notification
            )
        }

        let profile = try JSONDecoder().decode(
            MinecraftProfileResponse.self,
            from: data
        )
        return MinecraftProfileResponse(
            id: profile.id,
            name: profile.name,
            skins: profile.skins,
            capes: profile.capes,
            accessToken: player.authAccessToken,
            authXuid: player.authXuid,
            refreshToken: player.authRefreshToken
        )
    }

    /// Show/equip a cape (silent version)
    /// - Parameters:
    ///   - capeId: Cape UUID to equip
    ///   - player: Current online player
    /// - Returns: Whether successful
    static func showCape(capeId: String, player: Player) async -> Bool {
        do {
            try await showCapeThrowing(capeId: capeId, player: player)
            return true
        } catch {
            handleError(error, operation: "Show cape")
            return false
        }
    }

    /// Show/equip a cape (throwing version)
    /// Implemented according to https://zh.minecraft.wiki/w/Mojang_API#show-cape specification
    static func showCapeThrowing(capeId: String, player: Player) async throws {
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }

        let payload = ["capeId": capeId]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(
            url: URLConfig.API.Authentication.minecraftProfileActiveCape
        )
        request.httpMethod = "PUT"
        request.setValue(
            "Bearer \(player.authAccessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "显示斗篷失败: 响应无效",
                i18nKey: "error.network.cape_show_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204:
            // Invalidate cache
            AppCacheManager.shared.removeSilently(
                namespace: cacheNamespace,
                key: player.id.replacingOccurrences(of: "-", with: "")
            )
            Logger.shared.info("Cape \(capeId) equipped successfully")
        case 400:
            throw GlobalError.validation(
                chineseMessage: "无效的斗篷ID或请求",
                i18nKey: "error.validation.cape_invalid_id",
                level: .notification
            )
        case 401:
            throw GlobalError.authentication(
                chineseMessage:
                    "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        case 403:
            throw GlobalError.authentication(
                chineseMessage: "没有装备斗篷的权限 (403)",
                i18nKey: "error.authentication.cape_equip_forbidden",
                level: .notification
            )
        case 404:
            throw GlobalError.resource(
                chineseMessage: "未找到斗篷或未拥有",
                i18nKey: "error.resource.cape_not_found",
                level: .notification
            )
        default:
            throw GlobalError.network(
                chineseMessage: "显示斗篷失败: HTTP \(http.statusCode)",
                i18nKey: "error.network.cape_show_http_error",
                level: .notification
            )
        }
    }

    /// Hide current cape (silent version)
    /// - Parameter player: Current online player
    /// - Returns: Whether successful
    static func hideCape(player: Player) async -> Bool {
        do {
            try await hideCapeThrowing(player: player)
            return true
        } catch {
            handleError(error, operation: "Hide cape")
            return false
        }
    }

    /// Hide current cape (throwing version)
    /// Implemented according to https://zh.minecraft.wiki/w/Mojang_API#hide-cape specification
    static func hideCapeThrowing(player: Player) async throws {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage: "离线账户不支持隐藏斗篷",
                i18nKey: "error.validation.offline_cape_hide_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }

        var request = URLRequest(
            url: URLConfig.API.Authentication.minecraftProfileActiveCape
        )
        request.httpMethod = "DELETE"
        request.setValue(
            "Bearer \(player.authAccessToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "隐藏斗篷失败: 响应无效",
                i18nKey: "error.network.cape_hide_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204:
            // Invalidate cache
            AppCacheManager.shared.removeSilently(
                namespace: cacheNamespace,
                key: player.id.replacingOccurrences(of: "-", with: "")
            )
            Logger.shared.info("Cape hidden successfully")
        case 401:
            throw GlobalError.authentication(
                chineseMessage:
                    "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        default:
            throw GlobalError.network(
                chineseMessage: "隐藏斗篷失败: HTTP \(http.statusCode)",
                i18nKey: "error.network.cape_hide_http_error",
                level: .notification
            )
        }
    }

    static func resetSkinThrowing(player: Player) async throws {
        guard player.isOnlineAccount else {
            throw GlobalError.validation(
                chineseMessage: "离线账户不支持皮肤重置",
                i18nKey: "error.validation.offline_skin_reset_not_supported",
                level: .notification
            )
        }
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }
        var request = URLRequest(
            url: URLConfig.API.Authentication.minecraftProfileActiveSkin
        )
        request.httpMethod = "DELETE"
        request.setValue(
            "Bearer \(player.authAccessToken)",
            forHTTPHeaderField: "Authorization"
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlobalError.network(
                chineseMessage: "重置皮肤失败: 响应无效",
                i18nKey: "error.network.skin_reset_invalid_response",
                level: .notification
            )
        }
        switch http.statusCode {
        case 200, 204:
            AppCacheManager.shared.removeSilently(
                namespace: cacheNamespace,
                key: player.id.replacingOccurrences(of: "-", with: "")
            )
            Logger.shared.info("Skin reset to default")
        case 401:
            throw GlobalError.authentication(
                chineseMessage:
                    "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_invalid_or_expired",
                level: .popup
            )
        default:
            throw GlobalError.network(
                chineseMessage: "重置皮肤失败: HTTP \(http.statusCode)",
                i18nKey: "error.network.skin_reset_http_error",
                level: .notification
            )
        }
    }
}
