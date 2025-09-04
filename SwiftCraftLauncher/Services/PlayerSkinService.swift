import Foundation

enum PlayerSkinService {
    
    // MARK: - Notification System
    static let playerUpdatedNotification = Notification.Name("PlayerUpdated")
    
    private static func notifyPlayerUpdated(_ updatedPlayer: Player) {
        NotificationCenter.default.post(
            name: playerUpdatedNotification,
            object: nil,
            userInfo: ["updatedPlayer": updatedPlayer]
        )
    }

    // MARK: - Error Handling
    private static func handleError(_ error: Error, operation: String) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("\(operation) failed: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
    }
    
    // MARK: - Common Error Helpers
    
    private static func validateAccessToken(_ player: Player) throws {
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                chineseMessage: "缺少访问令牌，请重新登录",
                i18nKey: "error.authentication.missing_token",
                level: .popup
            )
        }
    }
    
    private static func handleHTTPError(_ http: HTTPURLResponse, operation: String) throws {
        switch http.statusCode {
        case 400:
            throw GlobalError.validation(
                chineseMessage: "无效的请求参数",
                i18nKey: "error.validation.invalid_request",
                level: .notification
            )
        case 401:
            throw GlobalError.authentication(
                chineseMessage: "访问令牌无效或已过期，请重新登录",
                i18nKey: "error.authentication.token_expired",
                level: .popup
            )
        case 403:
            throw GlobalError.authentication(
                chineseMessage: "没有\(operation)的权限 (403)",
                i18nKey: "error.authentication.\(operation)_forbidden",
                level: .notification
            )
        case 404:
            throw GlobalError.resource(
                chineseMessage: "未找到相关资源",
                i18nKey: "error.resource.not_found",
                level: .notification
            )
        case 429:
            throw GlobalError.network(
                chineseMessage: "请求过于频繁，请稍后再试",
                i18nKey: "error.network.rate_limited",
                level: .notification
            )
        default:
            throw GlobalError.network(
                chineseMessage: "\(operation)失败: HTTP \(http.statusCode)",
                i18nKey: "error.network.\(operation)_http_error",
                level: .notification
            )
        }
    }

    struct PublicSkinInfo: Codable, Equatable {
        let skinURL: String?
        let model: SkinModel
        let capeURL: String?
        let fetchedAt: Date

        enum SkinModel: String, Codable, CaseIterable { case classic, slim }
    }


    

    /// 更新玩家皮肤信息到数据管理器
    /// - Parameters:
    ///   - uuid: 玩家UUID
    ///   - skinInfo: 皮肤信息
    /// - Returns: 是否更新成功
    private static func updatePlayerSkinInfo(uuid: String, skinInfo: PublicSkinInfo) async -> Bool {
        do {
            let dataManager = PlayerDataManager()
            let players = try dataManager.loadPlayersThrowing()
            
            guard let player = players.first(where: { $0.id == uuid }) else {
                Logger.shared.warning("Player not found for UUID: \(uuid)")
                return false
            }
            
            // 记录更新前的玩家信息
            Logger.shared.info("🔄 [updatePlayerSkinInfo] 更新前玩家信息:")
            Logger.shared.info("  - 姓名: \(player.name)")
            Logger.shared.info("  - 皮肤URL: \(player.avatarName)")
            Logger.shared.info("  - 是否当前玩家: \(player.isCurrent)")
            
            // 创建更新后的玩家对象
            let updatedPlayer = try Player(
                name: player.name,
                uuid: player.id,
                isOnlineAccount: player.isOnlineAccount,
                avatarName: skinInfo.skinURL?.httpToHttps() ?? player.avatarName,
                authXuid: player.authXuid,
                authAccessToken: player.authAccessToken,
                authRefreshToken: player.authRefreshToken,
                tokenExpiresAt: player.tokenExpiresAt,
                createdAt: player.createdAt,
                lastPlayed: player.lastPlayed,
                isCurrent: player.isCurrent,
                gameRecords: player.gameRecords
            )
            
            // 记录更新后的玩家信息
            Logger.shared.info("🔄 [updatePlayerSkinInfo] 更新后玩家信息:")
            Logger.shared.info("  - 姓名: \(updatedPlayer.name)")
            Logger.shared.info("  - 皮肤URL: \(updatedPlayer.avatarName)")
            Logger.shared.info("  - 是否当前玩家: \(updatedPlayer.isCurrent)")
            
            // 使用 dataManager 更新数据
            try dataManager.updatePlayer(updatedPlayer)
            
            // 通知ViewModel更新当前玩家
            notifyPlayerUpdated(updatedPlayer)
            
            Logger.shared.info("Player skin info updated for: \(player.name)")
            return true
        } catch {
            Logger.shared.error("Failed to update player skin info: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 使用 Minecraft Services API 获取当前玩家的皮肤信息（更准确，无缓存延迟）
    /// - Parameter player: 玩家信息
    /// - Returns: 皮肤信息，如果获取失败返回nil
    static func fetchCurrentPlayerSkinFromServices(player: Player) async -> PublicSkinInfo? {
        do {
            let profile = try await fetchPlayerProfileThrowing(player: player)
            
            // 从 Minecraft Services API 响应中提取皮肤信息
            guard !profile.skins.isEmpty else {
                Logger.shared.warning("玩家没有皮肤信息")
                return nil
            }
            
            // 找到当前激活的皮肤
            let activeSkin = profile.skins.first { $0.state == "ACTIVE" } ?? profile.skins.first
            
            guard let skin = activeSkin else {
                Logger.shared.warning("没有找到激活的皮肤")
                return nil
            }
            
            let skinInfo = PublicSkinInfo(
                skinURL: skin.url,
                model: skin.variant == "SLIM" ? .slim : .classic,
                capeURL: nil, // Minecraft Services API 不直接提供斗篷信息
                fetchedAt: Date()
            )
            
            Logger.shared.info("✅ 从 Minecraft Services API 获取皮肤信息成功")
            return skinInfo
            
        } catch {
            Logger.shared.error("从 Minecraft Services API 获取皮肤信息失败: \(error.localizedDescription)")
            return nil
        }
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
    
    /// 刷新皮肤信息（公共方法）
    /// - Parameter player: 玩家信息
    private static func refreshSkinInfo(player: Player) async {
        Logger.shared.info("🔄 正在获取最新皮肤信息...")
        
        if let newSkinInfo = await fetchCurrentPlayerSkinFromServices(player: player) {
            Logger.shared.info("✅ 成功获取最新皮肤信息，正在更新...")
            await updatePlayerSkinInfo(uuid: player.id, skinInfo: newSkinInfo)
        } else {
            Logger.shared.warning("⚠️ 无法获取最新皮肤信息")
        }
    }
    
    /// 处理皮肤上传后的完整流程（包括数据更新和通知）
    /// - Parameters:
    ///   - imageData: 皮肤图片数据
    ///   - model: 皮肤模型
    ///   - player: 玩家信息
    /// - Returns: 是否成功
    static func uploadSkinAndRefresh(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player
    ) async -> Bool {
        let success = await uploadSkin(imageData: imageData, model: model, player: player)
        if success {
            Logger.shared.info("🔄 皮肤上传成功，正在获取最新皮肤信息...")
            await refreshSkinInfo(player: player)
        }
        return success
    }
    
    /// 重置皮肤并刷新数据
    /// - Parameter player: 玩家信息
    /// - Returns: 是否成功
    static func resetSkinAndRefresh(player: Player) async -> Bool {
        let success = await resetSkin(player: player)
        if success {
            Logger.shared.info("🔄 皮肤重置成功，正在获取最新皮肤信息...")
            await refreshSkinInfo(player: player)
        }
        return success
    }

    /// Upload (throwing version)
    /// Implemented according to https://zh.minecraft.wiki/w/Mojang_API#upload-skin specification
    static func uploadSkinThrowing(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player
    ) async throws {
        try validateAccessToken(player)

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
        case 200, 204:
            Logger.shared.info("Skin upload successful, status=\(http.statusCode) bytes=\(data.count)")
            return
        case 400:
            throw GlobalError.validation(
                chineseMessage: "无效的皮肤文件",
                i18nKey: "error.validation.skin_invalid_file",
                level: .popup
            )
        default:
            try handleHTTPError(http, operation: "皮肤上传")
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

    // MARK: - Common Helper Methods
    
    /// 获取当前激活的披风ID
    /// - Parameter profile: 玩家配置文件
    /// - Returns: 激活的披风ID，如果没有则返回nil
    static func getActiveCapeId(from profile: MinecraftProfileResponse?) -> String? {
        return profile?.capes?.first { $0.state == "ACTIVE" }?.id
    }
    
    /// 检查是否有皮肤变化
    /// - Parameters:
    ///   - selectedSkinData: 选中的皮肤数据
    ///   - currentModel: 当前模型
    ///   - originalModel: 原始模型
    /// - Returns: 是否有皮肤变化
    static func hasSkinChanges(
        selectedSkinData: Data?,
        currentModel: PublicSkinInfo.SkinModel,
        originalModel: PublicSkinInfo.SkinModel
    ) -> Bool {
        return selectedSkinData != nil || currentModel != originalModel
    }
    
    /// 检查是否有披风变化
    /// - Parameters:
    ///   - selectedCapeId: 选中的披风ID
    ///   - currentActiveCapeId: 当前激活的披风ID
    /// - Returns: 是否有披风变化
    static func hasCapeChanges(selectedCapeId: String?, currentActiveCapeId: String?) -> Bool {
        return selectedCapeId != currentActiveCapeId
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
        try validateAccessToken(player)

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
        default:
            try handleHTTPError(http, operation: "获取个人资料")
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
        try validateAccessToken(player)

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
        try validateAccessToken(player)

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
        try validateAccessToken(player)
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
