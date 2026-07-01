//
//  PlayerSkinService.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides skin and cape management operations for Minecraft player profiles.
///
/// This service interacts with the Minecraft Services API to upload, reset,
/// and retrieve skin and cape data for authenticated online players.
enum PlayerSkinService {
    private static func notifyPlayerUpdated(_ updatedPlayer: Player) {
        NotificationCenter.default.post(
            name: .playerUpdated,
            object: nil,
            userInfo: ["updatedPlayer": updatedPlayer],
        )
    }

    private static func handleError(_ error: Error, operation: String) {
        let globalError = GlobalError.from(error)
        AppLog.player.error("\(operation) failed: \(globalError.localizedDescription)")
        AppServices.errorHandler.handle(globalError)
    }

    private static func validateAccessToken(_ player: Player) throws {
        guard !player.authAccessToken.isEmpty else {
            throw GlobalError.authentication(
                i18nKey: "error.authentication.missing_token",
                level: .popup,
                message: "Access token is empty for player \"\(player.name)\" (ID: \(player.id))",
            )
        }
    }

    private static func handleHTTPError(_ error: GlobalError, operation: String) throws {
        switch error.statusCode {
        case 400:
            throw GlobalError.validation(
                i18nKey: "error.validation.invalid_request",
                level: .notification,
                message: "HTTP 400 Bad Request during \(operation)",
            )
        case 401:
            throw GlobalError.authentication(
                i18nKey: "error.authentication.token_expired",
                level: .popup,
                message: "HTTP 401 Unauthorized during \(operation), token may have expired",
            )
        case 403:
            throw GlobalError.authentication(
                i18nKey: "error.authentication.\(operation)_forbidden",
                level: .notification,
                message: "HTTP 403 Forbidden during \(operation)",
            )
        case 404:
            throw GlobalError.resource(
                i18nKey: "error.resource.not_found",
                level: .notification,
                message: "HTTP 404 Not Found during \(operation)",
            )
        case 429:
            throw GlobalError.network(
                i18nKey: "error.network.rate_limited",
                message: "HTTP 429 Rate Limited during \(operation)",
            )
        default:
            throw error
        }
    }

    struct PublicSkinInfo: Codable, Equatable {
        let skinURL: String?
        let model: SkinModel
        let capeURL: String?
        let fetchedAt: Date

        enum SkinModel: String, Codable, CaseIterable { case classic, slim }
    }

