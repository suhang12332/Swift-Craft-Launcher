//
//  ServerAddressModels.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/20.
//

import Foundation

/// 服务器地址信息模型
struct ServerAddress: Codable, Identifiable, Hashable {
    /// 服务器唯一标识符
    let id: String
    
    /// 服务器名称
    let name: String
    
    /// 服务器地址（IP 或域名）
    let address: String
    
    /// 服务器端口（可选，默认 25565）
    let port: Int
    
    /// 是否隐藏服务器图标
    let hidden: Bool
    
    /// 服务器图标资源位置（可选）
    let icon: String?
    
    /// 是否接受文本到聊天
    let acceptTextures: Bool
    
    /// 初始化服务器地址信息
    /// - Parameters:
    ///   - id: 服务器ID，默认生成新的UUID
    ///   - name: 服务器名称
    ///   - address: 服务器地址
    ///   - port: 服务器端口，默认 25565
    ///   - hidden: 是否隐藏，默认 false
    ///   - icon: 服务器图标，默认 nil
    ///   - acceptTextures: 是否接受纹理，默认 false
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        port: Int = 25565,
        hidden: Bool = false,
        icon: String? = nil,
        acceptTextures: Bool = false
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.hidden = hidden
        self.icon = icon
        self.acceptTextures = acceptTextures
    }
    
    /// 获取完整的服务器地址（包含端口）
    var fullAddress: String {
        return "\(address):\(String(port))"
    }
}

