//
//  YggdrasilServerRegistry.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Yggdrasil 服务器统一注册表:内置预设 ∪ 用户自定义服务器。
///
/// 凭据与档案通过服务器 baseURL 字符串关联;查找时两种来源一并匹配,
/// 保证自定义服务器玩家在启动游戏等场景能解析到配置。
enum YggdrasilServerRegistry {
    /// 内置预设(OAuth 登录)。
    static var presets: [YggdrasilServerConfig] {
        YggdrasilServerPresets.servers
    }

    /// 用户添加的自定义服务器(密码登录)。读取自可观察存储,
    /// 增删后引用该列表的视图会自动刷新。
    static var custom: [YggdrasilServerConfig] {
        DIContainer.shared.system.customYggdrasilServerStore.servers
            .map(CustomYggdrasilServerStore.toConfig)
    }

    /// 全部可用服务器(预设在前,自定义在后)。
    static var allServers: [YggdrasilServerConfig] {
        presets + custom
    }

    /// 按 baseURL 字符串查找服务器配置。
    static func server(for baseURLString: String) -> YggdrasilServerConfig? {
        allServers.first { $0.baseURL.absoluteString == baseURLString }
    }

    /// 自定义服务器是否被现有玩家档案引用(删除前的保护检查)。
    static var referencedYggdrasilBaseURLs: Set<String> {
        let dataManager = DIContainer.shared.ui.playerDataManager
        guard let players = try? dataManager.loadPlayersThrowing() else { return [] }
        return Set(players.compactMap(\.yggdrasilServerBaseURL))
    }
}
