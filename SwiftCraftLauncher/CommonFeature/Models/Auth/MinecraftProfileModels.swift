//
//  MinecraftProfileModels.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

struct MinecraftProfileResponse: Codable, Equatable {
    let id: String
    let name: String
    let skins: [Skin]
    let capes: [Cape]?
    let accessToken: String
    let authXuid: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case skins
        case capes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        skins = try container.decode([Skin].self, forKey: .skins)
        capes = try container.decodeIfPresent([Cape].self, forKey: .capes)
        accessToken = ""
        authXuid = ""
        refreshToken = ""
    }

    init(id: String, name: String, skins: [Skin], capes: [Cape]?, accessToken: String, authXuid: String, refreshToken: String = "") {
        self.id = id
        self.name = name
        self.skins = skins
        self.capes = capes
        self.accessToken = accessToken
        self.authXuid = authXuid
        self.refreshToken = refreshToken
    }
}

struct Skin: Codable, Equatable {
    let state: String
    let url: String
    let variant: String?
}

struct Cape: Codable, Equatable {
    let id: String
    let state: String
    let url: String
    let alias: String?
}
