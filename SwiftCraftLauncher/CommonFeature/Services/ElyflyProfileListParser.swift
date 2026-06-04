//
//  ElyflyProfileListParser.swift
//  SwiftCraftLauncher
//
//  Created by su on 2026/3/30.
//

import Foundation

/// Ely.by 返回体解析
enum ElyflyProfileListParser {
    static func parse(data: Data, baseURL: String) async -> [YggdrasilProfileCandidate]? {
        _ = baseURL

        struct ElyflyUser: Decodable {
            let id: Int?
            let uuid: String
            let username: String
        }

        struct ElyflyTextures: Decodable {
            let SKIN: ElyflyTextureEntry?
            let CAPE: ElyflyTextureEntry?
        }

        struct ElyflyTextureEntry: Decodable {
            let url: String
            let metadata: ElyflyTextureMetadata?
        }

        struct ElyflyTextureMetadata: Decodable {
            let model: String?
        }

        let decoder = JSONDecoder()

        func fetchTextures(for nickname: String) async -> (skins: [Skin], capes: [Cape]) {
            var skins: [Skin] = []
            var capes: [Cape] = []

            let url = URLConfig.API.Ely.textures(nickname: nickname)
            if let textures: ElyflyTextures = try? await APIClient.request(url: url) {
                if let skin = textures.SKIN {
                    skins.append(Skin(
                        state: "ACTIVE",
                        url: skin.url,
                        variant: skin.metadata?.model ?? "classic"
                    ))
                }
                if let cape = textures.CAPE {
                    capes.append(Cape(
                        id: "ely_cape_\(nickname)",
                        state: "ACTIVE",
                        url: cape.url,
                        alias: nil
                    ))
                }
            }

            if skins.isEmpty {
                skins.append(Skin(state: "ACTIVE", url: "", variant: "classic"))
            }

            return (skins, capes)
        }

        func buildCandidate(from user: ElyflyUser) async -> YggdrasilProfileCandidate {
            let compactUUID = user.uuid.replacingOccurrences(of: "-", with: "")
            let resolvedName = user.username
            let textures = await fetchTextures(for: resolvedName)

            return YggdrasilProfileCandidate(
                id: compactUUID,
                name: resolvedName,
                skins: textures.skins,
                capes: textures.capes.isEmpty ? nil : textures.capes
            )
        }

        if let list = try? decoder.decode([ElyflyUser].self, from: data), !list.isEmpty {
            var results: [YggdrasilProfileCandidate] = []
            for user in list {
                let candidate = await buildCandidate(from: user)
                results.append(candidate)
            }
            return results
        }

        if let single = try? decoder.decode(ElyflyUser.self, from: data) {
            return [
                await buildCandidate(from: single),
            ]
        }

        return nil
    }
}

/// Ely.by 通用解析器
struct ElyflyProfileStyleProfileListParser: YggdrasilProfileListParser {
    let id: YggdrasilProfileParserID = .ely
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func parse(data: Data) async -> [YggdrasilProfileCandidate]? {
        await ElyflyProfileListParser.parse(data: data, baseURL: baseURL)
    }
}
