//
//  YggdrasilServerRegistry.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Unified lookup over built-in presets and user-added custom Yggdrasil servers.
///
/// Players are linked to their server by the base URL string stored in
/// ``OfflineUserServerMap``; lookups match both sources so that players of custom
/// servers can be resolved when launching the game.
enum YggdrasilServerRegistry {
    /// Built-in presets (OAuth login).
    static var presets: [YggdrasilServerConfig] {
        YggdrasilServerPresets.servers
    }

    /// User-added custom servers (password login), read from the observable store so
    /// that views referencing this list refresh when servers are added or removed.
    static var custom: [YggdrasilServerConfig] {
        DIContainer.shared.system.customYggdrasilServerStore.servers
            .map(CustomYggdrasilServerStore.toConfig)
    }

    /// All available servers, presets first.
    static var allServers: [YggdrasilServerConfig] {
        presets + custom
    }

    /// Finds a server configuration by its base URL string.
    static func server(for baseURLString: String) -> YggdrasilServerConfig? {
        allServers.first { $0.baseURL.absoluteString == baseURLString }
    }

    /// Base URLs of servers still referenced by existing players (guards server removal).
    ///
    /// Throws when players cannot be loaded, so that removal fails closed instead of
    /// treating every server as unused.
    static func referencedServerBaseURLs() throws -> Set<String> {
        let players = try DIContainer.shared.ui.playerDataManager.loadPlayersThrowing()
        return Set(players.compactMap { OfflineUserServerMap.serverKey(for: $0.id)?.serverBaseURL })
    }
}
