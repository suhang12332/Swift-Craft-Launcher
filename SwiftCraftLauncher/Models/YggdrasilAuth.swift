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
    
    // LittleSkin ID Token 可解析更多信息，根据需要添加
}

// MARK: - Yggdrasil 角色（选中档案）
struct YggdrasilSelectedProfile: Codable {
    let id: String
    let name: String
    let legacy: Bool?
    let demo: Bool?
}
