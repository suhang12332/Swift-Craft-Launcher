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

    private struct SessionProfile: Decodable {
        struct Property: Decodable { let name: String; let value: String }
        let id: String
        let name: String
        let properties: [Property]
    }

    private struct TexturesPayload: Decodable {
        struct Textures: Decodable {
            struct SkinObj: Decodable {
                struct Metadata: Decodable { let model: String? }
                let url: String
                let metadata: Metadata?
            }
            struct CapeObj: Decodable { let url: String }
            let SKIN: SkinObj?
            let CAPE: CapeObj?
        }
        let timestamp: Int64
        let profileId: String
        let profileName: String
        let textures: Textures
    }

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
        case 200: break
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
}