    /// Updates the player's skin information in the data manager.
    ///
    /// - Parameters:
    ///   - uuid: The player's UUID.
    ///   - skinInfo: The skin information to persist.
    /// - Returns: `true` if the update was successful.
    private static func updatePlayerSkinInfo(uuid: String, skinInfo: PublicSkinInfo) async -> Bool {
        do {
            let dataManager = AppServices.playerDataManager
            let players = try dataManager.loadPlayersThrowing()

            guard let player = players.first(where: { $0.id == uuid }) else {
                AppLog.player.error("Player not found for UUID: \(uuid)")
                return false
            }

            let updatedProfile = UserProfile(
                id: player.profile.id,
                name: player.profile.name,
                avatar: skinInfo.skinURL?.httpToHttps() ?? player.avatarName,
                lastPlayed: player.lastPlayed,
                isCurrent: player.isCurrent,
            )

            let updatedCredential = player.credential

            let updatedPlayer = Player(profile: updatedProfile, credential: updatedCredential)

            try dataManager.updatePlayer(updatedPlayer)

            notifyPlayerUpdated(updatedPlayer)

            return true
        } catch {
            AppLog.player.error("Failed to update player skin info: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetches the current player's skin information from the Minecraft Services API.
    ///
    /// - Parameter player: The player to query.
    /// - Returns: Skin information, or `nil` if the fetch fails.
    static func fetchCurrentPlayerSkinFromServices(player: Player) async -> PublicSkinInfo? {
        do {
            let profile = try await fetchPlayerProfileThrowing(player: player)

            guard !profile.skins.isEmpty else {
                AppLog.player.error("Player has no skin information")
                return nil
            }

            let activeSkin = profile.skins.first { $0.state == "ACTIVE" } ?? profile.skins.first

            guard let skin = activeSkin else {
                AppLog.player.error("No active skin found")
                return nil
            }

            return PublicSkinInfo(
                skinURL: skin.url,
                model: skin.variant == "SLIM" ? .slim : .classic,
                capeURL: nil,
                fetchedAt: Date(),
            )
        } catch {
            AppLog.player.error("Failed to fetch skin info from Minecraft Services API: \(error.localizedDescription)")
            return nil
        }
    }

    /// Uploads a skin for the specified player.
    ///
    /// - Parameters:
    ///   - imageData: The PNG image data (64×64 or 64×32 resolution).
    ///   - model: The skin model type (classic or slim).
    ///   - player: The player whose skin should be updated.
    /// - Returns: `true` if the upload succeeded.
    static func uploadSkin(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player,
    ) async -> Bool {
        do {
            try await uploadSkinThrowing(
                imageData: imageData,
                model: model,
                player: player,
            )
            return true
        } catch {
            handleError(error, operation: "Upload skin")
            return false
        }
    }

    /// Refreshes the skin information for the given player.
    ///
    /// - Parameter player: The player whose skin information should be refreshed.
    private static func refreshSkinInfo(player: Player) async {
        if let newSkinInfo = await fetchCurrentPlayerSkinFromServices(player: player) {
            _ = await updatePlayerSkinInfo(uuid: player.id, skinInfo: newSkinInfo)
        }
    }

    /// Uploads a skin and refreshes the local skin information on success.
    ///
    /// - Parameters:
    ///   - imageData: The PNG image data.
    ///   - model: The skin model type.
    ///   - player: The player to update.
    /// - Returns: `true` if both the upload and refresh succeeded.
    static func uploadSkinAndRefresh(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player,
    ) async -> Bool {
        let success = await uploadSkin(imageData: imageData, model: model, player: player)
        if success {
            await refreshSkinInfo(player: player)
        }
        return success
    }

    /// Resets the player's skin to the default and refreshes local information.
    ///
    /// - Parameter player: The player whose skin should be reset.
    /// - Returns: `true` if the reset and refresh succeeded.
    static func resetSkinAndRefresh(player: Player) async -> Bool {
        let success = await resetSkin(player: player)
        if success {
            await refreshSkinInfo(player: player)
        }
        return success
    }

    /// Uploads a skin image for the specified player, throwing on failure.
    ///
    /// Implements the [Mojang API skin upload](https://zh.minecraft.wiki/w/Mojang_API#upload-skin) specification.
    static func uploadSkinThrowing(
        imageData: Data,
        model: PublicSkinInfo.SkinModel,
        player: Player,
    ) async throws {
        try validateAccessToken(player)

        let boundary = "Boundary-\(UUID().uuidString)"
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
            data: Data,
        ) {
            var part = Data()
            func appendString(_ s: String) {
                if let d = s.data(using: .utf8) { part.append(d) }
            }
            appendString("--\(boundary)\r\n")
            appendString(
                "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n",
            )
            appendString("Content-Type: \(mime)\r\n\r\n")
            part.append(data)
            appendString("\r\n")
            body.append(part)
        }
        let variantValue = model == .slim ? "SLIM" : "CLASSIC"
        AppLog.player.info("Uploading skin with variant: \(variantValue), data size: \(imageData.count) bytes")

        appendField(name: "variant", value: variantValue)
        appendFile(
            name: "file",
            filename: "skin.png",
            mime: "image/png",
            data: imageData,
        )
        if let closing = "--\(boundary)--\r\n".data(using: .utf8) {
            body.append(closing)
        }

        do {
            _ = try await APIClient.post(
                url: URLConfig.API.Authentication.minecraftProfileSkins,
                body: body,
                headers: [
                    APIClient.Header.authorization: APIClient.bearer(player.authAccessToken),
                    APIClient.Header.contentType: "\(APIClient.MimeType.multipart); boundary=\(boundary)",
                ],
            )
        } catch let error as GlobalError where error.kind == .network {
            switch error.statusCode {
            case 400:
                throw GlobalError.validation(
                    i18nKey: "error.validation.skin_invalid_file",
                    level: .popup,
                    message: "HTTP 400 during skin upload, invalid skin file (variant: \(variantValue), size: \(imageData.count) bytes)",
                )
            default:
                try handleHTTPError(error, operation: "skin_upload")
            }
        }
        AppLog.player.info("Skin upload successful with variant: \(variantValue)")
    }

    /// Resets the player's skin to the default.
    ///
    /// - Parameter player: The player whose skin should be reset.
    /// - Returns: `true` if the reset succeeded.
    static func resetSkin(player: Player) async -> Bool {
        do {
            try await resetSkinThrowing(player: player)
            return true
        } catch {
            handleError(error, operation: "Reset skin")
            return false
        }
    }

    /// Returns the identifier of the currently active cape, or `nil` if none is active.
    ///
    /// - Parameter profile: The player's Minecraft profile response.
    static func getActiveCapeId(from profile: MinecraftProfileResponse?) -> String? {
        profile?.capes?.first { $0.state == "ACTIVE" }?.id
    }

    /// A Boolean value indicating whether the skin configuration has changed.
    ///
    /// - Parameters:
    ///   - selectedSkinData: Newly selected skin data, or `nil` if none was selected.
    ///   - currentModel: The currently configured skin model.
    ///   - originalModel: The original skin model, or `nil` if no existing skin.
    /// - Returns: `true` if the skin or model differs from the original.
    static func hasSkinChanges(
        selectedSkinData: Data?,
        currentModel: PublicSkinInfo.SkinModel,
        originalModel: PublicSkinInfo.SkinModel?,
    ) -> Bool {
        if selectedSkinData != nil {
            return true
        }

        if originalModel == nil, currentModel != .classic {
            return true
        }

        if let original = originalModel {
            return currentModel != original
        }

        return false
    }

    /// A Boolean value indicating whether the cape selection has changed.
    ///
    /// - Parameters:
    ///   - selectedCapeId: The newly selected cape identifier.
    ///   - currentActiveCapeId: The currently active cape identifier.
    /// - Returns: `true` if the selected cape differs from the current one.
    static func hasCapeChanges(selectedCapeId: String?, currentActiveCapeId: String?) -> Bool {
        selectedCapeId != currentActiveCapeId
    }

    /// Fetches the player's Minecraft profile including cape information.
    ///
    /// - Parameter player: The player to query.
    /// - Returns: The profile response, or `nil` on failure.
    static func fetchPlayerProfile(player: Player) async
        -> MinecraftProfileResponse? {
        do {
            return try await fetchPlayerProfileThrowing(player: player)
        } catch {
            handleError(error, operation: "Fetch player profile")
            return nil
        }
    }

    /// Fetches the player's Minecraft profile including cape information, throwing on failure.
    static func fetchPlayerProfileThrowing(player: Player) async throws
        -> MinecraftProfileResponse {
        try validateAccessToken(player)

        let data = try await APIClient.get(
            url: URLConfig.API.Authentication.minecraftProfile,
            headers: [APIClient.Header.authorization: APIClient.bearer(player.authAccessToken)],
        )

        let profile = try JSONDecoder().decode(
            MinecraftProfileResponse.self,
            from: data,
        )
        return MinecraftProfileResponse(
            id: profile.id,
            name: profile.name,
            skins: profile.skins,
            capes: profile.capes,
            accessToken: player.authAccessToken,
            authXuid: player.authXuid,
            refreshToken: player.authRefreshToken,
        )
    }

    /// Equips a cape for the specified player.
    ///
    /// - Parameters:
    ///   - capeId: The cape's UUID to equip.
    ///   - player: The player whose cape should be changed.
    /// - Returns: `true` if the operation succeeded.
    static func showCape(capeId: String, player: Player) async -> Bool {
        do {
            try await showCapeThrowing(capeId: capeId, player: player)
            return true
        } catch {
            handleError(error, operation: "Show cape")
            return false
        }
    }

    /// Equips a cape for the specified player, throwing on failure.
    ///
    /// Implements the [Mojang API show cape](https://zh.minecraft.wiki/w/Mojang_API#show-cape) specification.
    static func showCapeThrowing(capeId: String, player: Player) async throws {
        try validateAccessToken(player)

        let payload = ["capeId": capeId]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)

        do {
            _ = try await APIClient.put(
                url: URLConfig.API.Authentication.minecraftProfileActiveCape,
                body: jsonData,
                headers: [
                    APIClient.Header.authorization: APIClient.bearer(player.authAccessToken),
                    APIClient.Header.contentType: APIClient.MimeType.json,
                ],
            )
        } catch let error as GlobalError where error.kind == .network {
            switch error.statusCode {
            case 404:
                throw GlobalError.resource(
                    i18nKey: "error.resource.cape_not_found",
                    level: .notification,
                    message: "HTTP 404 during equip cape, cape ID \"\(capeId)\" not found",
                )
            default:
                try handleHTTPError(error, operation: "equip_cape")
            }
        }
    }

    /// Hides the currently active cape.
    ///
    /// - Parameter player: The player whose cape should be hidden.
    /// - Returns: `true` if the operation succeeded.
    static func hideCape(player: Player) async -> Bool {
        do {
            try await hideCapeThrowing(player: player)
            return true
        } catch {
            handleError(error, operation: "Hide cape")
            return false
        }
    }

    /// Hides the currently active cape, throwing on failure.
    ///
    /// Implements the [Mojang API hide cape](https://zh.minecraft.wiki/w/Mojang_API#hide-cape) specification.
    static func hideCapeThrowing(player: Player) async throws {
        try validateAccessToken(player)
        do {
            _ = try await APIClient.delete(
                url: URLConfig.API.Authentication.minecraftProfileActiveCape,
                headers: [APIClient.Header.authorization: APIClient.bearer(player.authAccessToken)],
            )
        } catch let error as GlobalError where error.kind == .network {
            try handleHTTPError(error, operation: "hide_cape")
        }
    }

    /// Resets the player's skin to the default, throwing on failure.
    static func resetSkinThrowing(player: Player) async throws {
        try validateAccessToken(player)
        do {
            _ = try await APIClient.delete(
                url: URLConfig.API.Authentication.minecraftProfileActiveSkin,
                headers: [APIClient.Header.authorization: APIClient.bearer(player.authAccessToken)],
            )
        } catch let error as GlobalError where error.kind == .network {
            try handleHTTPError(error, operation: "reset_skin")
        }
    }
}
