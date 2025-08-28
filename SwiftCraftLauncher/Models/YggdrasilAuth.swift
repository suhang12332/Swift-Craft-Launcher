//
//  YggdrasilAuth.swift
//  SwiftCraftLauncher
//
//  Created by rayanceking on 2025/8/16.
//

import Foundation

// MARK: - Yggdrasil 用户档案响应
struct YggdrasilProfileResponse: Codable, Identifiable {
    let id: String
    let username: String
    let selectedProfile: YggdrasilSelectedProfile?
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let textures: YggdrasilTextures?

    // LittleSkin ID Token 可解析更多信息，根据需要添加
}

// MARK: - Yggdrasil 角色（选中档案）
struct YggdrasilSelectedProfile: Codable {
    let id: String
    let name: String
    let legacy: Bool?
    let demo: Bool?
}

// MARK: - Yggdrasil UserInfo 响应模型
struct YggdrasilUserInfo: Codable {
    let sub: String
    let aud: String
    let selectedProfile: YggdrasilSelectedProfile
}


// MARK: - Yggdrasil 设备代码响应模型
struct YggdrasilDeviceCodeResponse: Codable {
    let userCode: String
    let deviceCode: String
    let verificationUri: String
    let verificationUriComplete: String?
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case deviceCode = "device_code"
        case verificationUri = "verification_uri"
        case verificationUriComplete = "verification_uri_complete"
        case expiresIn = "expires_in"
        case interval
    }
}

// MARK: - Yggdrasil 令牌响应模型
struct YggdrasilTokenResponse: Codable {
    let tokenType: String
    let expiresIn: Int
    let accessToken: String
    let refreshToken: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

// MARK: - Yggdrasil 皮肤响应模型
struct YggdrasilSkinResponse: Codable {
    let id: String
    let name: String
    let properties: [YggdrasilProperty]
}

// MARK: - Yggdrasil 属性模型
struct YggdrasilProperty: Codable {
    let name: String
    let value: String
}

// MARK: - Yggdrasil 纹理模型 (Base64解码后的内容)
struct YggdrasilTextures: Codable {
    let timestamp: Int
    let profileId: String
    let profileName: String
    let textures: YggdrasilTextureUrls
}

// MARK: - Yggdrasil 纹理URL模型
struct YggdrasilTextureUrls: Codable {
    let SKIN: YggdrasilTextureInfo?
    let CAPE: YggdrasilTextureInfo?
}

// MARK: - Yggdrasil 纹理信息模型
struct YggdrasilTextureInfo: Codable {
    let url: String
}

