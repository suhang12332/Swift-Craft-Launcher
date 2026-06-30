//
//  MinecraftJavaServerResourceUtils.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Utilities for handling Minecraft Java server resources.
enum MinecraftJavaServerResourceUtils {
    /// Parses the server address from a project detail's file name.
    static func parseAddress(from detail: ModrinthProjectDetail) -> String {
        let rawFileName = detail.fileName ?? ""
        return CommonUtil.parseMinecraftJavaServerInfo(from: rawFileName).address
    }

    /// Adds a server to the game if it is not already present.
    /// - Throws: A validation error if the server address cannot be parsed.
    @MainActor
    static func addServerToGameIfNeeded(
        game: GameVersionInfo,
        detail: ModrinthProjectDetail
    ) async throws {
        let address = parseAddress(from: detail)
        guard !address.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "无法解析服务器地址",
                i18nKey: "error.server.invalid_address",
                level: .notification
            )
        }

        try await AppServices.serverAddressService.addServerIfNeeded(
            for: game.gameName,
            address: address,
            name: detail.title
        )
    }
}
