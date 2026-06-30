//
//  CommonBlessingSkinStyleProfileListParser.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Parses Blessing Skin profile list responses in MUA format.
enum BlessingSkinProfileListParser {
    static func parse(data: Data, baseURL: String) -> [YggdrasilProfileCandidate]? {
        struct BlessingSkinProfileItem: Decodable {
            let pid: Int?
            let uid: Int?
            let name: String
            let tidCape: Int?
            let tidSkin: Int?
            let uuid: String?

            private enum CodingKeys: String, CodingKey {
                case pid, uid, name, uuid
                case tidCape = "tid_cape"
                case tidSkin = "tid_skin"
            }
        }

        if let list = try? JSONDecoder().decode([BlessingSkinProfileItem].self, from: data), !list.isEmpty {
            return list.map { item in
                var skins: [Skin] = []
                var capes: [Cape] = []

                if let tidSkin = item.tidSkin, tidSkin > 0 {
                    let url = Self.rawURL(baseURL: baseURL, id: tidSkin)
                    skins.append(Skin(state: "ACTIVE", url: url, variant: "classic"))
                }

                if let capeId = item.tidCape, capeId > 0 {
                    let url = Self.rawURL(baseURL: baseURL, id: capeId)
                    capes.append(Cape(
                        id: "cape_\(capeId)",
                        state: "ACTIVE",
                        url: url,
                        alias: nil
                    ))
                }

                if skins.isEmpty {
                    skins.append(Skin(state: "ACTIVE", url: "", variant: "classic"))
                }

                let resolvedId = (try? PlayerUtils.generateOfflineUUID(for: item.name)) ?? item.name

                return YggdrasilProfileCandidate(
                    id: resolvedId,
                    name: item.name,
                    skins: skins,
                    capes: capes.isEmpty ? nil : capes
                )
            }
        }

        return nil
    }

    private static func rawURL(baseURL: String, id: Int) -> String {
        "\(baseURL)/raw/\(id)"
    }
}

/// Parses MUA (Blessing Skin) profile list responses.
struct CommonBlessingSkinStyleProfileListParser: YggdrasilProfileListParser {
    let id: YggdrasilProfileParserID = .mua
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func parse(data: Data) async -> [YggdrasilProfileCandidate]? {
        BlessingSkinProfileListParser.parse(data: data, baseURL: baseURL)
    }
}
